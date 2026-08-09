package ae.kiddytube.app.catalog

import ae.kiddytube.app.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CatalogJsonTest {
    private val retiredIds = setOf(
        "arabic_cartoons",
        "learn_arabic",
        "islamic_kids",
        "playtime",
        "fulla",
        "dawood_juz_amma",
        "dawood_juz_amma_plain",
        "dawood_juz_amma_repeat",
        "dawood_juz_amma_selection",
        "dawood_juz_amma_memorize",
        "dawood_juz_amma_3d",
        "dawood_stories",
        "dawood_teaches_me",
        "dawood_and_me",
        "dawood_secrets_industry",
        "dawood_quranic_games",
        "dawood_quran_quiz",
        "dawood_tabarak",
        "dawood_tabarak_plain",
        "dawood_tabarak_memorize",
        "dawood_juz_28",
        "dawood_juz_27",
        "dawood_juz_26"
    )

    private val showIds = listOf(
        "omar_hana",
        "mini_muslim",
        "dawood",
        "kids_music",
        "spacetoon",
        "moda_modi",
        "smarta",
        "toyor_jana",
        "adam_mishmish",
        "zakaria",
        "kiki_nadoush",
        "rayan",
        "sweet_kalima",
        "abata",
        "sara_duck",
        "twirlywoos",
        "barney",
        "dora",
        "peppa",
        "lego_duplo",
        "play_doh",
        "toy_kitchen",
        "dancing_fruit",
        "toyor_baby",
        "pingu",
        "daniel_tiger",
        "hey_duggee",
        "numberblocks",
        "pocoyo",
        "cocomelon",
        "masha",
        "mansour",
        "maruko",
        "live_makkah",
        "live_quran",
        "masha_ar",
        "blippi_ar",
        "disney_songs",
        "disney_songs_ar"
    )

    @Test
    fun roundTripSeedChannels() {
        val seed = DefaultChannels.seed()
        val json = CatalogJson.encode(seed)
        val decoded = CatalogJson.decode(json)
        assertEquals(seed.size, decoded.size)
        assertEquals("omar_hana", decoded.first().id)
        assertEquals("disney_songs_ar", decoded.last().id)
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
    fun seedVersionSeventeenAddsTwirlywoosEpisodes() {
        assertEquals(20, DefaultChannels.SEED_VERSION)
        val twirly = DefaultChannels.seed().first { it.id == "twirlywoos" }
        assertTrue(twirly.videos.any { it.id == "wAFiVXz1NNw" })
        assertTrue(twirly.videos.any { it.id == "Wg0JkKmQY6A" })
        assertTrue(twirly.videos.size >= 9)
    }

    @Test
    fun mergeEnablesFollowUploadsAndNumberblocksSeason1Playlist() {
        val existing = listOf(
            ContentChannel(
                id = "numberblocks",
                title = "Numberblocks",
                iconRes = R.drawable.tile_numberblocks,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "UUPlwvN0w4qFSP1FllALB92w",
                followUploads = false,
                playlistManagedByParent = false,
                sortOrder = 37,
                videos = listOf(
                    VideoItem("jVeYnCehEFE", "One", youtubeVideoId = "jVeYnCehEFE")
                )
            ),
            ContentChannel(
                id = "dora",
                title = "Dora the Explorer",
                iconRes = R.drawable.tile_dora,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "UUkvPyGW-gsYucCK37UR0q2g",
                followUploads = false,
                playlistManagedByParent = false,
                sortOrder = 20,
                videos = listOf(
                    VideoItem("7bqSFXuEUgo", "Dora", youtubeVideoId = "7bqSFXuEUgo")
                )
            )
        )
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        val numberblocks = merged.first { it.id == "numberblocks" }
        assertEquals("PL9swKX1PviEr9UfByZqJYiN8KX3AXqyXm", numberblocks.youtubePlaylistId)
        assertTrue(numberblocks.followUploads)
        assertTrue(numberblocks.videos.any { it.id == "Ap5kgJ-bpEQ" })
        assertTrue(merged.first { it.id == "dora" }.followUploads)
    }

    @Test
    fun mergeKeepsParentManagedFollowUploadsOff() {
        val existing = listOf(
            ContentChannel(
                id = "numberblocks",
                title = "Numberblocks",
                iconRes = R.drawable.tile_numberblocks,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "UUPlwvN0w4qFSP1FllALB92w",
                followUploads = false,
                playlistManagedByParent = true,
                sortOrder = 37,
                videos = listOf(
                    VideoItem("jVeYnCehEFE", "One", youtubeVideoId = "jVeYnCehEFE")
                )
            )
        )
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        val numberblocks = merged.first { it.id == "numberblocks" }
        assertFalse(numberblocks.followUploads)
        assertEquals("UUPlwvN0w4qFSP1FllALB92w", numberblocks.youtubePlaylistId)
    }

    @Test
    fun seedVersionEighteenEnablesDailyFollowAndNumberblocksSeason1() {
        assertEquals(20, DefaultChannels.SEED_VERSION)
        val seed = DefaultChannels.seed()
        assertTrue(seed.any { it.id == "maruko" })
        val maruko = seed.first { it.id == "maruko" }
        assertEquals("ماروكو الصغيرة", maruko.title)
        assertTrue(maruko.videos.any { it.id == "OMbPlfL2VMY" })
        assertTrue(seed.any { it.id == "live_makkah" })
        assertTrue(seed.any { it.id == "disney_songs" })
        assertTrue(seed.any { it.id == "disney_songs_ar" })
        assertEquals(showIds, seed.map { it.id })
        retiredIds.forEach { id ->
            assertFalse(seed.any { it.id == id })
        }

        assertEquals("omar_hana", seed.first().id)
        assertTrue(seed.first { it.id == "omar_hana" }.videos.any { it.id == "T6ggVnk1JZg" })

        val dawood = seed.first { it.id == "dawood" }
        assertEquals("داوود", dawood.title)
        assertEquals("PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR", dawood.youtubePlaylistId)
        assertTrue(dawood.followUploads)
        assertEquals(R.drawable.tile_dawood, dawood.iconRes)
        assertEquals(1, seed.count { it.id == "dawood" || it.id.startsWith("dawood_") })

        val kidsMusic = seed.first { it.id == "kids_music" }
        assertEquals("Kids Music", kidsMusic.title)
        assertTrue(kidsMusic.youtubePlaylistId.isNullOrBlank())
        assertFalse(kidsMusic.followUploads)
        assertTrue(kidsMusic.videos.any { it.id == "wyOJfLSeZIE" })
        assertTrue(kidsMusic.videos.any { it.id == "5wnNBQAkc-A" })
        assertTrue(kidsMusic.videos.any { it.id == "ISSlEZyIRFw" })
        assertEquals(R.drawable.tile_kids_music, kidsMusic.iconRes)

        val songs = seed.first { it.id == "spacetoon" }
        assertEquals("Spacetoon أناشيد", songs.title)
        assertTrue(songs.youtubePlaylistId.isNullOrBlank())
        assertTrue(songs.videos.any { it.id == "-_Kz-hseLkc" })
        assertTrue(songs.videos.any { it.id == "dB95J8Pa49c" })
        assertTrue(songs.videos.none { it.id == "V2upg7iZvT0" })

        val moda = seed.first { it.id == "moda_modi" }
        assertEquals("مودا مودي", moda.title)
        assertTrue(moda.videos.any { it.id == "V2upg7iZvT0" })

        val dora = seed.first { it.id == "dora" }
        assertEquals("Dora the Explorer", dora.title)
        assertEquals("UUkvPyGW-gsYucCK37UR0q2g", dora.youtubePlaylistId)
        assertTrue(dora.followUploads)
        assertTrue(dora.videos.any { it.id == "7bqSFXuEUgo" })

        val numberblocks = seed.first { it.id == "numberblocks" }
        assertEquals("PL9swKX1PviEr9UfByZqJYiN8KX3AXqyXm", numberblocks.youtubePlaylistId)
        assertTrue(numberblocks.followUploads)
        assertTrue(numberblocks.videos.any { it.id == "Ap5kgJ-bpEQ" })

        val toyorJana = seed.first { it.id == "toyor_jana" }
        assertEquals("طيور الجنة", toyorJana.title)
        assertTrue(toyorJana.videos.any { it.id == "7GgZjoF0D2I" })

        val coco = seed.first { it.id == "cocomelon" }
        assertEquals("UUbCmjCuTUZos6Inko4u57UQ", coco.youtubePlaylistId)
        assertTrue(coco.videos.any { it.id == "e_04ZrNroTo" })

        val masha = seed.first { it.id == "masha" }
        assertTrue(masha.videos.any { it.id == "qBp1rCz_yQU" })

        val mansour = seed.first { it.id == "mansour" }
        assertEquals("منصور", mansour.title)
        assertTrue(mansour.videos.any { it.id == "TohnJvGq-cU" })

        assertEquals(R.drawable.tile_zakaria, seed.first { it.id == "zakaria" }.iconRes)
        assertTrue(seed.first { it.id == "adam_mishmish" }.videos.any { it.id == "FurzMF0L6QI" })
    }

    @Test
    fun mergeDropsSplitDawoodTilesForSingleHub() {
        val legacySplit = listOf(
            ContentChannel(
                id = "dawood_juz_amma",
                title = "داوود — جزء عم",
                iconRes = R.drawable.tile_dawood,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR",
                sortOrder = 2
            ),
            ContentChannel(
                id = "dawood_stories",
                title = "داوود — قصص",
                iconRes = R.drawable.tile_dawood,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "PLKhm8Z5pXdOWeVW24vPIRcmyWJJI3JOLC",
                sortOrder = 8
            ),
            ContentChannel(
                id = "dawood_tabarak",
                title = "داوود — جزء تبارك",
                iconRes = R.drawable.tile_dawood,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "PLKhm8Z5pXdOXqBC9Gmh2MVTEVQj6x_4or",
                enabled = true,
                sortOrder = 50
            )
        )
        val merged = DefaultChannels.mergeSeedUpdates(legacySplit)
        assertFalse(merged.any { it.id.startsWith("dawood_") })
        val hub = merged.first { it.id == "dawood" }
        assertEquals("داوود", hub.title)
        assertEquals("PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR", hub.youtubePlaylistId)
        assertTrue(merged.any { it.id == "kids_music" })
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
        assertTrue(merged.any { it.id == "toyor_jana" })
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
            ),
            ContentChannel(
                id = "fulla",
                title = "Fulla / فلة",
                iconRes = R.drawable.tile_fulla,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                youtubePlaylistId = "UUif2El0DYcJY9uP4DrST0Bw",
                sortOrder = 17
            )
        )
        val merged = DefaultChannels.mergeSeedUpdates(legacy)
        retiredIds.forEach { id ->
            assertFalse(merged.any { it.id == id })
        }
        assertTrue(merged.any { it.id == "dora" })
        assertTrue(merged.any { it.id == "toyor_jana" })
        assertTrue(merged.any { it.id == "smarta" })
        assertTrue(merged.any { it.id == "adam_mishmish" })
        assertTrue(merged.any { it.id == "omar_hana" })
        assertTrue(merged.any { it.id == "lego_duplo" })
        assertTrue(merged.any { it.id == "cocomelon" })
        assertTrue(merged.any { it.id == "masha" })
        assertTrue(merged.any { it.id == "mansour" })
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
    fun newestOrNullMatchesNewestFirstHead() {
        val a = VideoItem("a", "Old", youtubeVideoId = "a", publishedAtMs = 1_000L)
        val b = VideoItem("b", "New", youtubeVideoId = "b", publishedAtMs = 9_000L)
        val c = VideoItem("c", "Unknown", youtubeVideoId = "c", publishedAtMs = null)
        val list = listOf(a, c, b)
        assertEquals(list.newestFirst().firstOrNull()?.id, list.newestOrNull()?.id)
        assertNull(emptyList<VideoItem>().newestOrNull())
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
    fun roundTripTitleContainingClosingBracket() {
        val channel = DefaultChannels.seed().first().copy(
            videos = listOf(
                VideoItem(
                    id = "abc123xyz__",
                    title = "Surah [1] and part ] end",
                    youtubeVideoId = "abc123xyz__"
                )
            )
        )
        val decoded = CatalogJson.decodeOrNull(CatalogJson.encode(listOf(channel)))
        assertEquals("Surah [1] and part ] end", decoded!!.first().videos.first().title)
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
