package ae.kidstv.launcher;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;

/**
 * Parent unlock trigger sequence, PIN verification, and failure backoff.
 * Pure logic so it can be unit-tested without Android instrumentation.
 */
public final class ParentUnlockGate {
    // Values match android.view.KeyEvent constants used by the remote path.
    public static final int KEYCODE_DPAD_UP = 19;
    public static final int KEYCODE_DPAD_DOWN = 20;
    public static final int KEYCODE_DPAD_LEFT = 21;
    public static final int KEYCODE_DPAD_RIGHT = 22;
    public static final int KEYCODE_DPAD_CENTER = 23;

    public static final int[] TRIGGER_SEQUENCE = {
            KEYCODE_DPAD_UP,
            KEYCODE_DPAD_UP,
            KEYCODE_DPAD_DOWN,
            KEYCODE_DPAD_DOWN,
            KEYCODE_DPAD_LEFT,
            KEYCODE_DPAD_RIGHT,
            KEYCODE_DPAD_LEFT,
            KEYCODE_DPAD_RIGHT,
            KEYCODE_DPAD_CENTER
    };

    public static final int MIN_PIN_LENGTH = 4;
    public static final int MAX_PIN_LENGTH = 8;
    public static final long KEY_IDLE_TIMEOUT_MS = 3_000L;
    public static final int MAX_FAILURES_BEFORE_LOCKOUT = 5;
    public static final long BASE_LOCKOUT_MS = 30_000L;

    private final Deque<Integer> recentKeys = new ArrayDeque<>();
    private long lastKeyAtMs;
    private int failureCount;
    private long lockedUntilMs;

    public ParentUnlockGate() {
        this(0, 0L);
    }

    public ParentUnlockGate(int failureCount, long lockedUntilMs) {
        this.failureCount = Math.max(0, failureCount);
        this.lockedUntilMs = Math.max(0L, lockedUntilMs);
    }

    public int getFailureCount() {
        return failureCount;
    }

    public long getLockedUntilMs() {
        return lockedUntilMs;
    }

    public void restoreRateLimitState(int failureCount, long lockedUntilMs) {
        this.failureCount = Math.max(0, failureCount);
        this.lockedUntilMs = Math.max(0L, lockedUntilMs);
    }

    public void clearKeys() {
        recentKeys.clear();
        lastKeyAtMs = 0L;
    }

    /**
     * Records a key and returns true when the discreet trigger sequence matches.
     */
    public boolean recordKeyAndCheckTrigger(int keyCode, long nowMs) {
        if (lastKeyAtMs > 0L && nowMs - lastKeyAtMs > KEY_IDLE_TIMEOUT_MS) {
            recentKeys.clear();
        }
        lastKeyAtMs = nowMs;
        recentKeys.addLast(keyCode);
        while (recentKeys.size() > TRIGGER_SEQUENCE.length) {
            recentKeys.removeFirst();
        }
        return matchesTrigger();
    }

    public boolean matchesTrigger() {
        if (recentKeys.size() != TRIGGER_SEQUENCE.length) {
            return false;
        }
        int index = 0;
        for (int key : recentKeys) {
            if (key != TRIGGER_SEQUENCE[index++]) {
                return false;
            }
        }
        return true;
    }

    /**
     * Clears spent lockouts so a new attempt window can begin.
     */
    public void refreshLockout(long nowMs) {
        if (lockedUntilMs > 0L && nowMs >= lockedUntilMs) {
            lockedUntilMs = 0L;
            failureCount = 0;
        }
    }

    public boolean isLockedOut(long nowMs) {
        refreshLockout(nowMs);
        return nowMs < lockedUntilMs;
    }

    public long remainingLockoutMs(long nowMs) {
        return Math.max(0L, lockedUntilMs - nowMs);
    }

    public boolean verifyPin(String pin, String saltHex, String expectedHashHex) {
        if (!isValidPinFormat(pin) || saltHex == null || expectedHashHex == null) {
            return false;
        }
        String actual = hashPin(pin, saltHex);
        return actual != null && actual.equalsIgnoreCase(expectedHashHex);
    }

    /**
     * Records a failed PIN attempt. Returns true if this failure engaged lockout.
     */
    public boolean registerFailure(long nowMs) {
        failureCount++;
        if (failureCount >= MAX_FAILURES_BEFORE_LOCKOUT) {
            int rounds = failureCount - MAX_FAILURES_BEFORE_LOCKOUT + 1;
            long multiplier = 1L << Math.min(rounds - 1, 4); // 30s, 60s, 120s, 240s, 480s
            lockedUntilMs = nowMs + BASE_LOCKOUT_MS * multiplier;
            return true;
        }
        return false;
    }

    public void registerSuccess() {
        failureCount = 0;
        lockedUntilMs = 0L;
        clearKeys();
    }

    public static boolean isValidPinFormat(String pin) {
        if (pin == null) {
            return false;
        }
        int length = pin.length();
        if (length < MIN_PIN_LENGTH || length > MAX_PIN_LENGTH) {
            return false;
        }
        for (int i = 0; i < length; i++) {
            char c = pin.charAt(i);
            if (c < '0' || c > '9') {
                return false;
            }
        }
        return true;
    }

    public static String newSaltHex() {
        byte[] salt = new byte[16];
        new SecureRandom().nextBytes(salt);
        return toHex(salt);
    }

    public static String hashPin(String pin, String saltHex) {
        if (pin == null || saltHex == null) {
            return null;
        }
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(fromHex(saltHex));
            digest.update(pin.getBytes(StandardCharsets.UTF_8));
            return toHex(digest.digest());
        } catch (NoSuchAlgorithmException | IllegalArgumentException e) {
            return null;
        }
    }

    private static String toHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format(Locale.US, "%02x", b));
        }
        return sb.toString();
    }

    private static byte[] fromHex(String hex) {
        String value = hex.trim();
        if ((value.length() & 1) != 0) {
            throw new IllegalArgumentException("odd hex length");
        }
        byte[] out = new byte[value.length() / 2];
        for (int i = 0; i < out.length; i++) {
            int index = i * 2;
            out[i] = (byte) Integer.parseInt(value.substring(index, index + 2), 16);
        }
        return out;
    }
}
