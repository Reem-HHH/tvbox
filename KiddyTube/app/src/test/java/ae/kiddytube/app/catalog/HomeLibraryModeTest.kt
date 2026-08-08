package ae.kiddytube.app.catalog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeLibraryModeTest {
    @Test
    fun fromStoredDefaultsUnknownToChannels() {
        assertEquals(HomeLibraryMode.CHANNELS, HomeLibraryMode.fromStored(null))
        assertEquals(HomeLibraryMode.CHANNELS, HomeLibraryMode.fromStored("nope"))
        assertEquals(HomeLibraryMode.MIX_VIDEOS, HomeLibraryMode.fromStored("MIX_VIDEOS"))
    }

    @Test
    fun flattenEnabledVideosSkipsDisabledAndIsSeedStable() {
        val channels = listOf(
            ContentChannel(
                id = "a",
                title = "A",
                iconRes = 0,
                sourceType = SourceType.YOUTUBE_VIDEO_LIST,
                enabled = true,
                videos = listOf(
                    VideoItem(id = "1", title = "One", youtubeVideoId = "1"),
                    VideoItem(id = "2", title = "Two", youtubeVideoId = "2")
                )
            ),
            ContentChannel(
                id = "b",
                title = "B",
                iconRes = 0,
                sourceType = SourceType.YOUTUBE_VIDEO_LIST,
                enabled = false,
                videos = listOf(
                    VideoItem(id = "3", title = "Three", youtubeVideoId = "3")
                )
            )
        )
        val first = flattenEnabledVideos(channels, seed = 42L)
        val second = flattenEnabledVideos(channels, seed = 42L)
        assertEquals(setOf("1", "2"), first.map { it.video.id }.toSet())
        assertTrue(first.all { it.channelId == "a" })
        assertEquals(first.map { it.video.id }, second.map { it.video.id })
    }
}
