package ae.kiddytube.app.tv

import ae.kiddytube.app.catalog.RecentWatchItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URLDecoder

class WatchNextPublisherTest {

    @Test
    fun playUriStringEncodesQueryParts() {
        val raw = WatchNextPublisher.buildPlayUriString(
            RecentWatchItem(
                videoId = "vid-1",
                channelId = "ch & 1",
                title = "Hello & Go",
                youtubeVideoId = "dQw4w9WgXcQ",
                directUrl = null,
                watchedAtMs = 1L
            )
        )
        assertTrue(raw.startsWith("kiddytube://play?"))
        val query = raw.substringAfter('?')
        val map = query.split('&').associate {
            val (k, v) = it.split('=', limit = 2)
            k to URLDecoder.decode(v, Charsets.UTF_8.name())
        }
        assertEquals("ch & 1", map["channelId"])
        assertEquals("vid-1", map["videoId"])
        assertEquals("Hello & Go", map["title"])
        assertEquals("dQw4w9WgXcQ", map["youtubeId"])
    }
}
