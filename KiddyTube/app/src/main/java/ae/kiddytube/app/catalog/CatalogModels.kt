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
    val directUrl: String? = null
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
    val sortOrder: Int = 0
)

/**
 * Parent-curated starter catalog. Each channel is one named show (not a generic mix).
 * Playlist IDs point at official channel upload feeds where the whole channel is that show;
 * parents should review/replace in the parent dashboard.
 *
 * Uploads playlist id = replace leading "UC" with "UU" on a channel id.
 */
object DefaultChannels {
    /** Bump when seed playlist/video IDs change so existing installs merge updates once. */
    const val SEED_VERSION = 7

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
            id = "sara_duck",
            title = "Sarah & Duck",
            iconRes = R.drawable.tile_sara_duck,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC3OUMU3s7Oy6Ta0wnpZFBWw"),
            sortOrder = 5,
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
            order = 6,
            playlistId = uploadsOf("UCAOtE1V7Ots4DjM8JLlrYgg")
        ),
        ContentChannel(
            id = "adam_mishmish",
            title = "Adam & Mishmish",
            iconRes = R.drawable.tile_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 7,
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
            sortOrder = 8,
            videos = listOf(
                yt("EI3yLs6A-Qk", "Learn Arabic Colors — Kiki wa Nadoush")
            )
        ),
        ContentChannel(
            id = "zakaria",
            title = "Zakaria",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 9,
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
            sortOrder = 10,
            videos = listOf(
                yt("yPhFBBMWbPU", "Shapes & Directions in Arabic — Rayan")
            )
        ),
        ContentChannel(
            id = "sweet_kalima",
            title = "Sweet Kalima",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 11,
            videos = listOf(
                yt("En3OJwCqHx8", "Shapes, Colors & Numbers — Sweet Kalima")
            )
        ),
        ContentChannel(
            id = "abata",
            title = "Abata",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 12,
            videos = listOf(
                yt("sVtaIloYxvw", "Arabic Alphabet with Chalk — Abata")
            )
        ),
        ContentChannel(
            id = "lego_duplo",
            title = "LEGO DUPLO",
            iconRes = R.drawable.tile_playtime,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 13,
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
            sortOrder = 14,
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
            sortOrder = 15,
            videos = listOf(
                yt("mSUJM2naI7I", "Travel Kitchen Playset Unboxing"),
                yt("TL3e2UZQxPE", "Kitchen Set & Toy Fruits")
            )
        ),
        ContentChannel(
            id = "mini_muslim",
            title = "Mini Muslim",
            iconRes = R.drawable.tile_mini_muslim,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCIDYe6rgdROl77DDevNIcPA"),
            sortOrder = 16,
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
            sortOrder = 17,
            videos = listOf(
                yt("T6ggVnk1JZg", "Omar & Hana 15 Minutes Song"),
                yt("iJtM9bzScJY", "Omar & Hana — Dua & Salah (Acapella)"),
                yt("HvzYeFB0lB4", "Breakfasting — Omar & Hana"),
                yt("AkSrzSwK2wE", "Omar & Hana Arabic — Please Come Home Dad")
            )
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

            val needsPlaylist = current.youtubePlaylistId.isNullOrBlank() &&
                !seed.youtubePlaylistId.isNullOrBlank()
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
                    videos = videos,
                    sourceType = when {
                        clearSpacetoonUploads -> seed.sourceType
                        needsPlaylist -> SourceType.YOUTUBE_PLAYLIST
                        else -> current.sourceType
                    },
                    sortOrder = seed.sortOrder,
                    iconRes = if (current.iconRes == 0) seed.iconRes else current.iconRes
                )
            } else if (current.sortOrder != seed.sortOrder) {
                byId[seed.id] = current.copy(sortOrder = seed.sortOrder)
            }
        }
        return byId.values.sortedBy { it.sortOrder }
    }

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
        sortOrder = order
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
