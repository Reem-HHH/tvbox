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
        "dora",
        "fulla",
        "smarta",
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
        "dancing_fruit",
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
    fun seedVersionTenIncludesDancingFruit() {
        assertEquals(10, DefaultChannels.SEED_VERSION)
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

        val dora = seed.first { it.id == "dora" }
        assertEquals("Dora the Explorer", dora.title)
        assertEquals("UUkvPyGW-gsYucCK37UR0q2g", dora.youtubePlaylistId)
        assertFalse(dora.followUploads)

        val fulla = seed.first { it.id == "fulla" }
        assertEquals("Fulla / فلة", fulla.title)
        assertEquals("UUif2El0DYcJY9uP4DrST0Bw", fulla.youtubePlaylistId)

        val smarta = seed.first { it.id == "smarta" }
        assertEquals("سمارتا وحقيبتها العجيبة", smarta.title)
        assertTrue(smarta.youtubePlaylistId.isNullOrBlank())
        assertTrue(smarta.videos.any { it.id == "USLdtIWQrLU" })
        assertTrue(smarta.videos.any { it.id == "xIFNnxZD5IQ" })
        assertEquals(11, smarta.videos.size)

        val fruit = seed.first { it.id == "dancing_fruit" }
        assertEquals("Dancing Fruit", fruit.title)
        assertTrue(fruit.youtubePlaylistId.isNullOrBlank())
        assertTrue(fruit.videos.any { it.id == "7mR81x2Fk7g" })
        assertTrue(fruit.videos.any { it.id == "kAxdvigZtw8" })
        assertEquals(6, fruit.videos.size)

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
        assertTrue(merged.any { it.id == "dora" })
        assertTrue(merged.any { it.id == "fulla" })
        assertTrue(merged.any { it.id == "smarta" })
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
        assertTrue(merged.any { it.id == "dora" })
        assertTrue(merged.any { it.id == "fulla" })
        assertTrue(merged.any { it.id == "smarta" })
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
    fun mergePreservesParentPlaylistOverride() {
        val existing = DefaultChannels.seed().map {
            if (it.id == "peppa") it.copy(youtubePlaylistId = "PLcustomParent") else it
        }
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        assertEquals("PLcustomParent", merged.first { it.id == "peppa" }.youtubePlaylistId)
    }

    @Test
    fun mergeDoesNotReattachClearedParentPlaylist() {
        val existing = DefaultChannels.seed().map {
            if (it.id == "peppa") {
                it.copy(
                    youtubePlaylistId = null,
                    videos = it.videos.ifEmpty {
                        listOf(VideoItem("manual1", "Kept", youtubeVideoId = "manual1", manual = true))
                    },
                    playlistManagedByParent = true
                )
            } else it
        }
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        val peppa = merged.first { it.id == "peppa" }
        assertTrue(peppa.youtubePlaylistId.isNullOrBlank())
        assertTrue(peppa.playlistManagedByParent)
    }

    @Test
    fun mergeSeedUpdatesFillsEmptyUnmanagedPlaylists() {
        val empty = DefaultChannels.seed().map {
            it.copy(
                youtubePlaylistId = null,
                videos = emptyList(),
                playlistManagedByParent = false
            )
        }
        val merged = DefaultChannels.mergeSeedUpdates(empty)
        assertTrue(merged.any { !it.youtubePlaylistId.isNullOrBlank() })
        assertTrue(
            merged.first { it.id == "sara_duck" }.videos.isNotEmpty() ||
                !merged.first { it.id == "sara_duck" }.youtubePlaylistId.isNullOrBlank()
        )
        assertTrue(!merged.first { it.id == "omar_hana" }.youtubePlaylistId.isNullOrBlank())
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
    fun newestFirstOrdersByPublishedAt() {
        val a = VideoItem("a", "Old", youtubeVideoId = "a", publishedAtMs = 1_000L)
        val b = VideoItem("b", "New", youtubeVideoId = "b", publishedAtMs = 9_000L)
        val c = VideoItem("c", "Unknown", youtubeVideoId = "c", publishedAtMs = null)
        val sorted = listOf(a, c, b).newestFirst()
        assertEquals(listOf("b", "a", "c"), sorted.map { it.id })
    }

    @Test
    fun roundTripPublishedAtMs() {
        val channel = DefaultChannels.seed().first().copy(
            videos = listOf(
                VideoItem(
                    id = "vid1",
                    title = "Dated",
                    youtubeVideoId = "vid1",
                    publishedAtMs = 1_700_000_000_000L
                )
            )
        )
        val decoded = CatalogJson.decode(CatalogJson.encode(listOf(channel))).first()
        assertEquals(1_700_000_000_000L, decoded.videos.first().publishedAtMs)
    }

    @Test
    fun corruptJsonFallsBackToSeed() {
        val decoded = CatalogJson.decode("not-json")
        assertTrue(decoded.isNotEmpty())
        assertEquals(DefaultChannels.seed().size, decoded.size)
    }

    @Test
    fun corruptJsonDecodeOrNullReturnsNull() {
        assertEquals(null, CatalogJson.decodeOrNull("not-json"))
        assertEquals(null, CatalogJson.decodeOrNull("{broken"))
        assertEquals(null, CatalogJson.decodeOrNull(""))
    }

    @Test
    fun roundTripFollowUploadsAndManualFlags() {
        val channel = DefaultChannels.seed().first().copy(
            followUploads = true,
            playlistManagedByParent = true,
            videos = listOf(
                VideoItem(
                    id = "dQw4w9WgXcQ",
                    title = "Manual",
                    youtubeVideoId = "dQw4w9WgXcQ",
                    manual = true
                )
            )
        )
        val decoded = CatalogJson.decode(CatalogJson.encode(listOf(channel))).first()
        assertTrue(decoded.followUploads)
        assertTrue(decoded.playlistManagedByParent)
        assertTrue(decoded.videos.first().manual)
        assertTrue(decoded.videos.first().allowSeek)
        assertEquals(DefaultChannels.iconResFor(channel.id), decoded.iconRes)
        assertEquals(decoded.iconRes, decoded.resolvedIconRes())
    }

    @Test
    fun roundTripAllowSeekFalse() {
        val channel = DefaultChannels.seed().first().copy(
            videos = listOf(
                VideoItem(
                    id = "dQw4w9WgXcQ",
                    title = "No seek",
                    youtubeVideoId = "dQw4w9WgXcQ",
                    allowSeek = false
                )
            )
        )
        val decoded = CatalogJson.decode(CatalogJson.encode(listOf(channel))).first()
        assertEquals(false, decoded.videos.first().allowSeek)
    }

    @Test
    fun resolvedIconResFallsBackById() {
        val channel = ContentChannel(
            id = "barney",
            title = "Barney",
            iconRes = 0,
            sourceType = SourceType.YOUTUBE_PLAYLIST
        )
        assertEquals(DefaultChannels.iconResFor("barney"), channel.resolvedIconRes())
    }
}
