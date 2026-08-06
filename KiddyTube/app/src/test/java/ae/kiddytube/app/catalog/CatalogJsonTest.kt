package ae.kiddytube.app.catalog

import ae.kiddytube.app.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CatalogJsonTest {
    private val retiredIds = setOf(
        "arabic_cartoons",
        "learn_arabic",
        "islamic_kids",
        "playtime"
    )

    private val showIds = listOf(
        "barney",
        "spacetoon",
        "moda_modi",
        "sara_duck",
        "peppa",
        "adam_mishmish",
        "kiki_nadoush",
        "zakaria",
        "rayan",
        "sweet_kalima",
        "abata",
        "lego_duplo",
        "play_doh",
        "toy_kitchen",
        "mini_muslim",
        "omar_hana"
    )

    @Test
    fun roundTripSeedChannels() {
        val seed = DefaultChannels.seed()
        val json = CatalogJson.encode(seed)
        val decoded = CatalogJson.decode(json)
        assertEquals(seed.size, decoded.size)
        assertEquals("barney", decoded.first().id)
        assertEquals("omar_hana", decoded.last().id)
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
    fun seedVersionSixIsPerShow() {
        assertEquals(6, DefaultChannels.SEED_VERSION)
        val seed = DefaultChannels.seed()
        assertEquals(showIds, seed.map { it.id })
        retiredIds.forEach { id ->
            assertFalse(seed.any { it.id == id })
        }

        val songs = seed.first { it.id == "spacetoon" }
        assertEquals("Spacetoon أناشيد", songs.title)
        assertTrue(songs.youtubePlaylistId.isNullOrBlank())
        assertTrue(songs.videos.any { it.id == "-_Kz-hseLkc" })
        assertTrue(songs.videos.none { it.id == "V2upg7iZvT0" })

        val moda = seed.first { it.id == "moda_modi" }
        assertEquals("مودا مودي", moda.title)
        assertTrue(moda.videos.any { it.id == "V2upg7iZvT0" })

        assertTrue(seed.first { it.id == "adam_mishmish" }.videos.any { it.id == "FurzMF0L6QI" })
        assertTrue(seed.first { it.id == "zakaria" }.videos.size == 5)
        assertTrue(seed.first { it.id == "lego_duplo" }.videos.any { it.id == "fwg0UIw0Efs" })
        assertTrue(seed.first { it.id == "omar_hana" }.videos.any { it.id == "T6ggVnk1JZg" })
        assertFalse(seed.first { it.id == "omar_hana" }.youtubePlaylistId.isNullOrBlank())
    }

    @Test
    fun mergeClearsOldSpacetoonUploadsPlaylist() {
        val existing = listOf(
            ContentChannel(
                id = "spacetoon",
                title = "Spacetoon",
                iconRes = R.drawable.tile_spacetoon,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "UUuQKih3Ac3NABADQKQdeV6A",
                videos = listOf(VideoItem("old", "Old dump", youtubeVideoId = "old")),
                sortOrder = 1
            )
        )
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        val songs = merged.first { it.id == "spacetoon" }
        assertEquals("Spacetoon أناشيد", songs.title)
        assertTrue(songs.youtubePlaylistId.isNullOrBlank())
        assertTrue(songs.videos.any { it.id == "-_Kz-hseLkc" })
        assertTrue(songs.videos.none { it.id == "old" })
        assertTrue(merged.any { it.id == "moda_modi" })
        assertTrue(merged.any { it.id == "omar_hana" })
    }

    @Test
    fun mergeDropsRetiredGenericChannels() {
        val legacy = listOf(
            ContentChannel(
                id = "arabic_cartoons",
                title = "Arabic Cartoons",
                iconRes = R.drawable.tile_arabic,
                sourceType = SourceType.YOUTUBE_VIDEO_LIST,
                videos = listOf(VideoItem("x", "x", youtubeVideoId = "x")),
                sortOrder = 5
            ),
            ContentChannel(
                id = "learn_arabic",
                title = "Learn Arabic",
                iconRes = R.drawable.tile_learn_arabic,
                sourceType = SourceType.YOUTUBE_VIDEO_LIST,
                sortOrder = 6
            ),
            ContentChannel(
                id = "islamic_kids",
                title = "Islamic Kids",
                iconRes = R.drawable.tile_islamic,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "UUlegacy",
                sortOrder = 8
            ),
            ContentChannel(
                id = "playtime",
                title = "Playtime",
                iconRes = R.drawable.tile_playtime,
                sourceType = SourceType.YOUTUBE_VIDEO_LIST,
                sortOrder = 9
            )
        )
        val merged = DefaultChannels.mergeSeedUpdates(legacy)
        retiredIds.forEach { id ->
            assertFalse(merged.any { it.id == id })
        }
        assertTrue(merged.any { it.id == "adam_mishmish" })
        assertTrue(merged.any { it.id == "omar_hana" })
        assertTrue(merged.any { it.id == "lego_duplo" })
    }

    @Test
    fun mergeAppendsMissingSeedVideos() {
        val existing = DefaultChannels.seed().map {
            if (it.id == "zakaria") {
                it.copy(videos = listOf(it.videos.first()))
            } else it
        }
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        assertTrue(merged.first { it.id == "zakaria" }.videos.size > 1)
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
        assertTrue(!merged.first { it.id == "omar_hana" }.youtubePlaylistId.isNullOrBlank())
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
