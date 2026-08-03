package ae.kidstv.launcher;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

public class AssetPathSanitizerTest {
    @Test
    public void allowsWhitelistedAssets() {
        assertEquals("player.html", AssetPathSanitizer.resolveAllowedAsset("player.html"));
        assertEquals("channels.json", AssetPathSanitizer.resolveAllowedAsset("channels.json"));
        assertEquals("player.html", AssetPathSanitizer.resolveAllowedAsset("/player.html"));
        assertEquals("channels.json", AssetPathSanitizer.resolveAllowedAsset("Channels.JSON"));
    }

    @Test
    public void rejectsTraversalAndUnknownPaths() {
        assertNull(AssetPathSanitizer.resolveAllowedAsset("../player.html"));
        assertNull(AssetPathSanitizer.resolveAllowedAsset("foo/../../channels.json"));
        assertNull(AssetPathSanitizer.resolveAllowedAsset("secret.txt"));
        assertNull(AssetPathSanitizer.resolveAllowedAsset("subdir/player.html"));
        assertNull(AssetPathSanitizer.resolveAllowedAsset("player.html\\x"));
        assertNull(AssetPathSanitizer.resolveAllowedAsset("player.html\0"));
        assertNull(AssetPathSanitizer.resolveAllowedAsset(""));
        assertNull(AssetPathSanitizer.resolveAllowedAsset(null));
    }
}
