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
 * Parent-curated starter catalog. Playlist IDs point at official channel upload feeds
 * or curated playlists; parents should review/replace in the parent dashboard.
 *
 * Uploads playlist id = replace leading "UC" with "UU" on a channel id.
 */
object DefaultChannels {
    /** Bump when seed playlist/video IDs change so existing installs merge updates once. */
    const val SEED_VERSION = 5

    /** Former Spacetoon Arabic uploads feed — too broad for toddlers; cleared on upgrade. */
    private const val SPACETOON_UPLOADS_PLAYLIST = "UUuQKih3Ac3NABADQKQdeV6A"

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
            title = "Spacetoon Songs",
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
        ContentChannel(
            id = "sara_duck",
            title = "Sara & Duck",
            iconRes = R.drawable.tile_sara_duck,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC3OUMU3s7Oy6Ta0wnpZFBWw"),
            sortOrder = 3,
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
            order = 4,
            playlistId = uploadsOf("UCAOtE1V7Ots4DjM8JLlrYgg")
        ),
        ContentChannel(
            id = "arabic_cartoons",
            title = "Arabic Cartoons",
            iconRes = R.drawable.tile_arabic,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = "PLrEO7bVLqAMv5bDvRaHYxXZyLatDuFRKF",
            sortOrder = 5,
            videos = listOf(
                yt("FurzMF0L6QI", "Animal Sounds Songs (68 min) — Adam & Mishmish"),
                yt("docDippkI-Q", "Farm Animal Songs — Adam & Mishmish"),
                yt("etAPDF2i9s0", "Arabic Letters with Animals — Adam & Mishmish")
            )
        ),
        ContentChannel(
            id = "learn_arabic",
            title = "Learn Arabic",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC5vfWTTPnKdFp-8s0KbqJhw"),
            sortOrder = 6,
            videos = listOf(
                yt("EI3yLs6A-Qk", "Learn Arabic Colors — Kiki wa Nadoush"),
                yt("LocumA_zI0c", "Learn Colors with Cars — Zakaria"),
                yt("yPhFBBMWbPU", "Shapes & Directions in Arabic — Rayan"),
                yt("En3OJwCqHx8", "Shapes, Colors & Numbers — Sweet Kalima"),
                yt("sVtaIloYxvw", "Arabic Alphabet with Chalk — Abata"),
                yt("sGw7Fs7oRvw", "Vehicle Names in Arabic — Zakaria"),
                yt("XCp_1eTPnrM", "Arabic Numbers 1–10 — Zakaria"),
                yt("0MGqhiLQbxI", "Write Arabic Alphabet أ–ص — Zakaria"),
                yt("5v7A2AXzCY0", "Write Arabic Alphabet ض–ي — Zakaria"),
                yt("fwg0UIw0Efs", "LEGO DUPLO Numbers & Colors in Arabic")
            )
        ),
        ContentChannel(
            id = "mini_muslim",
            title = "Mini Muslim",
            iconRes = R.drawable.tile_mini_muslim,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCIDYe6rgdROl77DDevNIcPA"),
            sortOrder = 7,
            videos = listOf(
                yt("4VpiuY_C5Ok", "Ramadan Around The World — MiniMuslims"),
                yt("vB3ffnqdNVs", "Islamic Songs for Kids (45 min) — MiniMuslims"),
                yt("WyxekrpqcEQ", "Islamic Songs for Kids (30 min) — MiniMuslims")
            )
        ),
        ContentChannel(
            id = "islamic_kids",
            title = "Islamic Kids",
            iconRes = R.drawable.tile_islamic,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UC178EmfQAV3OT-UpuO6WUMg"),
            sortOrder = 8,
            videos = listOf(
                yt("T6ggVnk1JZg", "Omar & Hana 15 Minutes Song"),
                yt("iJtM9bzScJY", "Omar & Hana — Dua & Salah (Acapella)"),
                yt("HvzYeFB0lB4", "Breakfasting — Omar & Hana"),
                yt("AkSrzSwK2wE", "Omar & Hana Arabic — Please Come Home Dad")
            )
        ),
        ContentChannel(
            id = "playtime",
            title = "Playtime",
            iconRes = R.drawable.tile_playtime,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 9,
            videos = listOf(
                yt("w7aZLVaLTlM", "LEGO DUPLO Vehicles & Colors"),
                yt("01JxHFDBdzE", "LEGO DUPLO Creative Animals Unbox"),
                yt("a0uPqr_iASU", "LEGO DUPLO Animal Build"),
                yt("jvCdmPsAn40", "LEGO DUPLO Balancing Tree"),
                yt("xvxQeQfdifk", "LEGO DUPLO Marble Run"),
                yt("mSUJM2naI7I", "Travel Kitchen Playset Unboxing"),
                yt("TL3e2UZQxPE", "Kitchen Set & Toy Fruits"),
                yt("2FyKZKNls4c", "Play-Doh Cookie Man & Shapes"),
                yt("8581xy-tGqw", "Play-Doh Rainbow Ice Cream"),
                yt("kS9fxiOdiGs", "Marble Run Plasticine Race"),
                yt("F4ICHmkVGtQ", "Magic Marble Run Compilation")
            )
        )
    )

    /**
     * Apply newer seed playlist/video defaults onto an existing catalog without
     * wiping parent overrides. Appends missing seed videos; adds new seed channels.
     */
    fun mergeSeedUpdates(existing: List<ContentChannel>): List<ContentChannel> {
        val byId = existing.associateBy { it.id }.toMutableMap()
        for (seed in seed()) {
            val current = byId[seed.id]
            if (current == null) {
                byId[seed.id] = seed
                continue
            }

            // Drop the broad Spacetoon uploads feed when upgrading to curated songs.
            val clearSpacetoonUploads = seed.id == "spacetoon" &&
                seed.youtubePlaylistId.isNullOrBlank() &&
                current.youtubePlaylistId == SPACETOON_UPLOADS_PLAYLIST

            val needsPlaylist = current.youtubePlaylistId.isNullOrBlank() &&
                !seed.youtubePlaylistId.isNullOrBlank()
            val existingIds = current.videos.map { it.id }.toSet()
            val missingVideos = seed.videos.filter { it.id !in existingIds }

            if (clearSpacetoonUploads || needsPlaylist || missingVideos.isNotEmpty()) {
                val videos = when {
                    clearSpacetoonUploads -> seed.videos
                    current.videos.isEmpty() && seed.videos.isNotEmpty() -> seed.videos
                    missingVideos.isNotEmpty() -> current.videos + missingVideos
                    else -> current.videos
                }
                byId[seed.id] = current.copy(
                    title = if (clearSpacetoonUploads) seed.title else current.title,
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
                    iconRes = if (current.iconRes == 0) seed.iconRes else current.iconRes
                )
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
