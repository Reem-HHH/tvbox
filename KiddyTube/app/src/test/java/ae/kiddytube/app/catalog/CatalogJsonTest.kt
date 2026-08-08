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
        "omar_hana",
        "mini_muslim",
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
        "spacetoon",
        "moda_modi",
        "smarta",
        "fulla",
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
        "dawood_tabarak",
        "dawood_tabarak_plain",
        "dawood_tabarak_memorize",
        "dawood_juz_28",
        "dawood_juz_27",
        "dawood_juz_26"
    )

    @Test
    fun roundTripSeedChannels() {
        val seed = DefaultChannels.seed()
        val json = CatalogJson.encode(seed)
        val decoded = CatalogJson.decode(json)
        assertEquals(seed.size, decoded.size)
        assertEquals("omar_hana", decoded.first().id)
        assertEquals("dawood_juz_26", decoded.last().id)
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
    fun seedVersionFourteenAddsPreschoolBatch() {
        assertEquals(14, DefaultChannels.SEED_VERSION)
        val seed = DefaultChannels.seed()
        assertEquals(showIds, seed.map { it.id })
        retiredIds.forEach { id ->
            assertFalse(seed.any { it.id == id })
        }

        assertEquals("omar_hana", seed.first().id)
        assertTrue(seed.first { it.id == "omar_hana" }.videos.any { it.id == "T6ggVnk1JZg" })

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
        assertTrue(dora.videos.any { it.id == "7bqSFXuEUgo" })
        assertTrue(dora.videos.any { it.id == "gFTaVxUynsQ" })

        val fulla = seed.first { it.id == "fulla" }
        assertEquals("Fulla / فلة", fulla.title)
        assertEquals("UUif2El0DYcJY9uP4DrST0Bw", fulla.youtubePlaylistId)
        assertTrue(fulla.videos.any { it.id == "l7YnIRtwypM" })
        assertTrue(fulla.videos.any { it.id == "DEpSoa72zYw" })

        val barney = seed.first { it.id == "barney" }
        assertTrue(barney.videos.any { it.id == "HoS5Dv4kAx8" })
        assertTrue(barney.videos.any { it.id == "eb7yLV9moeU" })

        val peppa = seed.first { it.id == "peppa" }
        assertTrue(peppa.videos.any { it.id == "XAK5n8XUmfM" })
        assertTrue(peppa.videos.any { it.id == "t7dTdE8Aqtw" })
        assertTrue(peppa.videos.none { it.title.contains("Jail", ignoreCase = true) })

        val smarta = seed.first { it.id == "smarta" }
        assertEquals("سمارتا وحقيبتها العجيبة", smarta.title)
        assertTrue(smarta.youtubePlaylistId.isNullOrBlank())
        assertTrue(smarta.videos.any { it.id == "USLdtIWQrLU" })
        assertTrue(smarta.videos.any { it.id == "xIFNnxZD5IQ" })

        val twirly = seed.first { it.id == "twirlywoos" }
        assertEquals("Twirlywoos", twirly.title)
        assertEquals("UU6-m1hdh8xEu-XBJK3v1TPg", twirly.youtubePlaylistId)
        assertTrue(twirly.videos.any { it.id == "yS4vFgys9-U" })
        assertTrue(twirly.videos.any { it.id == "Ya45-PIVjhA" })
        assertEquals(11, smarta.videos.size)

        val fruit = seed.first { it.id == "dancing_fruit" }
        assertEquals("Dancing Fruit", fruit.title)
        assertTrue(fruit.youtubePlaylistId.isNullOrBlank())
        assertTrue(fruit.videos.any { it.id == "7mR81x2Fk7g" })
        assertTrue(fruit.videos.any { it.id == "kAxdvigZtw8" })
        assertEquals(6, fruit.videos.size)

        val toyor = seed.first { it.id == "toyor_baby" }
        assertEquals("طيور بيبي", toyor.title)
        assertTrue(toyor.youtubePlaylistId.isNullOrBlank())
        assertFalse(toyor.followUploads)
        assertTrue(toyor.videos.any { it.id == "_tN--Xk4kaE" })
        assertTrue(toyor.videos.any { it.id == "UA6sLNgWRtI" })
        assertEquals(R.drawable.tile_toyor_baby, toyor.iconRes)

        val pingu = seed.first { it.id == "pingu" }
        assertEquals("UUM88mtSE0zRTn5ae4EbYcuw", pingu.youtubePlaylistId)
        assertTrue(pingu.videos.any { it.id == "fWb-pNyPzdo" })
        assertFalse(pingu.followUploads)

        val daniel = seed.first { it.id == "daniel_tiger" }
        assertEquals("UUDqgSnRMGVx3dP4sn3ATZMA", daniel.youtubePlaylistId)
        assertTrue(daniel.videos.any { it.id == "OrNlkDVk_PA" })

        val duggee = seed.first { it.id == "hey_duggee" }
        assertEquals("UUj_mFUb-47d9QNiJ5556LjQ", duggee.youtubePlaylistId)
        assertTrue(duggee.videos.any { it.id == "W4oqUjPj-pI" })

        val numbers = seed.first { it.id == "numberblocks" }
        assertEquals("UUPlwvN0w4qFSP1FllALB92w", numbers.youtubePlaylistId)
        assertTrue(numbers.videos.any { it.id == "jVeYnCehEFE" })
        assertTrue(numbers.videos.any { it.id == "aJzaNIpbUZo" })

        val pocoyo = seed.first { it.id == "pocoyo" }
        assertEquals("UUhT6ex4rsEDXjJKW7wJAb8w", pocoyo.youtubePlaylistId)
        assertTrue(pocoyo.videos.any { it.id == "CwL_mEsASGY" })
        assertTrue(pocoyo.videos.any { it.id == "eDu9RdFhcg4" })

        assertEquals(R.drawable.tile_zakaria, seed.first { it.id == "zakaria" }.iconRes)
        assertEquals(R.drawable.tile_kiki, seed.first { it.id == "kiki_nadoush" }.iconRes)
        assertEquals(R.drawable.tile_lego_duplo, seed.first { it.id == "lego_duplo" }.iconRes)

        assertTrue(seed.first { it.id == "adam_mishmish" }.videos.any { it.id == "FurzMF0L6QI" })
        assertTrue(seed.first { it.id == "zakaria" }.videos.size == 5)
        assertTrue(seed.first { it.id == "lego_duplo" }.videos.any { it.id == "fwg0UIw0Efs" })

        val dawood = seed.filter { it.id.startsWith("dawood_") }
        assertEquals(18, dawood.size)
        dawood.forEach { ch ->
            assertFalse("${ch.id} needs playlist id", ch.youtubePlaylistId.isNullOrBlank())
            assertFalse(ch.followUploads)
            assertEquals(R.drawable.tile_dawood, ch.iconRes)
            assertEquals(R.drawable.tile_dawood, ch.resolvedIconRes())
        }
        listOf(
            "dawood_tabarak",
            "dawood_tabarak_plain",
            "dawood_tabarak_memorize",
            "dawood_juz_28",
            "dawood_juz_27",
            "dawood_juz_26"
        ).forEach { id ->
            assertFalse("$id should default off", seed.first { it.id == id }.enabled)
        }
        assertTrue(seed.first { it.id == "dawood_juz_amma" }.enabled)
        assertEquals(
            "PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR",
            seed.first { it.id == "dawood_juz_amma" }.youtubePlaylistId
        )
        assertEquals(
            "PLKhm8Z5pXdOWeVW24vPIRcmyWJJI3JOLC",
            seed.first { it.id == "dawood_stories" }.youtubePlaylistId
        )
        assertEquals("PLJBjyx9DErqk", seed.first { it.id == "dawood_juz_26" }.youtubePlaylistId)
    }

    @Test
    fun mergeDisablesOlderDawoodAjzaFromSeed() {
        val existing = DefaultChannels.seed().map {
            if (it.id == "dawood_tabarak" || it.id == "dawood_juz_26") {
                it.copy(enabled = true)
            } else it
        }
        val merged = DefaultChannels.mergeSeedUpdates(existing)
        assertFalse(merged.first { it.id == "dawood_tabarak" }.enabled)
        assertFalse(merged.first { it.id == "dawood_juz_26" }.enabled)
        assertTrue(merged.first { it.id == "dawood_juz_amma" }.enabled)
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
