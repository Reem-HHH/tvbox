package ae.kidstv.launcher;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.AssetManager;
import android.graphics.Color;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.text.InputFilter;
import android.text.InputType;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.MimeTypeMap;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.io.IOException;
import java.io.InputStream;
import java.util.Collections;

public class MainActivity extends Activity {
    private static final String APP_ORIGIN = "https://appassets.androidplatform.net";
    private static final String START_URL = APP_ORIGIN + "/assets/player.html";
    private static final String PREFS_NAME = "parent_gate";
    private static final String KEY_PIN_HASH = "pin_hash";
    private static final String KEY_PIN_SALT = "pin_salt";
    private static final String KEY_FAIL_COUNT = "fail_count";
    private static final String KEY_LOCKED_UNTIL = "locked_until";

    private final ParentUnlockGate unlockGate = new ParentUnlockGate();
    private FrameLayout root;
    private WebView webView;
    private AudioManager audioManager;
    private SharedPreferences prefs;
    private AlertDialog activeDialog;
    private int pendingParentAction = -1;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        unlockGate.restoreRateLimitState(
                prefs.getInt(KEY_FAIL_COUNT, 0),
                prefs.getLong(KEY_LOCKED_UNTIL, 0L)
        );
        audioManager = (AudioManager) getSystemService(AUDIO_SERVICE);

        root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        configureWebView();
        root.addView(webView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        setContentView(root);
        hideSystemUi();
        webView.loadUrl(START_URL);
    }

    private void configureWebView() {
        webView = new WebView(this);
        webView.setBackgroundColor(Color.BLACK);
        webView.setFocusable(true);
        webView.setFocusableInTouchMode(true);
        webView.requestFocus();
        webView.setOnTouchListener((view, event) -> {
            // Air-mouse/touch input is disabled so the physical remote is the
            // only playback controller and the embedded player is never focused.
            return true;
        });

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setJavaScriptCanOpenWindowsAutomatically(false);
        settings.setSupportMultipleWindows(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);

        webView.setWebChromeClient(new WebChromeClient());
        webView.setWebViewClient(new LocalAssetWebViewClient(getAssets()));
    }

    @Override
    protected void onResume() {
        super.onResume();
        hideSystemUi();
        if (webView != null && (activeDialog == null || !activeDialog.isShowing())) {
            webView.setVisibility(View.VISIBLE);
            webView.onResume();
            runJs("ensurePlaying()");
        }
    }

    @Override
    protected void onPause() {
        if (webView != null) {
            webView.onPause();
        }
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        dismissActiveDialog();
        destroyWebView();
        super.onDestroy();
    }

    private void destroyWebView() {
        if (webView == null) {
            return;
        }
        if (root != null) {
            root.removeView(webView);
        }
        webView.loadUrl("about:blank");
        webView.stopLoading();
        webView.setWebChromeClient(null);
        webView.setWebViewClient(null);
        webView.destroy();
        webView = null;
    }

    private void hideSystemUi() {
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController controller = getWindow().getInsetsController();
            if (controller != null) {
                controller.hide(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                controller.setSystemBarsBehavior(
                        WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                );
            }
        } else {
            getWindow().getDecorView().setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            | View.SYSTEM_UI_FLAG_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            );
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            hideSystemUi();
        }
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (activeDialog != null && activeDialog.isShowing()) {
            return super.dispatchKeyEvent(event);
        }

        if (event.getAction() != KeyEvent.ACTION_DOWN || event.getRepeatCount() > 0) {
            return super.dispatchKeyEvent(event);
        }

        int keyCode = event.getKeyCode();
        if (unlockGate.recordKeyAndCheckTrigger(keyCode, System.currentTimeMillis())) {
            unlockGate.clearKeys();
            beginParentAccess();
            return true;
        }

        switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER:
            case KeyEvent.KEYCODE_NUMPAD_ENTER:
            case KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE:
            case KeyEvent.KEYCODE_SPACE:
                runJs("ensurePlaying()");
                return true;

            case KeyEvent.KEYCODE_DPAD_RIGHT:
            case KeyEvent.KEYCODE_MEDIA_NEXT:
            case KeyEvent.KEYCODE_CHANNEL_UP:
                runJs("nextVideo()");
                return true;

            case KeyEvent.KEYCODE_DPAD_LEFT:
            case KeyEvent.KEYCODE_MEDIA_PREVIOUS:
            case KeyEvent.KEYCODE_CHANNEL_DOWN:
                runJs("previousVideo()");
                return true;

