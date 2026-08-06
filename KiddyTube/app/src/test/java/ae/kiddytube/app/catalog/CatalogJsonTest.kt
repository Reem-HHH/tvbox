package ae.kiddytube.app.catalog

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CatalogJsonTest {
    @Test
    fun roundTripSeedChannels() {
        val seed = DefaultChannels.seed()
        val json = CatalogJson.encode(seed)
        val decoded = CatalogJson.decode(json)
        assertEquals(seed.size, decoded.size)
        assertEquals("barney", decoded.first().id)
        assertEquals("playtime", decoded.last().id)
    }

    @Test
    fun seedHasPlaylistsOrStarterVideos() {
        DefaultChannels.seed().forEach { ch ->
            val hasPlaylist = !ch.youtubePlaylistId.isNullOrBlank()
            val hasVideos = ch.videos.isNotEmpty()
            assertTrue("${ch.id} needs playlist or starter videos", hasPlaylist || hasVideos)
        }
    }

    @Test
    fun seedVersionFourOrganizesCuratedVideos() {
        assertEquals(4, DefaultChannels.SEED_VERSION)
        val seed = DefaultChannels.seed()
        assertTrue(seed.any { it.id == "playtime" })
        assertTrue(seed.first { it.id == "learn_arabic" }.videos.size >= 10)
        assertTrue(seed.first { it.id == "islamic_kids" }.videos.any { it.id == "T6ggVnk1JZg" })
        assertTrue(seed.first { it.id == "playtime" }.videos.any { it.id == "F4ICHmkVGtQ" })
    }

    @Test
    fun mergeAppendsMissingSeedVideos() {
        val existing = DefaultChannels.seed().map {
            if (it.id == "learn_arabic") {
                it.copy(videos = listOf(it.videos.first()))
            } else it
        }
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        assertTrue(merged.first { it.id == "learn_arabic" }.videos.size > 1)
    }

    @Test
    fun mergeSeedUpdatesFillsEmptyPlaylists() {
        val empty = DefaultChannels.seed().map {
            it.copy(youtubePlaylistId = null, videos = emptyList())
        }
        val merged = DefaultChannels.mergeSeedUpdates(empty)
        assertTrue(merged.any { !it.youtubePlaylistId.isNullOrBlank() })
        assertTrue(merged.first { it.id == "sara_duck" }.videos.isNotEmpty() ||
            !merged.first { it.id == "sara_duck" }.youtubePlaylistId.isNullOrBlank())
        assertTrue(!merged.first { it.id == "learn_arabic" }.youtubePlaylistId.isNullOrBlank())
    }

    @Test
    fun mergePreservesParentPlaylistOverride() {
        val existing = DefaultChannels.seed().map {
            if (it.id == "peppa") it.copy(youtubePlaylistId = "PLcustomParent") else it
        }
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        assertEquals("PLcustomParent", merged.first { it.id == "peppa" }.youtubePlaylistId)
    }

    @Test
    fun roundTripWithVideos() {
        val channel = DefaultChannels.seed().first().copy(
            youtubePlaylistId = "PLtest123",
            videos = listOf(
                VideoItem(
                    id = "dQw4w9WgXcQ",
                    title = "Sample",
                    youtubeVideoId = "dQw4w9WgXcQ"
                )
            )
        )
        val decoded = CatalogJson.decode(CatalogJson.encode(listOf(channel))).first()
        assertEquals("PLtest123", decoded.youtubePlaylistId)
        assertEquals(1, decoded.videos.size)
        assertEquals("Sample", decoded.videos.first().title)
    }

    @Test
    fun corruptJsonFallsBackToSeed() {
        val decoded = CatalogJson.decode("not-json")
        assertTrue(decoded.isNotEmpty())
        assertEquals(DefaultChannels.seed().size, decoded.size)
    }
}
