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
    /** Bump when seed playlist IDs change so existing installs merge updates once. */
    const val SEED_VERSION = 2

    fun seed(): List<ContentChannel> = listOf(
        playlistChannel(
            id = "barney",
            title = "Barney & Friends",
            icon = R.drawable.tile_barney,
            order = 0,
            // Barney Nursery Rhymes & Kids Songs (Scholastic)
            playlistId = uploadsOf("UCelJG1JV-pKYGOG3AM17Wvg")
        ),
        playlistChannel(
            id = "spacetoon",
            title = "Spacetoon",
            icon = R.drawable.tile_spacetoon,
            order = 1,
            // Official Spacetoon Arabic channel uploads
            playlistId = uploadsOf("UCuQKih3Ac3NABADQKQdeV6A")
        ),
        ContentChannel(
            id = "sara_duck",
            title = "Sara & Duck",
            iconRes = R.drawable.tile_sara_duck,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 2,
            // Starter episodes from official CBeebies (replace/extend in parent UI)
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
            order = 3,
            // Peppa Pig - Official Channel uploads
            playlistId = uploadsOf("UCAOtE1V7Ots4DjM8JLlrYgg")
        ),
        playlistChannel(
            id = "arabic_cartoons",
            title = "Arabic Cartoons",
            icon = R.drawable.tile_arabic,
            order = 4,
            // Mansour's Adventures curated playlist
            playlistId = "PLrEO7bVLqAMv5bDvRaHYxXZyLatDuFRKF"
        ),
        ContentChannel(
            id = "learn_arabic",
            title = "Learn Arabic",
            iconRes = R.drawable.tile_learn_arabic,
            sourceType = SourceType.YOUTUBE_VIDEO_LIST,
            sortOrder = 5,
            videos = listOf(
                yt("6e145BWP7ng", "Arabic Alphabet Song with Zaky"),
                yt("idTmXdvByF8", "Arabic Alphabet with Zaky (slower)"),
                yt("ufIppXESntI", "Learn the Arabic Alphabet — Kalam Kids")
            )
        ),
        ContentChannel(
            id = "mini_muslim",
            title = "Mini Muslim",
            iconRes = R.drawable.tile_mini_muslim,
            sourceType = SourceType.YOUTUBE_PLAYLIST,
            youtubePlaylistId = uploadsOf("UCIDYe6rgdROl77DDevNIcPA"),
            sortOrder = 6,
            // Instant starters until playlist sync (official MiniMuslims)
            videos = listOf(
                yt("4VpiuY_C5Ok", "Ramadan Around The World — MiniMuslims"),
                yt("vB3ffnqdNVs", "Islamic Songs for Kids (45 min) — MiniMuslims"),
                yt("WyxekrpqcEQ", "Islamic Songs for Kids (30 min) — MiniMuslims")
            )
        ),
        playlistChannel(
            id = "islamic_kids",
            title = "Islamic Kids",
            icon = R.drawable.tile_islamic,
            order = 7,
            // Omar & Hana - Islamic Cartoons for Kids uploads
            playlistId = uploadsOf("UC178EmfQAV3OT-UpuO6WUMg")
        )
    )

    /**
     * Apply newer seed playlist/video defaults onto an existing catalog without
     * wiping parent overrides that already set a playlist or videos.
     */
    fun mergeSeedUpdates(existing: List<ContentChannel>): List<ContentChannel> {
        val byId = existing.associateBy { it.id }.toMutableMap()
        for (seed in seed()) {
            val current = byId[seed.id]
            if (current == null) {
                byId[seed.id] = seed
                continue
            }
            val needsPlaylist = current.youtubePlaylistId.isNullOrBlank() &&
                !seed.youtubePlaylistId.isNullOrBlank()
            val needsVideos = current.videos.isEmpty() && seed.videos.isNotEmpty()
            if (needsPlaylist || needsVideos) {
                byId[seed.id] = current.copy(
                    youtubePlaylistId = if (needsPlaylist) seed.youtubePlaylistId else current.youtubePlaylistId,
                    videos = if (needsVideos) seed.videos else current.videos,
                    sourceType = when {
                        needsPlaylist -> SourceType.YOUTUBE_PLAYLIST
                        needsVideos -> seed.sourceType
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
