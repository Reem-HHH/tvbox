package ae.kidstv.launcher;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/**
 * Restricts WebView asset loads to an explicit whitelist and rejects traversal.
 */
public final class AssetPathSanitizer {
    private static final Set<String> ALLOWED_ASSETS = Collections.unmodifiableSet(
            new HashSet<>(Arrays.asList("player.html", "channels.json"))
    );

    private AssetPathSanitizer() {
    }

    /**
     * @param rawPath path after the {@code /assets/} prefix (may include junk)
     * @return sanitized asset name to open, or {@code null} if rejected
     */
    public static String resolveAllowedAsset(String rawPath) {
        if (rawPath == null || rawPath.isEmpty()) {
            return null;
        }
        if (rawPath.indexOf('\0') >= 0) {
            return null;
        }
        if (rawPath.contains("..") || rawPath.indexOf('\\') >= 0) {
            return null;
        }

        String path = rawPath;
        while (path.startsWith("/")) {
            path = path.substring(1);
        }
        if (path.isEmpty() || path.contains("/")) {
            return null;
        }

        String normalized = path.toLowerCase(Locale.US);
        if (!ALLOWED_ASSETS.contains(normalized)) {
            return null;
        }
        // Preserve canonical casing from the whitelist entry.
        for (String allowed : ALLOWED_ASSETS) {
            if (allowed.equals(normalized)) {
                return allowed;
            }
        }
        return null;
    }
}
