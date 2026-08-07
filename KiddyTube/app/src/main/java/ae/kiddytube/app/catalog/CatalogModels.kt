package ae.kiddytube.app.catalog

import ae.kiddytube.app.R
import ae.kiddytube.app.sources.YoutubeUrlParser

enum class SourceType {
    YOUTUBE_PLAYLIST,
    YOUTUBE_VIDEO_LIST,
    DIRECT_URL
}

data class VideoItem(
    val id: String,
    val title: String,
    val thumbnailUrl: String? = null,
    val youtubeVideoId: String? = null,
    val directUrl: String? = null,
    /** Epoch millis when the video was published on YouTube; null if unknown. */
    val publishedAtMs: Long? = null,
    /** True when a parent added this item manually (survives playlist refresh). */
    val manual: Boolean = false,
    /** When true, remote FF/RW and D-pad seek work for this item. */
    val allowSeek: Boolean = true
) {
    fun isYoutube(): Boolean = !youtubeVideoId.isNullOrBlank()
    fun isDirect(): Boolean = !directUrl.isNullOrBlank()
}

data class ContentChannel(
    val id: String,
    val title: String,
    val iconRes: Int,
    val sourceType: SourceType,
    val enabled: Boolean = true,
    val youtubePlaylistId: String? = null,
    val videos: List<VideoItem> = emptyList(),
    val sortOrder: Int = 0,
    /** When true, launch/TTL sync follows the linked playlist/uploads feed. */
    val followUploads: Boolean = false,
    /** When true, seed upgrades must not re-attach a cleared playlist id. */
    val playlistManagedByParent: Boolean = false
) {
    fun resolvedIconRes(): Int =
        if (iconRes != 0) iconRes else DefaultChannels.iconResFor(id)
}

/**
 * Parent-curated starter catalog. Each channel is one named show (not a generic mix).
 * Playlist IDs point at official channel upload feeds where the whole channel is that show;
 * parents should review/replace in the parent dashboard.
 *
 * Uploads playlist id = replace leading "UC" with "UU" on a channel id.
 */
object DefaultChannels {
    /** Bump when seed playlist/video IDs change so existing installs merge updates once. */
    const val SEED_VERSION = 11

    /** Former Spacetoon Arabic uploads feed — too broad for toddlers; cleared on upgrade. */
    private const val SPACETOON_UPLOADS_PLAYLIST = "UUuQKih3Ac3NABADQKQdeV6A"

    /** Pre–v6 generic category channels removed when upgrading to per-show seeds. */
    private val RETIRED_CHANNEL_IDS = setOf(
        "arabic_cartoons",
        "learn_arabic",
        "islamic_kids",
        "playtime"
    )

