package ae.kiddytube.app.catalog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RecentWatchLogicTest {

    @Test
    fun prependMovesDuplicateToFront() {
        val older = item("a", channelId = "c1", watchedAtMs = 1)
        val newer = item("a", channelId = "c1", watchedAtMs = 2, title = "Again")
        val other = item("b", channelId = "c1", watchedAtMs = 3)
        val out = RecentWatchLogic.prepend(listOf(older, other), newer)
        assertEquals(listOf("a", "b"), out.map { it.videoId })
        assertEquals("Again", out.first().title)
        assertEquals(2L, out.first().watchedAtMs)
    }

    @Test
    fun prependCapsAtMax() {
        val existing = (1..RecentWatchLogic.MAX_ITEMS).map {
            item("v$it", watchedAtMs = it.toLong())
        }
        val out = RecentWatchLogic.prepend(existing, item("fresh", watchedAtMs = 999))
        assertEquals(RecentWatchLogic.MAX_ITEMS, out.size)
        assertEquals("fresh", out.first().videoId)
        assertTrue(out.none { it.videoId == "v${RecentWatchLogic.MAX_ITEMS}" })
    }

    @Test
    fun prependDedupesByYoutubeId() {
        val existing = item(
            videoId = "local-1",
            youtubeVideoId = "dQw4w9WgXcQ",
            watchedAtMs = 1
        )
        val incoming = item(
            videoId = "local-2",
            youtubeVideoId = "dQw4w9WgXcQ",
            watchedAtMs = 2
        )
        val out = RecentWatchLogic.prepend(listOf(existing), incoming)
        assertEquals(1, out.size)
        assertEquals("local-2", out.first().videoId)
    }

    @Test
    fun resolvePlayableDropsMissingAndDisabled() {
        val settings = CatalogSettings(
            channels = listOf(
                ContentChannel(
                    id = "on",
                    title = "On",
                    iconRes = 0,
                    sourceType = SourceType.YOUTUBE_VIDEO_LIST,
                    enabled = true,
                    videos = listOf(
                        VideoItem(id = "keep", title = "Keep", youtubeVideoId = "AAAAAAAAAAA")
                    )
                ),
                ContentChannel(
                    id = "off",
                    title = "Off",
                    iconRes = 0,
                    sourceType = SourceType.YOUTUBE_VIDEO_LIST,
                    enabled = false,
                    videos = listOf(
                        VideoItem(id = "gone", title = "Gone", youtubeVideoId = "BBBBBBBBBBB")
                    )
                )
            )
        )
        val recent = listOf(
            item("keep", channelId = "on", youtubeVideoId = "AAAAAAAAAAA"),
            item("gone", channelId = "off", youtubeVideoId = "BBBBBBBBBBB"),
            item("missing", channelId = "on")
        )
        val playable = RecentWatchLogic.resolvePlayable(recent, settings)
        assertEquals(1, playable.size)
        assertEquals("keep", playable.first().second.id)
        assertEquals("Keep", playable.first().first.title)
    }

    @Test
    fun jsonRoundTrip() {
        val items = listOf(
            item(
                "v1",
                channelId = "c1",
                title = "Hello \"Kids\"",
                thumbnailUrl = "https://example.com/a.jpg",
                youtubeVideoId = "AAAAAAAAAAA",
                watchedAtMs = 42
            ),
            item(
                "v2",
                channelId = "c2",
                title = "Direct",
                directUrl = "https://cdn.example.com/a.mp4",
                watchedAtMs = 43
            )
        )
        val encoded = RecentWatchJson.encode(items)
        val decoded = RecentWatchJson.decode(encoded)
        assertEquals(items, decoded)
    }

    private fun item(
        videoId: String,
        channelId: String = "ch",
        title: String = videoId,
        thumbnailUrl: String? = null,
        youtubeVideoId: String? = null,
        directUrl: String? = null,
        watchedAtMs: Long = 0L
    ) = RecentWatchItem(
        videoId = videoId,
        channelId = channelId,
        title = title,
        thumbnailUrl = thumbnailUrl,
        youtubeVideoId = youtubeVideoId,
        directUrl = directUrl,
        watchedAtMs = watchedAtMs
    )
}
