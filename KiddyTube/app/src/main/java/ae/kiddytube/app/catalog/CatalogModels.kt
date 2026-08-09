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
    const val SEED_VERSION = 22

    /** Wrong upload formerly labeled مابي أنام; replaced by بنيتي الحبوبة. */
    private const val RETIRED_KIDS_MUSIC_VIDEO_ID = "ISSlEZyIRFw"

    /** Former Spacetoon Arabic uploads feed — too broad for toddlers; cleared on upgrade. */
    private const val SPACETOON_UPLOADS_PLAYLIST = "UUuQKih3Ac3NABADQKQdeV6A"

    /** Primary Dawood TV hub playlist (Juz Amma) — deeper playlists documented for parents. */
    private const val DAWOOD_HUB_PLAYLIST = "PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR"

    /** Official Numberblocks Season 1 full episodes (preferred over channel uploads). */
    private const val NUMBERBLOCKS_SEASON_1_PLAYLIST = "PL9swKX1PviEr9UfByZqJYiN8KX3AXqyXm"

    /** Pre–v6 generics, retired shows, and pre–v16 multi-tile Dawood channels. */
    private val RETIRED_CHANNEL_IDS = setOf(
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

    fun seed(): List<ContentChannel> = withDailyFollow(
        listOf(
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
        // Single home tile for all Dawood TV content (deeper playlists: docs/channels/dawood.md).
        playlistChannel(
            id = "dawood",
            title = "داوود",
            icon = R.drawable.tile_dawood,
            order = 2,
            playlistId = DAWOOD_HUB_PLAYLIST
        ),
        ContentChannel(
            id = "kids_music",
            title = "Kids Music",
            iconRes = R.drawable.tile_kids_music,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 3,
            videos = listOf(
                yt("wyOJfLSeZIE", "بابا فين — Free Baby (Music Video)"),
                yt("5wnNBQAkc-A", "ماما جابت بيبي — جنى مقداد | طيور الجنة"),
                yt("qn3ITODjLiw", "بنيتي الحبوبة — حلا الترك و مشاعل"),
                yt("03X3iys-Rcs", "أغنية آيس كريم — ثعلوب والفواكه | أسرتنا"),
                yt("Gmhk7mWG050", "في منزل أنثى السنجاب — أسرتنا"),
                yt("Pf1Y0JtfMPU", "أنشودة الخضروات — أسرتنا"),
                yt("WqzwrbzSqyY", "أغنية الكواكب — أسرتنا"),
                yt("wK-YBukZUuU", "كوكسينو والعنكبوت — أسرتنا"),
                yt("NWcs3bZ0fSM", "رمضان جانا — أسرتنا"),
                yt("XE4qklLOokQ", "أنا البندورة الحمراء — طيور الجنة")
            )
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
                yt("s7FQXvhwm40", "كتابُ الله"),
                yt("mJMigyCh-I8", "أغنية الكتاب"),
                yt("YoAU-tciuVs", "يا طيبة — المدينة المنورة"),
                yt("2h6Y8k8fNS4", "هيا للمسجد لنصلي"),
                yt("g7LjhyO7CEw", "رمضان أقبل طيباً"),
                yt("INZMVhnVlRM", "أهلاً رمضان يا شهر الإحسان"),
                yt("BojfVe5G6GM", "هلال رمضان — يوسف إسلام"),
                yt("Jh4gl0obMK0", "رمضان 2020 — أطل الفجر بالبشر"),
                yt("dB95J8Pa49c", "أغنية بداية أنا وأختي"),
                yt("o9xR7JcU2iw", "فلفول — أغنية السلطة"),
                yt("krYQGcQ3o0U", "جميع أغاني الأشكال الهندسية"),
                yt("fxZE5hOMyi4", "أكثر من 30 دقيقة — أروع أغاني سبيستون")
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
            id = "toyor_jana",
            title = "طيور الجنة",
            iconRes = R.drawable.tile_toyor_jana,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 17,
            videos = listOf(
                yt("7GgZjoF0D2I", "قلبي ينادي | طيور الجنة"),
                yt("jlJaCmIOu8k", "الصدقة — ديمة بشار | طيور الجنة"),
                yt("So6XIOgO4TM", "بيجاما — سند مقداد | طيور الجنة"),
                yt("B5kD9sxd5Jg", "شاكر والببغاء الشاطر — الخلفاء الراشدون"),
                yt("1zt6iH8R2uA", "شاكر والببغاء الشاطر — الفصول الأربعة"),
                yt("02OKtnWyjNo", "دادا حبة حبة (بدون إيقاع) — راية مقداد")
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
                yt("Ya45-PIVjhA", "Sneaking in the Kitchen — Twirlywoos"),
                yt("wAFiVXz1NNw", "Full — Twirlywoos"),
                yt("Wg0JkKmQY6A", "Connecting — Twirlywoos"),
                yt("8MUQW96Nsks", "Turning — Twirlywoos"),
                yt("iagHmqt-Hio", "Going Over — Twirlywoos"),
                yt("7JXSOIOebW4", "Full (Kid Movies) — Twirlywoos")
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
            youtubePlaylistId = NUMBERBLOCKS_SEASON_1_PLAYLIST,
            sortOrder = 37,
            videos = listOf(
                yt("jVeYnCehEFE", "One — Numberblocks S1 E1"),
                yt("bz2oWyDjgbc", "Another One — Numberblocks S1 E2"),
                yt("aJzaNIpbUZo", "Two — Numberblocks S1 E3"),
                yt("6-duQqX5ECs", "Three — Numberblocks S1 E4"),
                yt("IqkSbJqplpg", "One, Two, Three — Numberblocks S1 E5"),
                yt("yKAttOvgWJc", "Three Little Pigs — Numberblocks S1 E8"),
                yt("Ap5kgJ-bpEQ", "How to Count — Numberblocks S1 E10")
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
        // Seed v15 — classic preschool / Arabic family cartoons (Follow uploads stays off).
        ContentChannel(
            id = "cocomelon",
            title = "CoComelon",
            iconRes = R.drawable.tile_cocomelon,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCbCmjCuTUZos6Inko4u57UQ"),
            sortOrder = 39,
            videos = listOf(
                yt("e_04ZrNroTo", "Wheels on the Bus — CoComelon"),
                yt("WRVsOCh907o", "Bath Song — CoComelon"),
                yt("ZzAm13KsBCc", "Bath Song + More — CoComelon"),
                yt("tgFynI0l06U", "Old MacDonald Had A Farm + More — CoComelon"),
                yt("hqehvbhky5k", "On My Way To School — CoComelon"),
                yt("wfwvrawZDs8", "Happy Birthday Song — CoComelon")
            )
        ),
        ContentChannel(
            id = "masha",
            title = "Masha and the Bear",
            iconRes = R.drawable.tile_masha,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCu59yAFE8fM0sVNTipR4edw"),
            sortOrder = 40,
            videos = listOf(
                yt("qBp1rCz_yQU", "Recipe For Disaster — Masha and the Bear"),
                yt("1Kt9RhxJdzk", "Recipe For Disaster (4K) — Masha and the Bear"),
                yt("g9CMF85dAt4", "Laundry Day — Best Episodes Collection"),
                yt("AV-UBYOGB_o", "Why Should We Play Games? — Best Episodes"),
                yt("R6Oh1xUmB3E", "Honey Day — Cartoon Collection")
            )
        ),
        ContentChannel(
            id = "mansour",
            title = "منصور",
            iconRes = R.drawable.tile_mansour,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCqiIbqnJB0AVTg6Z6QnZNdw"),
            sortOrder = 41,
            videos = listOf(
                yt("TohnJvGq-cU", "مغامرات منصور — مغامرات مشوقة الجزء 7"),
                yt("A1edNxaVICE", "مغامرات منصور — مغامرات مشوقة الجزء 6"),
                yt("T1AlwoEdxGo", "مغامرات منصور — مغامرات مشوقة الجزء 5"),
                yt("l5LwMtanIg8", "مغامرات منصور — مغامرات مشوقة الجزء 4"),
                yt("qbrHu-vkXiI", "مغامرات منصور — الحلقات المميزة ج7")
            )
        ),
        ContentChannel(
            id = "maruko",
            title = "ماروكو الصغيرة",
            iconRes = R.drawable.tile_maruko,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 42,
            videos = listOf(
                yt("7Xf9nKYyAM4", "شارة العمل — ماروكو الصغيرة | سبيستون"),
                yt("OMbPlfL2VMY", "الحلقات الثلاث الأولى — ماروكو الصغيرة | سبيستون"),
                yt("vnwWjLlbYUQ", "المقدمة الرسمية — ماروكو الصغيرة"),
                yt("_WgvHPmMYXo", "مشاجرة الأختين — ماروكو الصغيرة"),
                yt("zZAQztwJGxg", "بيع الساعة — ماروكو الصغيرة"),
                yt("3iKlvWdgQ2M", "ماروكو الصغيرة تستغل الفرصة"),
                yt("KQidxkPZrOI", "عالية مكانتي — ماروكو الصغيرة"),
                yt("OBPi512Q-0c", "ماروكو الصغيرة واكتشافها")
            )
        ),
        ContentChannel(
            id = "live_makkah",
            title = "مكة مباشر",
            iconRes = R.drawable.tile_live_makkah,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 43,
            videos = listOf(
                yt("wawzF8i5yAo", "بث مباشر — قناة القرآن الكريم | مكة")
            )
        ),
        ContentChannel(
            id = "live_quran",
            title = "القرآن مباشر",
            iconRes = R.drawable.tile_live_quran,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 44,
            videos = listOf(
                yt("wawzF8i5yAo", "بث مباشر — قناة القرآن الكريم")
            )
        ),
        ContentChannel(
            id = "masha_ar",
            title = "ماشا والدب",
            iconRes = R.drawable.tile_masha_ar,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 45,
            videos = listOf(
                yt("N9HG6_hdotI", "ساعة من المرح — ماشا والدب"),
                yt("b_o6JWdrMB8", "بيت بالمقلوب — ماشا والدب"),
                yt("KedRL7GrXo8", "الحَمَل الجديدة — ماشا والدب"),
                yt("MZ_nL7BW4Wg", "الطلاب المثاليون — ماشا والدب"),
                yt("BmtZ9zo8XYs", "سباحة أنيقة — ماشا والدب"),
                yt("FFe8tPNw1AU", "أكثر 10 حلقات مشاهدة — ماشا والدب")
            )
        ),
        ContentChannel(
            id = "blippi_ar",
            title = "بليبي بالعربي",
            iconRes = R.drawable.tile_blippi_ar,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 46,
            videos = listOf(
                yt("ZooIBL5z-s8", "بليبي يزور ملعب داخلي"),
                yt("fKBp_i03wSE", "بليبي يزور مصنع للشوكولاتة"),
                yt("XXyqtYoBXLg", "بليبي يستكشف حيوانات الغابة"),
                yt("si138Y1-xs0", "بلبي يتعلم مهارات السيرك"),
                yt("JE0MivjUzOc", "قفزات بلبي على الترامبولين"),
                yt("uwLH7U-AJ5M", "سيارات بليبي السريعة")
            )
        ),
        ContentChannel(
            id = "disney_songs",
            title = "Disney Songs",
            iconRes = R.drawable.tile_disney_songs,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 47,
            videos = listOf(
                yt("L0MK7qz13bU", "Let It Go — Sing-Along (Frozen)"),
                yt("kQDw88hEr2c", "Love Is an Open Door — Sing-Along (Frozen)"),
                yt("r4KTqce-9Z0", "You're Welcome — Sing-Along (Moana)"),
                yt("RTWhvp_OD6s", "Where You Are — Sing-Along (Moana)"),
                yt("ILRs2r6lcHY", "I See the Light — Sing-Along (Tangled)"),
                yt("0fVcwXbAWtA", "When Will My Life Begin? — Sing-Along (Tangled)"),
                yt("YRpvIiz9G8A", "We Don't Talk About Bruno — Sing-Along (Encanto)"),
                yt("uh4dTLJ9q9o", "Lava — Official Lyric Video")
            )
        ),
        ContentChannel(
            id = "disney_songs_ar",
            title = "أغاني ديزني",
            iconRes = R.drawable.tile_disney_songs_ar,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 48,
            videos = listOf(
                yt("pBTtPEVdf3k", "أطلقي سركِ — ملكة الثلج | Disney Junior MENA"),
                yt("r7YUuTvOq7w", "إظهري — ملكة الثلج ٢ | ديزني بالعربي"),
                yt("05NZT9vQfJE", "في طريق مجهول — ملكة الثلج ٢ | ديزني بالعربي"),
                yt("J_7OroO4z2U", "حاجات مش بتضيع — ملكة الثلج ٢ | ديزني بالعربي"),
                yt("eQVNPPRqe2Y", "لأول يوم بعمري — ملكة الثلج | ديزني بالعربي")
            )
        ),
        ContentChannel(
            id = "babar",
            title = "بابار",
            iconRes = R.drawable.tile_babar,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 49,
            videos = listOf(
                yt("CKG8KXSiehs", "Babar — The Elephant Express (Ep. 18)"),
                yt("7x1RmD8gnug", "Babar — Remember When… (Ep. 26)"),
                yt("OzjPwN0rDY0", "Babar — Monkey Business (Ep. 23)"),
                yt("8lXs1qmACnU", "Babar — A Tale of Two Siblings (Ep. 36)"),
                yt("8Z5jvr_JJUk", "Babar & Badou — Kite Fight / Zoomerblimps (Ep. 9)"),
                yt(
                    "uilO6OTjo-4",
                    "Babar & Badou — The Brave Guy / Starring Ms. Strich (Ep. 14)"
                ),
                yt(
                    "PlKszSbTh1E",
                    "Babar & Badou — The Unhidden Courtyard / The Rhino Rule (Ep. 36)"
                ),
                yt(
                    "hoT5HIAhTQ8",
                    "Babar & Badou — Fair is Fair / Savanna Surfing (Ep. 55)"
                )
            )
        ),
        ContentChannel(
            id = "hadikat_almarah",
            title = "حديقة المرح",
            iconRes = R.drawable.tile_hadikat_almarah,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 50,
            videos = listOf(
                yt("knTqvBZtgDc", "نظيف نظيف — حديقة المرح | 1"),
                yt("bGRQ9KBKpwA", "جوجو — حديقة المرح | 2"),
                yt("lZKz-xtGLiU", "الطائرة الظريفة — حديقة المرح | 3"),
                yt("talSXCgXMJk", "أواني الزهور — حديقة المرح | 4"),
                yt("EHCfylJXNto", "الدمى المضحكة عال — حديقة المرح | 5"),
                yt("rqmJ3-3kcEg", "استيقظ إيجل بيجل — حديقة المرح"),
                yt("DDhMUpA3CuA", "حجر هوبزا هوب الخاصة — حديقة المرح"),
                yt("fi1qBp_VNfY", "1 + 2 — حديقة المرح")
            )
        )
        )
    )

    /**
     * Playlist-backed channels follow uploads daily by default; manual libraries stay off.
     */
    private fun withDailyFollow(channels: List<ContentChannel>): List<ContentChannel> =
        channels.map { ch ->
            if (ch.youtubePlaylistId.isNullOrBlank()) ch
            else ch.copy(followUploads = true)
        }

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
            val replaceNumberblocksPlaylist = seed.id == "numberblocks" &&
                !current.playlistManagedByParent &&
                !seed.youtubePlaylistId.isNullOrBlank() &&
                current.youtubePlaylistId != seed.youtubePlaylistId
            val enableFollowFromSeed = seed.followUploads &&
                !current.followUploads &&
                !current.playlistManagedByParent
            val dropWrongKidsMusic = seed.id == "kids_music" &&
                current.videos.any { it.id == RETIRED_KIDS_MUSIC_VIDEO_ID }
            val baseVideos = if (dropWrongKidsMusic) {
                current.videos.filter { it.id != RETIRED_KIDS_MUSIC_VIDEO_ID }
            } else {
                current.videos
            }
            val existingIds = baseVideos.map { it.id }.toSet()
            val missingVideos = seed.videos.filter { it.id !in existingIds }
            val titleStale = current.title != seed.title &&
                (seed.id == "spacetoon" || clearSpacetoonUploads)
            // Seed marks later ajza disabled for preschool; apply on upgrade only when seed says off.
            val disableFromSeed = !seed.enabled && current.enabled

            if (clearSpacetoonUploads || needsPlaylist || replaceNumberblocksPlaylist ||
                enableFollowFromSeed || missingVideos.isNotEmpty() || dropWrongKidsMusic ||
                titleStale || disableFromSeed
            ) {
                fun withSeekPolicy(items: List<VideoItem>): List<VideoItem> =
                    items.map { it.copy(allowSeek = current.defaultAllowSeek) }
                val videos = when {
                    clearSpacetoonUploads -> withSeekPolicy(seed.videos)
                    current.videos.isEmpty() && seed.videos.isNotEmpty() ->
                        withSeekPolicy(seed.videos)
                    missingVideos.isNotEmpty() || dropWrongKidsMusic ->
                        baseVideos + withSeekPolicy(missingVideos)
                    else -> current.videos
                }
                byId[seed.id] = current.copy(
                    title = if (titleStale || clearSpacetoonUploads) seed.title else current.title,
                    youtubePlaylistId = when {
                        clearSpacetoonUploads -> null
                        needsPlaylist || replaceNumberblocksPlaylist -> seed.youtubePlaylistId
                        else -> current.youtubePlaylistId
                    },
                    videos = videos.newestFirst(),
                    sourceType = when {
                        clearSpacetoonUploads -> seed.sourceType
                        needsPlaylist || replaceNumberblocksPlaylist -> SourceType.YOUTUBE_PLAYLIST
                        else -> current.sourceType
                    },
                    sortOrder = seed.sortOrder,
                    iconRes = seed.iconRes,
                    enabled = if (!seed.enabled) false else current.enabled,
                    followUploads = if (!current.playlistManagedByParent && seed.followUploads) {
                        true
                    } else {
                        current.followUploads
                    }
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
        followUploads = true,
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

/**
 * Single-pass pick of the newest video (same ordering as [newestFirst].firstOrNull).
 * Prefer this in RecyclerView binds to avoid sorting the full list.
 */
fun List<VideoItem>.newestOrNull(): VideoItem? =
    withIndex().maxWithOrNull(
        compareBy(
            { it.value.publishedAtMs ?: Long.MIN_VALUE },
            { -it.index }
        )
    )?.value