    fun seed(): List<ContentChannel> = listOf(
        playlistChannel(
            id = "barney",
            title = "Barney & Friends",
            icon = R.drawable.tile_barney,
            order = 0,
            playlistId = uploadsOf("UCelJG1JV-pKYGOG3AM17Wvg")
        ),
        ContentChannel(
            id = "spacetoon",
            title = "Spacetoon أناشيد",
            iconRes = R.drawable.tile_spacetoon,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            youtubePlaylistId = null,
            sortOrder = 1,
            videos = listOf(
                yt("-_Kz-hseLkc", "كتاب الله"),
                yt("YoAU-tciuVs", "يا طيبة — المدينة المنورة"),
                yt("g7LjhyO7CEw", "رمضان أقبل طيباً"),
                yt("INZMVhnVlRM", "أهلاً رمضان يا شهر الإحسان"),
                yt("BojfVe5G6GM", "هلال رمضان — يوسف إسلام"),
                yt("Jh4gl0obMK0", "رمضان 2020 — أطل الفجر بالبشر")
            )
        ),
        ContentChannel(
            id = "moda_modi",
            title = "مودا مودي",
            iconRes = R.drawable.tile_moda_modi,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 2,
            videos = listOf(
                yt("V2upg7iZvT0", "مودا مودي — وأتى رمضان"),
                yt("_SdwG5nE0Ik", "مودا مودي — رمضان عاد"),
                yt("7DUiKe_UneA", "عائلة مودا مودي — رمضان تجلّى"),
                yt("8cRwwgOzHF4", "أغنية عيد الفطر من مودا مودي")
            )
        ),
        playlistChannel(
            id = "dora",
            title = "Dora the Explorer",
            icon = R.drawable.tile_dora,
            order = 3,
            playlistId = uploadsOf("UCkvPyGW-gsYucCK37UR0q2g")
        ),
        playlistChannel(
            id = "fulla",
            title = "Fulla / فلة",
            icon = R.drawable.tile_fulla,
            order = 4,
            playlistId = uploadsOf("UCif2El0DYcJY9uP4DrST0Bw")
        ),
        ContentChannel(
            id = "smarta",
            title = "سمارتا وحقيبتها العجيبة",
            iconRes = R.drawable.tile_smarta,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 5,
            videos = listOf(
                yt("USLdtIWQrLU", "سمارتا — الحلقة 1"),
                yt("efHkhsi675M", "سمارتا — الحلقة 2"),
                yt("nP-F7A54oVc", "سمارتا — الحلقة 3"),
                yt("xIFNnxZD5IQ", "ساعة من المغامرات — المجموعة الأولى"),
                yt("Ui2P60B2WJE", "مجموعة الحلقات الثالثة"),
                yt("rf8FgLed_E8", "مجموعة الحلقات الرابعة"),
                yt("YgXdgZ2Wd0I", "مجموعة الحلقات الخامسة"),
                yt("5xftaiEK_7Y", "مجموعة الحلقات السادسة"),
                yt("nPBlRc5heBc", "مجموعة الحلقات السابعة"),
                yt("wcIW_tbTB3M", "مجموعة الحلقات الثامنة"),
                yt("kJULJaJjD4M", "مجموعة الحلقات العاشرة")
            )
        ),
        ContentChannel(
            id = "sara_duck",
            title = "Sarah & Duck",
            iconRes = R.drawable.tile_sara_duck,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC3OUMU3s7Oy6Ta0wnpZFBWw"),
            sortOrder = 6,
            videos = listOf(
                yt("EOj_7ZYmCOI", "Cheer Up Donkey — Sarah & Duck"),
                yt("e69BdjwjDxk", "Bouncy Ball — Sarah & Duck"),
                yt("zGn6PwRkD7c", "Sarah, Duck and the Penguins")
            )
        ),
        playlistChannel(
            id = "peppa",
            title = "Peppa Pig",
            icon = R.drawable.tile_peppa,
            order = 7,
            playlistId = uploadsOf("UCAOtE1V7Ots4DjM8JLlrYgg")
        ),
        ContentChannel(
            id = "adam_mishmish",
            title = "Adam & Mishmish",
            iconRes = R.drawable.tile_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 8,
            videos = listOf(
                yt("FurzMF0L6QI", "Animal Sounds Songs (68 min) — Adam & Mishmish"),
                yt("docDippkI-Q", "Farm Animal Songs — Adam & Mishmish"),
                yt("etAPDF2i9s0", "Arabic Letters with Animals — Adam & Mishmish")
            )
        ),
        ContentChannel(
            id = "kiki_nadoush",
            title = "Kiki wa Nadoush",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 9,
            videos = listOf(
                yt("EI3yLs6A-Qk", "Learn Arabic Colors — Kiki wa Nadoush")
            )
        ),
        ContentChannel(
            id = "zakaria",
            title = "Zakaria",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 10,
            videos = listOf(
                yt("LocumA_zI0c", "Learn Colors with Cars — Zakaria"),
                yt("sGw7Fs7oRvw", "Vehicle Names in Arabic — Zakaria"),
                yt("XCp_1eTPnrM", "Arabic Numbers 1–10 — Zakaria"),
                yt("0MGqhiLQbxI", "Write Arabic Alphabet أ–ص — Zakaria"),
                yt("5v7A2AXzCY0", "Write Arabic Alphabet ض–ي — Zakaria")
            )
        ),
        ContentChannel(
            id = "rayan",
            title = "Rayan",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 11,
            videos = listOf(
                yt("yPhFBBMWbPU", "Shapes & Directions in Arabic — Rayan")
            )
        ),
        ContentChannel(
            id = "sweet_kalima",
            title = "Sweet Kalima",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 12,
            videos = listOf(
                yt("En3OJwCqHx8", "Shapes, Colors & Numbers — Sweet Kalima")
            )
        ),
        ContentChannel(
            id = "abata",
            title = "Abata",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 13,
            videos = listOf(
                yt("sVtaIloYxvw", "Arabic Alphabet with Chalk — Abata")
            )
        ),
        ContentChannel(
            id = "lego_duplo",
            title = "LEGO DUPLO",
            iconRes = R.drawable.tile_playtime,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 14,
            videos = listOf(
                yt("fwg0UIw0Efs", "LEGO DUPLO Numbers & Colors in Arabic"),
                yt("w7aZLVaLTlM", "LEGO DUPLO Vehicles & Colors"),
                yt("01JxHFDBdzE", "LEGO DUPLO Creative Animals Unbox"),
                yt("a0uPqr_iASU", "LEGO DUPLO Animal Build"),
                yt("jvCdmPsAn40", "LEGO DUPLO Balancing Tree"),
                yt("xvxQeQfdifk", "LEGO DUPLO Marble Run")
            )
        ),
        ContentChannel(
            id = "play_doh",
            title = "Play-Doh",
            iconRes = R.drawable.tile_playtime,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 15,
            videos = listOf(
                yt("2FyKZKNls4c", "Play-Doh Cookie Man & Shapes"),
                yt("8581xy-tGqw", "Play-Doh Rainbow Ice Cream"),
                yt("kS9fxiOdiGs", "Marble Run Plasticine Race"),
                yt("F4ICHmkVGtQ", "Magic Marble Run Compilation")
            )
        ),
        ContentChannel(
            id = "toy_kitchen",
            title = "Toy Kitchen",
            iconRes = R.drawable.tile_playtime,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 16,
            videos = listOf(
                yt("mSUJM2naI7I", "Travel Kitchen Playset Unboxing"),
                yt("TL3e2UZQxPE", "Kitchen Set & Toy Fruits")
            )
        ),
        ContentChannel(
            id = "dancing_fruit",
            title = "Dancing Fruit",
            iconRes = R.drawable.tile_dancing_fruit,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 17,
            videos = listOf(
                yt("7mR81x2Fk7g", "Dancing Fruit! — 1 Hour Mix — Hey Bear Sensory"),
                yt("ALaQvK7KZOY", "Dance, Colors and Counting — Dancing Fruit & Funky Veggies"),
                yt("kAxdvigZtw8", "Best of Dancing Fruit and Funky Veggies — Dance Party"),
                yt("b65MoVwANq4", "Disco Fruit Party — Dancing Fruit with Cumbia"),
                yt("KPP4Cfupzhs", "Smoothie Mix — Fun Dance Video"),
                yt("xOUdk2LdXrs", "Let's Dance! — Avocadosaurus and Party Strawberries")
            )
        ),
        ContentChannel(
            id = "mini_muslim",
            title = "Mini Muslim",
            iconRes = R.drawable.tile_mini_muslim,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCIDYe6rgdROl77DDevNIcPA"),
            sortOrder = 18,
            videos = listOf(
                yt("4VpiuY_C5Ok", "Ramadan Around The World — MiniMuslims"),
                yt("vB3ffnqdNVs", "Islamic Songs for Kids (45 min) — MiniMuslims"),
                yt("WyxekrpqcEQ", "Islamic Songs for Kids (30 min) — MiniMuslims")
            )
        ),
        ContentChannel(
            id = "omar_hana",
            title = "Omar & Hana",
            iconRes = R.drawable.tile_islamic,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC178EmfQAV3OT-UpuO6WUMg"),
            sortOrder = 19,
            videos = listOf(
                yt("T6ggVnk1JZg", "Omar & Hana 15 Minutes Song"),
                yt("iJtM9bzScJY", "Omar & Hana — Dua & Salah (Acapella)"),
                yt("HvzYeFB0lB4", "Breakfasting — Omar & Hana"),
                yt("AkSrzSwK2wE", "Omar & Hana Arabic — Please Come Home Dad")
            )
        ),
        // Dawood TV (@DawoodKidsTV) — one app channel per educational playlist.
        playlistChannel(
            id = "dawood_juz_amma",
            title = "داوود — جزء عم",
            icon = R.drawable.tile_dawood,
            order = 20,
            playlistId = "PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR"
        ),
        playlistChannel(
            id = "dawood_juz_amma_plain",
            title = "داوود — جزء عم بدون تكرار",
            icon = R.drawable.tile_dawood,
            order = 21,
            playlistId = "PLKhm8Z5pXdOXO8wm-pQ670wmKnoC5Be5g"
        ),
        playlistChannel(
            id = "dawood_juz_amma_repeat",
            title = "داوود — جزء عم تكرار ٣٠ دقيقة",
            icon = R.drawable.tile_dawood,
            order = 22,
            playlistId = "PLKhm8Z5pXdOUcx5ho4DuPRtBvu8wlIkB6"
        ),
        playlistChannel(
            id = "dawood_juz_amma_selection",
            title = "داوود — تعليم جزء عم (سور مختارة)",
            icon = R.drawable.tile_dawood,
            order = 23,
            playlistId = "PLKhm8Z5pXdOUKa4_VNwykMYSfreDijDKX"
        ),
        playlistChannel(
            id = "dawood_juz_amma_memorize",
            title = "داوود — حفظ جزء عم",
            icon = R.drawable.tile_dawood,
            order = 24,
            playlistId = "PLKhm8Z5pXdOXjBYqLvu2L2YCghTEPkMJj"
        ),
        playlistChannel(
            id = "dawood_juz_amma_3d",
            title = "Dawood TV — Juz 30 (3D EN)",
            icon = R.drawable.tile_dawood,
            order = 25,
            playlistId = "PLKhm8Z5pXdOV_cEl6uIyQWAjB6mfyKpZl"
        ),
        playlistChannel(
            id = "dawood_stories",
            title = "داوود — قصص",
            icon = R.drawable.tile_dawood,
            order = 26,
            playlistId = "PLKhm8Z5pXdOWeVW24vPIRcmyWJJI3JOLC"
        ),
        playlistChannel(
            id = "dawood_teaches_me",
            title = "داوود يعلمني",
            icon = R.drawable.tile_dawood,
            order = 27,
            playlistId = "PLKhm8Z5pXdOWOOCtznZHhFVIVUD4GK4wf"
        ),
        playlistChannel(
            id = "dawood_and_me",
            title = "أنا و داوود",
            icon = R.drawable.tile_dawood,
            order = 28,
            playlistId = "PLKhm8Z5pXdOW8-ft9ncMR9XBFTtTxLujw"
        ),
        playlistChannel(
            id = "dawood_secrets_industry",
            title = "داوود — أسرار الصناعة",
            icon = R.drawable.tile_dawood,
            order = 29,
            playlistId = "PLKhm8Z5pXdOXpOLnMI0XNq-IjbNeS4CrB"
        ),
        playlistChannel(
            id = "dawood_quranic_games",
            title = "داوود — ألعاب قرآنية",
            icon = R.drawable.tile_dawood,
            order = 30,
            playlistId = "PLKhm8Z5pXdOVpBgwR82zlLRIJFQdiS3gU"
        ),
        playlistChannel(
            id = "dawood_quran_quiz",
            title = "داوود — مسابقات قرآنية",
            icon = R.drawable.tile_dawood,
            order = 31,
            playlistId = "PLKhm8Z5pXdOXJPE0FwCbyKXQW6EjldHxN"
        ),
        playlistChannel(
            id = "dawood_tabarak",
            title = "داوود — جزء تبارك",
            icon = R.drawable.tile_dawood,
            order = 32,
            playlistId = "PLKhm8Z5pXdOXqBC9Gmh2MVTEVQj6x_4or"
        ),
        playlistChannel(
            id = "dawood_tabarak_plain",
            title = "داوود — جزء تبارك بدون تكرار",
            icon = R.drawable.tile_dawood,
            order = 33,
            playlistId = "PLKhm8Z5pXdOWcPJqYwIEy3cySbyATyyLE"
        ),
        playlistChannel(
            id = "dawood_tabarak_memorize",
            title = "داوود — حفظ جزء تبارك",
            icon = R.drawable.tile_dawood,
            order = 34,
            playlistId = "PLKhm8Z5pXdOXR75WBeBFDve5gSR_wfA1o"
        ),
        playlistChannel(
            id = "dawood_juz_28",
            title = "داوود — جزء ٢٨",
            icon = R.drawable.tile_dawood,
            order = 35,
            playlistId = "PLKhm8Z5pXdOWx9JleIpX8EakeXcwLFTvm"
        ),
        playlistChannel(
            id = "dawood_juz_27",
            title = "داوود — جزء ٢٧",
            icon = R.drawable.tile_dawood,
            order = 36,
            playlistId = "PLKhm8Z5pXdOUiE1L6BBQAYIn-phTTHNpT"
        ),
        playlistChannel(
            id = "dawood_juz_26",
            title = "داوود — جزء ٢٦",
            icon = R.drawable.tile_dawood,
            order = 37,
            playlistId = "PLJBjyx9DErqk"
        )
    )

