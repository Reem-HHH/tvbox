package ae.kiddytube.app.catalog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ApiKeyResolverTest {
    @Test
    fun parentKeyWinsOverBuildConfig() {
        assertEquals(
            "parent-key",
            ApiKeyResolver.effective("parent-key", "build-key")
        )
    }

    @Test
    fun fallsBackToBuildConfig() {
        assertEquals(
            "build-key",
            ApiKeyResolver.effective(null, "build-key")
        )
        assertEquals(
            "build-key",
            ApiKeyResolver.effective("  ", "build-key")
        )
    }

    @Test
    fun blankEverywhereReturnsNull() {
        assertNull(ApiKeyResolver.effective(null, ""))
        assertNull(ApiKeyResolver.effective(" ", "  "))
    }
}
