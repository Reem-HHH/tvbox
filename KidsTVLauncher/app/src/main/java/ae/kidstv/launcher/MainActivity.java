package ae.kidstv.launcher;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.res.AssetManager;
import android.graphics.Color;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.MimeTypeMap;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Deque;

public class MainActivity extends Activity {
    private static final String APP_ORIGIN = "https://appassets.androidplatform.net";
    private static final String START_URL = APP_ORIGIN + "/assets/player.html";

    private static final int[] PARENT_SEQUENCE = {
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_DPAD_CENTER
    };

    private final Deque<Integer> recentKeys = new ArrayDeque<>();
    private WebView webView;
    private AudioManager audioManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        audioManager = (AudioManager) getSystemService(AUDIO_SERVICE);
        configureWebView();
        setContentView(webView);
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
        if (webView != null) {
            webView.setVisibility(View.VISIBLE);
            webView.onResume();
            runJs("ensurePlaying()");
        }
    }

    @Override
    protected void onPause() {
        if (webView != null) webView.onPause();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.loadUrl("about:blank");
            webView.stopLoading();
            webView.destroy();
        }
        super.onDestroy();
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
        if (hasFocus) hideSystemUi();
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (event.getAction() != KeyEvent.ACTION_DOWN || event.getRepeatCount() > 0) {
            return super.dispatchKeyEvent(event);
        }

        int keyCode = event.getKeyCode();
        rememberKey(keyCode);
        if (matchesParentSequence()) {
            recentKeys.clear();
            openParentMenu();
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
                return true;

            default:
                return super.dispatchKeyEvent(event);
        }
    }

    private void runJs(String command) {
        if (webView != null) {
            webView.evaluateJavascript("javascript:" + command, null);
        }
    }

    private void rememberKey(int keyCode) {
        recentKeys.addLast(keyCode);
        while (recentKeys.size() > PARENT_SEQUENCE.length) {
            recentKeys.removeFirst();
        }
    }

    private boolean matchesParentSequence() {
        if (recentKeys.size() != PARENT_SEQUENCE.length) return false;
        int index = 0;
        for (int key : recentKeys) {
            if (key != PARENT_SEQUENCE[index++]) return false;
        }
        return true;
    }

    private void openParentMenu() {
        runJs("pauseForParentMenu()");
        if (webView != null) webView.setVisibility(View.INVISIBLE);

        String[] options = {
                "Resume Kids TV",
                "Open Android settings",
                "Choose another Home app",
                "Open this app's settings"
        };

        new AlertDialog.Builder(this)
                .setTitle("Parent menu")
                .setItems(options, (dialog, which) -> {
                    switch (which) {
                        case 0:
                            if (webView != null) webView.setVisibility(View.VISIBLE);
                            runJs("ensurePlaying()");
                            break;
                        case 1:
                            safelyStart(new Intent(Settings.ACTION_SETTINGS));
                            break;
                        case 2:
                            Intent home = new Intent(Intent.ACTION_MAIN);
                            home.addCategory(Intent.CATEGORY_HOME);
                            safelyStart(Intent.createChooser(home, "Choose Home app"));
                            break;
                        case 3:
                            Intent appSettings = new Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:" + getPackageName())
                            );
                            safelyStart(appSettings);
                            break;
                        default:
                            break;
                    }
                })
                .setOnDismissListener(dialog -> {
                    if (webView != null) webView.setVisibility(View.VISIBLE);
                    runJs("ensurePlaying()");
                    hideSystemUi();
                })
                .show();
    }

    private void safelyStart(Intent intent) {
        try {
            startActivity(intent);
        } catch (Exception ignored) {
            // Generic Android TV boxes sometimes omit standard Settings activities.
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
            if ("appassets.androidplatform.net".equals(uri.getHost())
                    && uri.getPath() != null
                    && uri.getPath().startsWith("/assets/")) {
                String assetPath = uri.getPath().substring("/assets/".length());
                try {
                    InputStream stream = assets.open(assetPath);
                    String extension = MimeTypeMap.getFileExtensionFromUrl(assetPath);
                    String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
                    if (mime == null) {
                        mime = assetPath.endsWith(".json") ? "application/json" : "text/plain";
                    }
                    return new WebResourceResponse(mime, "UTF-8", stream);
                } catch (IOException ignored) {
                    return null;
                }
            }
            return null;
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            if (!request.isForMainFrame()) return false;
            Uri uri = request.getUrl();
            return !"appassets.androidplatform.net".equals(uri.getHost());
        }
    }
}