    /**
     * Apply newer seed playlist/video defaults onto an existing catalog without
     * wiping parent overrides. Appends missing seed videos; adds new seed channels;
     * drops retired generic category channels.
     */
    fun mergeSeedUpdates(existing: List<ContentChannel>): List<ContentChannel> {
        val byId = existing
            .filterNot { it.id in RETIRED_CHANNEL_IDS }
            .associateBy { it.id }
            .toMutableMap()

        for (seed in seed()) {
            val current = byId[seed.id]
            if (current == null) {
                byId[seed.id] = seed
                continue
            }

            // Drop the broad Spacetoon uploads feed when upgrading to curated nasheeds.
            val clearSpacetoonUploads = seed.id == "spacetoon" &&
                seed.youtubePlaylistId.isNullOrBlank() &&
                current.youtubePlaylistId == SPACETOON_UPLOADS_PLAYLIST

            // Never re-attach a playlist parents cleared or already manage.
            val needsPlaylist = !current.playlistManagedByParent &&
                current.youtubePlaylistId.isNullOrBlank() &&
                !seed.youtubePlaylistId.isNullOrBlank() &&
                current.videos.isEmpty()
            val existingIds = current.videos.map { it.id }.toSet()
            val missingVideos = seed.videos.filter { it.id !in existingIds }
            val titleStale = current.title != seed.title &&
                (seed.id == "spacetoon" || clearSpacetoonUploads)

            if (clearSpacetoonUploads || needsPlaylist || missingVideos.isNotEmpty() || titleStale) {
                val videos = when {
                    clearSpacetoonUploads -> seed.videos
                    current.videos.isEmpty() && seed.videos.isNotEmpty() -> seed.videos
                    missingVideos.isNotEmpty() -> current.videos + missingVideos
                    else -> current.videos
                }
                byId[seed.id] = current.copy(
                    title = if (titleStale || clearSpacetoonUploads) seed.title else current.title,
                    youtubePlaylistId = when {
                        clearSpacetoonUploads -> null
                        needsPlaylist -> seed.youtubePlaylistId
                        else -> current.youtubePlaylistId
                    },
                    videos = videos.newestFirst(),
                    sourceType = when {
                        clearSpacetoonUploads -> seed.sourceType
                        needsPlaylist -> SourceType.YOUTUBE_PLAYLIST
                        else -> current.sourceType
                    },
                    sortOrder = seed.sortOrder,
                    iconRes = seed.iconRes
                )
            } else if (current.sortOrder != seed.sortOrder || current.iconRes != seed.iconRes) {
                byId[seed.id] = current.copy(
                    sortOrder = seed.sortOrder,
                    iconRes = seed.iconRes
                )
            }
        }
        return byId.values.sortedBy { it.sortOrder }
    }

