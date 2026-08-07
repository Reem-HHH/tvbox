package ae.kiddytube.app.sources

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class YoutubeCatalogSourceTest {
    @Test
    fun parseIso8601WithMillis() {
        val ms = YoutubeCatalogSource.parseIso8601ToMillis("2024-06-01T12:30:00.000Z")
        assertNotNull(ms)
        assertEquals(1_717_245_000_000L, ms)
    }

    @Test
    fun parseIso8601WithoutMillis() {
        val ms = YoutubeCatalogSource.parseIso8601ToMillis("2024-06-01T12:30:00Z")
        assertNotNull(ms)
        assertEquals(1_717_245_000_000L, ms)
    }

    @Test
    fun parseIso8601BlankReturnsNull() {
        assertNull(YoutubeCatalogSource.parseIso8601ToMillis(null))
        assertNull(YoutubeCatalogSource.parseIso8601ToMillis(""))
    }

    @Test
    fun summarizeHttpErrorPrefersGoogleMessage() {
        val body = """{"error":{"code":403,"message":"Requests from this Android client application ae.kiddytube.app are blocked."}}"""
        val summary = YoutubeCatalogSource.summarizeHttpError(403, body)
        assertEquals(
            "HTTP 403 Requests from this Android client application ae.kiddytube.app are blocked.",
            summary
        )
    }

    @Test
    fun summarizeHttpErrorFallsBackToBodySnippet() {
        val summary = YoutubeCatalogSource.summarizeHttpError(500, "internal boom")
        assertEquals("HTTP 500 internal boom", summary)
    }
}
