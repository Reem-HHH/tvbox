package ae.kiddytube.app.sources

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaUrlValidatorTest {
    @Test
    fun acceptsDirectMedia() {
        assertTrue(MediaUrlValidator.isDirectMediaUrl("https://cdn.example.com/a.mp4"))
        assertTrue(MediaUrlValidator.isDirectMediaUrl("https://cdn.example.com/a.m3u8"))
        assertTrue(MediaUrlValidator.isDirectMediaUrl("https://cdn.example.com/stream.mpd"))
        assertTrue(MediaUrlValidator.isDirectMediaUrl("https://cdn.example.com/a.mp4?token=xyz"))
    }

    @Test
    fun rejectsHttpsWithoutMediaExtension() {
        assertFalse(MediaUrlValidator.isDirectMediaUrl("https://cdn.example.com/video"))
        assertFalse(MediaUrlValidator.isDirectMediaUrl("https://cdn.example.com/watch.html"))
        assertFalse(MediaUrlValidator.isDirectMediaUrl("https://example.com/"))
    }

    @Test
    fun rejectsHttpCleartext() {
        assertFalse(MediaUrlValidator.isDirectMediaUrl("http://cdn.example.com/a.mp4"))
        assertFalse(MediaUrlValidator.isDirectMediaUrl("http://192.168.1.10/kids.m3u8"))
    }

    @Test
    fun rejectsDriveViewAndYoutubeWatch() {
        assertFalse(
            MediaUrlValidator.isDirectMediaUrl(
                "https://drive.google.com/file/d/132lEYuY3MVIvhRLbXco7UrDG4cXd8Cyl/view"
            )
        )
        assertFalse(MediaUrlValidator.isDirectMediaUrl("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        assertFalse(MediaUrlValidator.isDirectMediaUrl("https://www.youtube.com/shorts/abcdef"))
        assertFalse(MediaUrlValidator.isDirectMediaUrl(null))
    }
}

class YoutubeUrlParserTest {
    @Test
    fun extractsVideoId() {
        assertEquals("dQw4w9WgXcQ", YoutubeUrlParser.extractVideoId("dQw4w9WgXcQ"))
        assertEquals(
            "dQw4w9WgXcQ",
            YoutubeUrlParser.extractVideoId("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        )
        assertEquals("dQw4w9WgXcQ", YoutubeUrlParser.extractVideoId("https://youtu.be/dQw4w9WgXcQ"))
        assertNull(YoutubeUrlParser.extractVideoId("nope"))
    }

    @Test
    fun validatesElevenCharIdsOnly() {
        assertTrue(YoutubeUrlParser.isValidVideoId("dQw4w9WgXcQ"))
        assertFalse(YoutubeUrlParser.isValidVideoId("short"))
        assertFalse(YoutubeUrlParser.isValidVideoId("too_long_id!!"))
        assertFalse(YoutubeUrlParser.isValidVideoId("bad id!!!!"))
        assertFalse(YoutubeUrlParser.isValidVideoId(null))
    }

    @Test
    fun extractsPlaylistId() {
        assertEquals(
            "PLabcdef",
            YoutubeUrlParser.extractPlaylistId(
                "https://www.youtube.com/playlist?list=PLabcdef"
            )
        )
        assertEquals("PLabcdef", YoutubeUrlParser.extractPlaylistId("PLabcdef"))
    }

    @Test
    fun parsesCsv() {
        val ids = YoutubeUrlParser.parseVideoIdsCsv("dQw4w9WgXcQ, abcdefghijk")
        assertEquals(2, ids.size)
    }
}