    fun iconResFor(channelId: String): Int =
        seed().firstOrNull { it.id == channelId }?.iconRes ?: R.drawable.tile_placeholder

    private fun playlistChannel(
        id: String,
        title: String,
        icon: Int,
        order: Int,
        playlistId: String
    ) = ContentChannel(
        id = id,
        title = title,
        iconRes = icon,
        sourceType = SourceType.YOUTUBE_PLAYLIST,
        youtubePlaylistId = playlistId,
        sortOrder = order,
        followUploads = false
    )

    private fun uploadsOf(channelId: String): String =
        if (channelId.startsWith("UC")) "UU" + channelId.removePrefix("UC") else channelId

    private fun yt(videoId: String, title: String) = VideoItem(
        id = videoId,
        title = title,
        thumbnailUrl = YoutubeUrlParser.defaultThumbnail(videoId),
        youtubeVideoId = videoId
    )
}

fun VideoItem.youtubeThumbnail(): String? {
    val id = youtubeVideoId ?: return thumbnailUrl
    return YoutubeUrlParser.defaultThumbnail(id)
}

/** Newest YouTube uploads first; items without a known date keep relative order at the end. */
fun List<VideoItem>.newestFirst(): List<VideoItem> =
    mapIndexed { index, item -> index to item }
        .sortedWith(
            compareByDescending<Pair<Int, VideoItem>> { it.second.publishedAtMs ?: Long.MIN_VALUE }
                .thenBy { it.first }
        )
        .map { it.second }
