package ae.kiddytube.app.player

import ae.kiddytube.app.catalog.ContentChannel
import ae.kiddytube.app.catalog.SourceType
import ae.kiddytube.app.catalog.VideoItem
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PlaybackAdvanceTest {

    private fun video(id: String, youtube: String? = id, direct: String? = null) = VideoItem(
        id = id,
        title = id,
        youtubeVideoId = youtube,
        directUrl = direct
    )

    private fun channel(id: String, videos: List<VideoItem>, enabled: Boolean = true) =
        ContentChannel(
            id = id,
            title = id,
            iconRes = 0,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            enabled = enabled,
            videos = videos
        )

    @Test
    fun returnsNextByCatalogOrder() {
        val ch = channel(
            "c1",
            listOf(video("a"), video("b"), video("c"))
        )
        val next = PlaybackAdvance.nextInChannel(
            channels = listOf(ch),
            channelId = "c1",
            currentVideoId = "a"
        )
        assertEquals("b", next?.id)
    }

    @Test
    fun returnsNullOnLastVideo() {
        val ch = channel("c1", listOf(video("a"), video("b")))
        assertNull(
            PlaybackAdvance.nextInChannel(
                channels = listOf(ch),
                channelId = "c1",
                currentVideoId = "b"
            )
        )
    }

    @Test
    fun matchesYoutubeIdWhenVideoIdMissing() {
        val ch = channel(
            "c1",
            listOf(
                video(id = "local-1", youtube = "ytAAA"),
                video(id = "local-2", youtube = "ytBBB")
            )
        )
        val next = PlaybackAdvance.nextInChannel(
            channels = listOf(ch),
            channelId = "c1",
            currentYoutubeId = "ytAAA"
        )
        assertEquals("local-2", next?.id)
    }

    @Test
    fun matchesDirectUrl() {
        val ch = channel(
            "c1",
            listOf(
                video(id = "d1", youtube = null, direct = "https://cdn.example/a.mp4"),
                video(id = "d2", youtube = null, direct = "https://cdn.example/b.mp4")
            )
        )
        val next = PlaybackAdvance.nextInChannel(
            channels = listOf(ch),
            channelId = "c1",
            currentDirectUrl = "https://cdn.example/a.mp4"
        )
        assertEquals("d2", next?.id)
    }

    @Test
    fun ignoresDisabledChannelAndUnknownCurrent() {
        val disabled = channel("c1", listOf(video("a"), video("b")), enabled = false)
        assertNull(
            PlaybackAdvance.nextInChannel(
                channels = listOf(disabled),
                channelId = "c1",
                currentVideoId = "a"
            )
        )
        val enabled = channel("c1", listOf(video("a"), video("b")))
        assertNull(
            PlaybackAdvance.nextInChannel(
                channels = listOf(enabled),
                channelId = "c1",
                currentVideoId = "missing"
            )
        )
    }

    @Test
    fun blankChannelIdReturnsNull() {
        assertNull(
            PlaybackAdvance.nextInChannel(
                channels = listOf(channel("c1", listOf(video("a")))),
                channelId = "",
                currentVideoId = "a"
            )
        )
    }
}