            case KeyEvent.KEYCODE_DPAD_UP:
            case KeyEvent.KEYCODE_VOLUME_UP:
                audioManager.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_RAISE,
                        0
                );
                return true;

            case KeyEvent.KEYCODE_DPAD_DOWN:
            case KeyEvent.KEYCODE_VOLUME_DOWN:
                audioManager.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_LOWER,
                        0
                );
                return true;

            case KeyEvent.KEYCODE_1:
            case KeyEvent.KEYCODE_NUMPAD_1:
                runJs("switchChannel(0)");
                return true;
            case KeyEvent.KEYCODE_2:
            case KeyEvent.KEYCODE_NUMPAD_2:
                runJs("switchChannel(1)");
                return true;
            case KeyEvent.KEYCODE_3:
            case KeyEvent.KEYCODE_NUMPAD_3:
                runJs("switchChannel(2)");
                return true;
            case KeyEvent.KEYCODE_4:
            case KeyEvent.KEYCODE_NUMPAD_4:
                runJs("switchChannel(3)");
                return true;

            case KeyEvent.KEYCODE_PAGE_UP:
                runJs("nextChannel()");
                return true;
            case KeyEvent.KEYCODE_PAGE_DOWN:
                runJs("previousChannel()");
                return true;

            case KeyEvent.KEYCODE_BACK:
            case KeyEvent.KEYCODE_HOME:
            case KeyEvent.KEYCODE_MENU:
            case KeyEvent.KEYCODE_SETTINGS:
            case KeyEvent.KEYCODE_VOICE_ASSIST:
            case KeyEvent.KEYCODE_SEARCH:
            case KeyEvent.KEYCODE_ASSIST:
            case KeyEvent.KEYCODE_APP_SWITCH:
            case KeyEvent.KEYCODE_ALL_APPS:
            case KeyEvent.KEYCODE_NOTIFICATION:
            case KeyEvent.KEYCODE_SYSRQ:
                return true;

            default:
                // Consume unknown keys so OEM shortcuts are less likely to leave kids mode.
                return true;
        }
    }

    private void runJs(String command) {
        if (webView != null) {
            webView.evaluateJavascript(command, null);
        }
    }

    private void beginParentAccess() {
        long now = System.currentTimeMillis();
        unlockGate.refreshLockout(now);
        persistRateLimitState();
        if (unlockGate.isLockedOut(now)) {
            long seconds = Math.max(1L, (unlockGate.remainingLockoutMs(now) + 999L) / 1000L);
            Toast.makeText(this, "Parent access locked. Try again in " + seconds + "s.", Toast.LENGTH_LONG)
                    .show();
            return;
        }

        pausePlayerForOverlay();
        if (!hasPinConfigured()) {
            showCreatePinDialog();
        } else {
            showEnterPinDialog();
        }
    }

    private boolean hasPinConfigured() {
        String hash = prefs.getString(KEY_PIN_HASH, null);
        String salt = prefs.getString(KEY_PIN_SALT, null);
        return hash != null && !hash.isEmpty() && salt != null && !salt.isEmpty();
    }

    private void showCreatePinDialog() {
        LinearLayout layout = newPinFormLayout();
        final EditText pinField = newPinField();
        final EditText confirmField = newPinField();
        TextView hint = new TextView(this);
        hint.setText("Create a parent PIN (4–8 digits). You will need it to open settings.");
        hint.setPadding(0, 0, 0, 24);
        layout.addView(hint);
        layout.addView(labeledField("PIN", pinField));
        layout.addView(labeledField("Confirm PIN", confirmField));

        activeDialog = new AlertDialog.Builder(this)
                .setTitle("Set parent PIN")
                .setView(layout)
                .setCancelable(false)
                .setPositiveButton("Save", null)
                .setNegativeButton("Cancel", (dialog, which) -> resumePlayerAfterOverlay())
                .setOnDismissListener(dialog -> {
                    if (activeDialog == dialog) {
                        activeDialog = null;
                    }
                    hideSystemUi();
                })
                .create();

        activeDialog.setOnShowListener(dialog -> {
            activeDialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
                String pin = pinField.getText().toString().trim();
                String confirm = confirmField.getText().toString().trim();
                if (!ParentUnlockGate.isValidPinFormat(pin)) {
                    Toast.makeText(this, "PIN must be 4–8 digits.", Toast.LENGTH_SHORT).show();
                    return;
                }
                if (!pin.equals(confirm)) {
                    Toast.makeText(this, "PINs do not match.", Toast.LENGTH_SHORT).show();
                    return;
                }
                persistNewPin(pin);
                unlockGate.registerSuccess();
                persistRateLimitState();
                activeDialog.dismiss();
                openParentMenu();
            });
            pinField.requestFocus();
        });
        activeDialog.show();
    }

    private void showEnterPinDialog() {
        LinearLayout layout = newPinFormLayout();
        final EditText pinField = newPinField();
        TextView hint = new TextView(this);
        hint.setText("Enter parent PIN");
        hint.setPadding(0, 0, 0, 24);
        layout.addView(hint);
        layout.addView(pinField);

        activeDialog = new AlertDialog.Builder(this)
                .setTitle("Parent access")
                .setView(layout)
                .setCancelable(false)
                .setPositiveButton("Unlock", null)
                .setNegativeButton("Cancel", (dialog, which) -> resumePlayerAfterOverlay())
                .setOnDismissListener(dialog -> {
                    if (activeDialog == dialog) {
                        activeDialog = null;
                    }
                    hideSystemUi();
                })
                .create();

        activeDialog.setOnShowListener(dialog -> {
            activeDialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v -> {
                long now = System.currentTimeMillis();
                if (unlockGate.isLockedOut(now)) {
                    long seconds = Math.max(1L, (unlockGate.remainingLockoutMs(now) + 999L) / 1000L);
                    Toast.makeText(this, "Too many attempts. Wait " + seconds + "s.", Toast.LENGTH_LONG)
                            .show();
                    return;
                }

                String pin = pinField.getText().toString().trim();
                String salt = prefs.getString(KEY_PIN_SALT, "");
                String expected = prefs.getString(KEY_PIN_HASH, "");
                if (unlockGate.verifyPin(pin, salt, expected)) {
                    unlockGate.registerSuccess();
                    persistRateLimitState();
                    activeDialog.dismiss();
                    openParentMenu();
                    return;
                }

                boolean locked = unlockGate.registerFailure(now);
                persistRateLimitState();
                pinField.setText("");
                if (locked) {
                    long seconds = Math.max(1L, (unlockGate.remainingLockoutMs(now) + 999L) / 1000L);
                    Toast.makeText(this, "Incorrect PIN. Locked for " + seconds + "s.", Toast.LENGTH_LONG)
                            .show();
                    activeDialog.dismiss();
                    resumePlayerAfterOverlay();
                } else {
                    int remaining = ParentUnlockGate.MAX_FAILURES_BEFORE_LOCKOUT
                            - unlockGate.getFailureCount();
                    Toast.makeText(
                            this,
                            "Incorrect PIN. " + Math.max(0, remaining) + " tries left.",
                            Toast.LENGTH_SHORT
                    ).show();
                }
            });
            pinField.requestFocus();
        });
        activeDialog.show();
    }

    private void persistNewPin(String pin) {
        String salt = ParentUnlockGate.newSaltHex();
        String hash = ParentUnlockGate.hashPin(pin, salt);
        prefs.edit()
                .putString(KEY_PIN_SALT, salt)
                .putString(KEY_PIN_HASH, hash)
                .apply();
    }

    private void persistRateLimitState() {
        prefs.edit()
                .putInt(KEY_FAIL_COUNT, unlockGate.getFailureCount())
                .putLong(KEY_LOCKED_UNTIL, unlockGate.getLockedUntilMs())
                .apply();
    }

    private LinearLayout newPinFormLayout() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) (24 * getResources().getDisplayMetrics().density);
        layout.setPadding(pad, pad, pad, pad);
        return layout;
    }

    private EditText newPinField() {
        EditText field = new EditText(this);
        field.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        field.setFilters(new InputFilter[]{
                new InputFilter.LengthFilter(ParentUnlockGate.MAX_PIN_LENGTH)
        });
        field.setHint("••••");
        return field;
    }

    private LinearLayout labeledField(String label, EditText field) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.VERTICAL);
        TextView title = new TextView(this);
        title.setText(label);
        row.addView(title);
        row.addView(field);
        int bottom = (int) (12 * getResources().getDisplayMetrics().density);
        row.setPadding(0, 0, 0, bottom);
        return row;
    }

    private void pausePlayerForOverlay() {
        runJs("pauseForParentMenu()");
        if (webView != null) {
            webView.setVisibility(View.INVISIBLE);
        }
    }

    private void resumePlayerAfterOverlay() {
        if (webView != null) {
            webView.setVisibility(View.VISIBLE);
        }
        runJs("ensurePlaying()");
        hideSystemUi();
    }

    private void openParentMenu() {
        pausePlayerForOverlay();
        pendingParentAction = -1;

        String[] options = {
                "Resume Kids TV",
                "Open Android settings",
                "Choose another Home app",
                "Open this app's settings",
                "Pin Kids TV (screen pinning)",
                "Change parent PIN"
        };

        activeDialog = new AlertDialog.Builder(this)
                .setTitle("Parent menu")
                .setItems(options, (dialog, which) -> pendingParentAction = which)
                .setOnDismissListener(dialog -> {
                    if (activeDialog == dialog) {
                        activeDialog = null;
                    }
                    int action = pendingParentAction;
                    pendingParentAction = -1;
                    if (action >= 0) {
                        handleParentAction(action);
                    } else if (activeDialog == null) {
                        resumePlayerAfterOverlay();
                    }
                    hideSystemUi();
                })
                .show();
    }

    private void handleParentAction(int which) {
        switch (which) {
            case 0:
                resumePlayerAfterOverlay();
                break;
            case 1:
                safelyStart(new Intent(Settings.ACTION_SETTINGS));
                resumePlayerAfterOverlay();
                break;
            case 2:
                Intent home = new Intent(Intent.ACTION_MAIN);
                home.addCategory(Intent.CATEGORY_HOME);
                safelyStart(Intent.createChooser(home, "Choose Home app"));
                resumePlayerAfterOverlay();
                break;
            case 3:
                Intent appSettings = new Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:" + getPackageName())
                );
                safelyStart(appSettings);
                resumePlayerAfterOverlay();
                break;
            case 4:
                startKidsLockTask();
                resumePlayerAfterOverlay();
                break;
            case 5:
                showCreatePinDialog();
                break;
            default:
                resumePlayerAfterOverlay();
                break;
        }
    }

    private void startKidsLockTask() {
        try {
            startLockTask();
            Toast.makeText(
                    this,
                    "Screen pinning requested. Confirm if the system asks. Full kiosk needs device owner.",
                    Toast.LENGTH_LONG
            ).show();
        } catch (Exception e) {
            Toast.makeText(
                    this,
                    "Screen pinning is not available on this device.",
                    Toast.LENGTH_LONG
            ).show();
        }
    }

    private void safelyStart(Intent intent) {
        try {
            startActivity(intent);
        } catch (Exception e) {
            Toast.makeText(
                    this,
                    "Could not open that screen on this TV.",
                    Toast.LENGTH_LONG
            ).show();
        }
    }

    private void dismissActiveDialog() {
        if (activeDialog != null) {
            try {
                if (activeDialog.isShowing()) {
                    activeDialog.dismiss();
                }
            } catch (Exception ignored) {
                // Activity may already be gone.
            }
            activeDialog = null;
        }
    }

    private static final class LocalAssetWebViewClient extends WebViewClient {
        private final AssetManager assets;

        private LocalAssetWebViewClient(AssetManager assets) {
            this.assets = assets;
        }

        @Override
        public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
            Uri uri = request.getUrl();
            if (!"appassets.androidplatform.net".equals(uri.getHost())
                    || uri.getPath() == null
                    || !uri.getPath().startsWith("/assets/")) {
                return null;
            }

            String raw = uri.getPath().substring("/assets/".length());
            String assetPath = AssetPathSanitizer.resolveAllowedAsset(raw);
            if (assetPath == null) {
                return new WebResourceResponse(
                        "text/plain", "UTF-8", 404, "Not Found", Collections.emptyMap(), null);
            }

            try {
                InputStream stream = assets.open(assetPath);
                String extension = MimeTypeMap.getFileExtensionFromUrl(assetPath);
                String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
                if (mime == null) {
                    mime = assetPath.endsWith(".json") ? "application/json" : "text/html";
                }
                return new WebResourceResponse(mime, "UTF-8", stream);
            } catch (IOException ignored) {
                return new WebResourceResponse(
                        "text/plain", "UTF-8", 404, "Not Found", Collections.emptyMap(), null);
            }
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            if (!request.isForMainFrame()) {
                return false;
            }
            Uri uri = request.getUrl();
            if (!"appassets.androidplatform.net".equals(uri.getHost())) {
                return true;
            }
            String path = uri.getPath();
            if (path == null || !path.startsWith("/assets/")) {
                return true;
            }
            return AssetPathSanitizer.resolveAllowedAsset(path.substring("/assets/".length())) == null;
        }
    }
}
