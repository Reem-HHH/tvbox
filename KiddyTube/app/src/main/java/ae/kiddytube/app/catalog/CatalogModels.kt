package ae.kiddytube.app.catalog

import ae.kiddytube.app.R
import ae.kiddytube.app.sources.YoutubeUrlParser

enum class SourceType {
    YOUTUBE_PLAYLIST,
    YOUTUBE_VIDEO_LIST,
    DIRECT_URL
}

/** Kids home: channel tiles vs a flat shuffled video mix. */
enum class HomeLibraryMode {
    CHANNELS,
    MIX_VIDEOS;

    companion object {
        fun fromStored(raw: String?): HomeLibraryMode =
            entries.firstOrNull { it.name == raw } ?: CHANNELS
    }
}

/** Video tile bound to its owning channel (mix home + library → player). */
data class PlayableVideo(
    val channelId: String,
    val video: VideoItem
)

/** Flatten enabled channel libraries and shuffle with a stable seed. */
fun flattenEnabledVideos(
    channels: List<ContentChannel>,
    seed: Long
): List<PlayableVideo> =
    channels
        .filter { it.enabled }
        .flatMap { ch -> ch.videos.map { PlayableVideo(ch.id, it) } }
        .shuffled(kotlin.random.Random(seed))

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
    val playlistManagedByParent: Boolean = false,
    /**
     * Default seek policy for new playlist imports and empty-channel Parent toggle.
     * Kept in sync by [ae.kiddytube.app.catalog.CatalogRepository.setChannelAllowSeek].
     */
    val defaultAllowSeek: Boolean = true,
    /**
     * After Parent "clear synced", do not one-shot re-import just because the library is empty.
     * Cleared when Follow uploads is turned on.
     */
    val suppressEmptyPlaylistImport: Boolean = false
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
    const val SEED_VERSION = 14

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
        // Islamic / Arabic-first home order for preschool installs.
        ContentChannel(
            id = "omar_hana",
            title = "Omar & Hana",
            iconRes = R.drawable.tile_islamic,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC178EmfQAV3OT-UpuO6WUMg"),
            sortOrder = 0,
            videos = listOf(
                yt("T6ggVnk1JZg", "Omar & Hana 15 Minutes Song"),
                yt("iJtM9bzScJY", "Omar & Hana — Dua & Salah (Acapella)"),
                yt("HvzYeFB0lB4", "Breakfasting — Omar & Hana"),
                yt("AkSrzSwK2wE", "Omar & Hana Arabic — Please Come Home Dad")
            )
        ),
        ContentChannel(
            id = "mini_muslim",
            title = "Mini Muslim",
            iconRes = R.drawable.tile_mini_muslim,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCIDYe6rgdROl77DDevNIcPA"),
            sortOrder = 1,
            videos = listOf(
                yt("4VpiuY_C5Ok", "Ramadan Around The World — MiniMuslims"),
                yt("vB3ffnqdNVs", "Islamic Songs for Kids (45 min) — MiniMuslims"),
                yt("WyxekrpqcEQ", "Islamic Songs for Kids (30 min) — MiniMuslims")
            )
        ),
        playlistChannel(
            id = "dawood_juz_amma",
            title = "داوود — جزء عم",
            icon = R.drawable.tile_dawood,
            order = 2,
            playlistId = "PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR"
        ),
        playlistChannel(
            id = "dawood_juz_amma_plain",
            title = "داوود — جزء عم بدون تكرار",
            icon = R.drawable.tile_dawood,
            order = 3,
            playlistId = "PLKhm8Z5pXdOXO8wm-pQ670wmKnoC5Be5g"
        ),
        playlistChannel(
            id = "dawood_juz_amma_repeat",
            title = "داوود — جزء عم تكرار ٣٠ دقيقة",
            icon = R.drawable.tile_dawood,
            order = 4,
            playlistId = "PLKhm8Z5pXdOUcx5ho4DuPRtBvu8wlIkB6"
        ),
        playlistChannel(
            id = "dawood_juz_amma_selection",
            title = "داوود — تعليم جزء عم (سور مختارة)",
            icon = R.drawable.tile_dawood,
            order = 5,
            playlistId = "PLKhm8Z5pXdOUKa4_VNwykMYSfreDijDKX"
        ),
        playlistChannel(
            id = "dawood_juz_amma_memorize",
            title = "داوود — حفظ جزء عم",
            icon = R.drawable.tile_dawood,
            order = 6,
            playlistId = "PLKhm8Z5pXdOXjBYqLvu2L2YCghTEPkMJj"
        ),
        playlistChannel(
            id = "dawood_juz_amma_3d",
            title = "Dawood TV — Juz 30 (3D EN)",
            icon = R.drawable.tile_dawood,
            order = 7,
            playlistId = "PLKhm8Z5pXdOV_cEl6uIyQWAjB6mfyKpZl"
        ),
        playlistChannel(
            id = "dawood_stories",
            title = "داوود — قصص",
            icon = R.drawable.tile_dawood,
            order = 8,
            playlistId = "PLKhm8Z5pXdOWeVW24vPIRcmyWJJI3JOLC"
        ),
        playlistChannel(
            id = "dawood_teaches_me",
            title = "داوود يعلمني",
            icon = R.drawable.tile_dawood,
            order = 9,
            playlistId = "PLKhm8Z5pXdOWOOCtznZHhFVIVUD4GK4wf"
        ),
        playlistChannel(
            id = "dawood_and_me",
            title = "أنا و داوود",
            icon = R.drawable.tile_dawood,
            order = 10,
            playlistId = "PLKhm8Z5pXdOW8-ft9ncMR9XBFTtTxLujw"
        ),
        playlistChannel(
            id = "dawood_secrets_industry",
            title = "داوود — أسرار الصناعة",
            icon = R.drawable.tile_dawood,
            order = 11,
            playlistId = "PLKhm8Z5pXdOXpOLnMI0XNq-IjbNeS4CrB"
        ),
        playlistChannel(
            id = "dawood_quranic_games",
            title = "داوود — ألعاب قرآنية",
            icon = R.drawable.tile_dawood,
            order = 12,
            playlistId = "PLKhm8Z5pXdOVpBgwR82zlLRIJFQdiS3gU"
        ),
        playlistChannel(
            id = "dawood_quran_quiz",
            title = "داوود — مسابقات قرآنية",
            icon = R.drawable.tile_dawood,
            order = 13,
            playlistId = "PLKhm8Z5pXdOXJPE0FwCbyKXQW6EjldHxN"
        ),
        ContentChannel(
            id = "spacetoon",
            title = "Spacetoon أناشيد",
            iconRes = R.drawable.tile_spacetoon,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            youtubePlaylistId = null,
            sortOrder = 14,
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
            sortOrder = 15,
            videos = listOf(
                yt("V2upg7iZvT0", "مودا مودي — وأتى رمضان"),
                yt("_SdwG5nE0Ik", "مودا مودي — رمضان عاد"),
                yt("7DUiKe_UneA", "عائلة مودا مودي — رمضان تجلّى"),
                yt("8cRwwgOzHF4", "أغنية عيد الفطر من مودا مودي")
            )
        ),
        ContentChannel(
            id = "smarta",
            title = "سمارتا وحقيبتها العجيبة",
            iconRes = R.drawable.tile_smarta,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 16,
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
            id = "fulla",
            title = "Fulla / فلة",
            iconRes = R.drawable.tile_fulla,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCif2El0DYcJY9uP4DrST0Bw"),
            sortOrder = 17,
            videos = listOf(
                yt("l7YnIRtwypM", "Fulla Song Yes I did it"),
                yt("tSQCJf2Li3k", "Cook Song — Fulla / أغنية الطبخ"),
                yt("DEpSoa72zYw", "DIY Prayer Set — Fashion with Fulla"),
                yt("RpmN1lCMk_Q", "Fulla Storytelling Ep03"),
                yt("RvCADv5165Q", "Fulla Storytelling Ep05"),
                yt("4zFf32zSYOc", "Fulla Storytelling Ep06")
            )
        ),
        ContentChannel(
            id = "adam_mishmish",
            title = "Adam & Mishmish",
            iconRes = R.drawable.tile_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 18,
            videos = listOf(
                yt("FurzMF0L6QI", "Animal Sounds Songs (68 min) — Adam & Mishmish"),
                yt("docDippkI-Q", "Farm Animal Songs — Adam & Mishmish"),
                yt("etAPDF2i9s0", "Arabic Letters with Animals — Adam & Mishmish")
            )
        ),
        ContentChannel(
            id = "zakaria",
            title = "Zakaria",
            iconRes = R.drawable.tile_zakaria,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 19,
            videos = listOf(
                yt("LocumA_zI0c", "Learn Colors with Cars — Zakaria"),
                yt("sGw7Fs7oRvw", "Vehicle Names in Arabic — Zakaria"),
                yt("XCp_1eTPnrM", "Arabic Numbers 1–10 — Zakaria"),
                yt("0MGqhiLQbxI", "Write Arabic Alphabet أ–ص — Zakaria"),
                yt("5v7A2AXzCY0", "Write Arabic Alphabet ض–ي — Zakaria")
            )
        ),
        ContentChannel(
            id = "kiki_nadoush",
            title = "Kiki wa Nadoush",
            iconRes = R.drawable.tile_kiki,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 20,
            videos = listOf(
                yt("EI3yLs6A-Qk", "Learn Arabic Colors — Kiki wa Nadoush")
            )
        ),
        ContentChannel(
            id = "rayan",
            title = "Rayan",
            iconRes = R.drawable.tile_rayan,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 21,
            videos = listOf(
                yt("yPhFBBMWbPU", "Shapes & Directions in Arabic — Rayan")
            )
        ),
        ContentChannel(
            id = "sweet_kalima",
            title = "Sweet Kalima",
            iconRes = R.drawable.tile_sweet_kalima,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 22,
            videos = listOf(
                yt("En3OJwCqHx8", "Shapes, Colors & Numbers — Sweet Kalima")
            )
        ),
        ContentChannel(
            id = "abata",
            title = "Abata",
            iconRes = R.drawable.tile_abata,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 23,
            videos = listOf(
                yt("sVtaIloYxvw", "Arabic Alphabet with Chalk — Abata")
            )
        ),
        ContentChannel(
            id = "sara_duck",
            title = "Sarah & Duck",
            iconRes = R.drawable.tile_sara_duck,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC3OUMU3s7Oy6Ta0wnpZFBWw"),
            sortOrder = 24,
            videos = listOf(
                yt("EOj_7ZYmCOI", "Cheer Up Donkey — Sarah & Duck"),
                yt("e69BdjwjDxk", "Bouncy Ball — Sarah & Duck"),
                yt("zGn6PwRkD7c", "Sarah, Duck and the Penguins")
            )
        ),
        ContentChannel(
            id = "twirlywoos",
            title = "Twirlywoos",
            iconRes = R.drawable.tile_twirlywoos,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC6-m1hdh8xEu-XBJK3v1TPg"),
            sortOrder = 25,
            videos = listOf(
                yt("yS4vFgys9-U", "Soft — Twirlywoos"),
                yt("lRVTYTWPUhU", "This way, that way — Twirlywoos"),
                yt("phqqLsmOxic", "Joining Up! — Twirlywoos"),
                yt("Ya45-PIVjhA", "Sneaking in the Kitchen — Twirlywoos")
            )
        ),
        ContentChannel(
            id = "barney",
            title = "Barney & Friends",
            iconRes = R.drawable.tile_barney,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCelJG1JV-pKYGOG3AM17Wvg"),
            sortOrder = 26,
            videos = listOf(
                yt("HoS5Dv4kAx8", "I Love You — Barney Nursery Rhymes"),
                yt("eb7yLV9moeU", "Learning Colors with Barney!"),
                yt("iuxvKiCkVUo", "Barney's Best Animal Songs!"),
                yt("ecj5DwqT2xE", "Having a Healthy Snack! — Barney"),
                yt("Zi5CQbSajXE", "Learning Something New with Barney!"),
                yt("gzw6-AbAbK4", "Let's Play Together! — Barney"),
                yt("dIQCqktBrXc", "A Friend Like You! — Barney")
            )
        ),
        ContentChannel(
            id = "dora",
            title = "Dora the Explorer",
            iconRes = R.drawable.tile_dora,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCkvPyGW-gsYucCK37UR0q2g"),
            sortOrder = 27,
            videos = listOf(
                yt("7bqSFXuEUgo", "NEW Dora Theme Song! — Dora & Friends"),
                yt("gFTaVxUynsQ", "You Can Do It! — Dora & Friends"),
                yt("kKCLBnKT4dU", "Best Friends Forever Day — Dora & Friends"),
                yt("aIkGW0o5NeM", "Dora Plays with Giant Kitty Cats!"),
                yt("fAYtT9_iOfI", "Sunny Flower Scenes with Boots — Dora & Friends")
            )
        ),
        ContentChannel(
            id = "peppa",
            title = "Peppa Pig",
            iconRes = R.drawable.tile_peppa,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCAOtE1V7Ots4DjM8JLlrYgg"),
            sortOrder = 28,
            videos = listOf(
                yt("XAK5n8XUmfM", "What is Peppa's Favourite Sound? — Full Episodes"),
                yt("t7dTdE8Aqtw", "Jumping in Muddy Puddles — Peppa Pig My First Album"),
                yt("P5vlEeqdJN8", "Peppa and George Love Jumping in Muddy Puddles!"),
                yt("jbdck_y74ls", "Peppa Pig Rides the TRAIN! — LEGO DUPLO")
            )
        ),
        ContentChannel(
            id = "lego_duplo",
            title = "LEGO DUPLO",
            iconRes = R.drawable.tile_lego_duplo,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 29,
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
            iconRes = R.drawable.tile_play_doh,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 30,
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
            iconRes = R.drawable.tile_toy_kitchen,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 31,
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
            sortOrder = 32,
            videos = listOf(
                yt("7mR81x2Fk7g", "Dancing Fruit! — 1 Hour Mix — Hey Bear Sensory"),
                yt("ALaQvK7KZOY", "Dance, Colors and Counting — Dancing Fruit & Funky Veggies"),
                yt("kAxdvigZtw8", "Best of Dancing Fruit and Funky Veggies — Dance Party"),
                yt("b65MoVwANq4", "Disco Fruit Party — Dancing Fruit with Cumbia"),
                yt("KPP4Cfupzhs", "Smoothie Mix — Fun Dance Video"),
                yt("xOUdk2LdXrs", "Let's Dance! — Avocadosaurus and Party Strawberries")
            )
        ),
        // Seed v14 preschool batch — curated starters; Follow uploads stays off.
        ContentChannel(
            id = "toyor_baby",
            title = "طيور بيبي",
            iconRes = R.drawable.tile_toyor_baby,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 33,
            videos = listOf(
                yt("_tN--Xk4kaE", "دعاء النوم — سند مقداد | طيور بيبي"),
                yt("9hmZtWndznM", "دعاء قبل الطعام وبعده — سند مقداد | طيور بيبي"),
                yt("UA6sLNgWRtI", "شمّام (بدون ايقاع) — طيور بيبي"),
                yt("42oNUPf_SsM", "دعسوقة (بدون إيقاع) — طيور بيبي"),
                yt("OHM8yH2QRC8", "شاكر والببغاء الشاطر — العشرة المبشرون بالجنة"),
                yt("-l5_ao_oxmg", "شاكر والببغاء الشاطر — الصلوات"),
                yt("iSuhEcI1HOQ", "شاكر والببغاء الشاطر — المدينة المنورة"),
                yt("QhAc8NS8J_M", "شمّام — طيور بيبي")
            )
        ),
        ContentChannel(
            id = "pingu",
            title = "Pingu",
            iconRes = R.drawable.tile_pingu,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCM88mtSE0zRTn5ae4EbYcuw"),
            sortOrder = 34,
            videos = listOf(
                yt("fWb-pNyPzdo", "The Flying Pingu! — Official Channel"),
                yt("e3egZ7tLXV4", "A Helping Pingu! — Official Channel"),
                yt("67zm4V1F0Z0", "Painting Pingu! — Official Channel"),
                yt("cXmY4mlM6OI", "Like Father Like Pingu! — Official Channel"),
                yt("PpwYRAWTD8c", "Pingu the Doctor — Official Channel"),
                yt("m3KuDiBEtgU", "Pingu and the Broken Vase — Official Channel")
            )
        ),
        ContentChannel(
            id = "daniel_tiger",
            title = "Daniel Tiger",
            iconRes = R.drawable.tile_daniel_tiger,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCDqgSnRMGVx3dP4sn3ATZMA"),
            sortOrder = 35,
            videos = listOf(
                yt("OrNlkDVk_PA", "Daniel's Big Emotions — Daniel Tiger"),
                yt("N4cTNBbDTdw", "Daniel Learns Good Manners — Daniel Tiger"),
                yt("R6nF76uDWDA", "Daniel Eats Healthy — Daniel Tiger"),
                yt("9AfD-N9HK8s", "Bath Time with Daniel Tiger — Full Episodes"),
                yt("oloZANav_g8", "Potty Training! — Daniel Tiger"),
                yt("IGM-r8baTN4", "Daniel Learns to Swing — Daniel Tiger")
            )
        ),
        ContentChannel(
            id = "hey_duggee",
            title = "Hey Duggee",
            iconRes = R.drawable.tile_hey_duggee,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCj_mFUb-47d9QNiJ5556LjQ"),
            sortOrder = 36,
            videos = listOf(
                yt("W4oqUjPj-pI", "The Drawing Badge — Hey Duggee"),
                yt("_zJJVO4XXZs", "The Colour Badge — Hey Duggee"),
                yt("RhMecZiUEiY", "The Decorating Badge — Hey Duggee"),
                yt("VVMjTvc8qbQ", "The Key Badge — Hey Duggee"),
                yt("6bxOoxBheb0", "Feel-Good Happy Days With Duggee")
            )
        ),
        ContentChannel(
            id = "numberblocks",
            title = "Numberblocks",
            iconRes = R.drawable.tile_numberblocks,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCPlwvN0w4qFSP1FllALB92w"),
            sortOrder = 37,
            videos = listOf(
                yt("jVeYnCehEFE", "One — Numberblocks S1 E1"),
                yt("bz2oWyDjgbc", "Another One — Numberblocks S1 E2"),
                yt("aJzaNIpbUZo", "Two — Numberblocks S1 E3"),
                yt("6-duQqX5ECs", "Three — Numberblocks S1 E4"),
                yt("IqkSbJqplpg", "One, Two, Three — Numberblocks S1 E5"),
                yt("yKAttOvgWJc", "Three Little Pigs — Numberblocks S1 E8")
            )
        ),
        ContentChannel(
            id = "pocoyo",
            title = "Pocoyo",
            iconRes = R.drawable.tile_pocoyo,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UChT6ex4rsEDXjJKW7wJAb8w"),
            sortOrder = 38,
            videos = listOf(
                yt("CwL_mEsASGY", "Pato's Bedtime — Pocoyo"),
                yt("_-UEJip10hE", "Elly's Market — Pocoyo"),
                yt("_g_QHiaKuEs", "Cooking with Elly — Pocoyo"),
                yt("eDu9RdFhcg4", "Magician Pocoyo — Pocoyo"),
                yt("_b2U6PLIc_E", "Giving Loula a Bath — Pocoyo"),
                yt("jO-AiyofVEI", "Pocoyo's New Toys — Pocoyo")
            )
        ),
        // Later ajza — default off for preschool installs; parent can enable.
        playlistChannel(
            id = "dawood_tabarak",
            title = "داوود — جزء تبارك",
            icon = R.drawable.tile_dawood,
            order = 39,
            playlistId = "PLKhm8Z5pXdOXqBC9Gmh2MVTEVQj6x_4or",
            enabled = false
        ),
        playlistChannel(
            id = "dawood_tabarak_plain",
            title = "داوود — جزء تبارك بدون تكرار",
            icon = R.drawable.tile_dawood,
            order = 40,
            playlistId = "PLKhm8Z5pXdOWcPJqYwIEy3cySbyATyyLE",
            enabled = false
        ),
        playlistChannel(
            id = "dawood_tabarak_memorize",
            title = "داوود — حفظ جزء تبارك",
            icon = R.drawable.tile_dawood,
            order = 41,
            playlistId = "PLKhm8Z5pXdOXR75WBeBFDve5gSR_wfA1o",
            enabled = false
        ),
        playlistChannel(
            id = "dawood_juz_28",
            title = "داوود — جزء ٢٨",
            icon = R.drawable.tile_dawood,
            order = 42,
            playlistId = "PLKhm8Z5pXdOWx9JleIpX8EakeXcwLFTvm",
            enabled = false
        ),
        playlistChannel(
            id = "dawood_juz_27",
            title = "داوود — جزء ٢٧",
            icon = R.drawable.tile_dawood,
            order = 43,
            playlistId = "PLKhm8Z5pXdOUiE1L6BBQAYIn-phTTHNpT",
            enabled = false
        ),
        playlistChannel(
            id = "dawood_juz_26",
            title = "داوود — جزء ٢٦",
            icon = R.drawable.tile_dawood,
            order = 44,
            playlistId = "PLJBjyx9DErqk", // verified short YouTube playlist id for Juz 26
            enabled = false
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
            // Seed marks later ajza disabled for preschool; apply on upgrade only when seed says off.
            val disableFromSeed = !seed.enabled && current.enabled

            if (clearSpacetoonUploads || needsPlaylist || missingVideos.isNotEmpty() || titleStale ||
                disableFromSeed
            ) {
                fun withSeekPolicy(items: List<VideoItem>): List<VideoItem> =
                    items.map { it.copy(allowSeek = current.defaultAllowSeek) }
                val videos = when {
                    clearSpacetoonUploads -> withSeekPolicy(seed.videos)
                    current.videos.isEmpty() && seed.videos.isNotEmpty() ->
                        withSeekPolicy(seed.videos)
                    missingVideos.isNotEmpty() ->
                        current.videos + withSeekPolicy(missingVideos)
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
                    iconRes = seed.iconRes,
                    enabled = if (!seed.enabled) false else current.enabled
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
        playlistId: String,
        enabled: Boolean = true,
        videos: List<VideoItem> = emptyList()
    ) = ContentChannel(
        id = id,
        title = title,
        iconRes = icon,
        sourceType = SourceType.YOUTUBE_PLAYLIST,
        enabled = enabled,
        youtubePlaylistId = playlistId,
        sortOrder = order,
        followUploads = false,
        videos = videos
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
