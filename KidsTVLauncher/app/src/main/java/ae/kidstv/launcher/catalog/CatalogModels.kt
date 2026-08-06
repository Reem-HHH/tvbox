package ae.kidstv.launcher.catalog

import ae.kidstv.launcher.R

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

object DefaultChannels {
    fun seed(): List<ContentChannel> = listOf(
        channel("barney", "Barney & Friends", R.drawable.tile_barney, 0),
        channel("spacetoon", "Spacetoon", R.drawable.tile_spacetoon, 1),
        channel("sara_duck", "Sara & Duck", R.drawable.tile_sara_duck, 2),
        channel("peppa", "Peppa Pig", R.drawable.tile_peppa, 3),
        channel("arabic_cartoons", "Arabic Cartoons", R.drawable.tile_arabic, 4),
        channel("learn_arabic", "Learn Arabic", R.drawable.tile_learn_arabic, 5),
        channel("mini_muslim", "Mini Muslim", R.drawable.tile_mini_muslim, 6),
        channel("islamic_kids", "Islamic Kids", R.drawable.tile_islamic, 7)
    )

    private fun channel(id: String, title: String, icon: Int, order: Int) = ContentChannel(
        id = id,
        title = title,
        iconRes = icon,
        sourceType = SourceType.YOUTUBE_PLAYLIST,
        sortOrder = order
    )
}

fun VideoItem.youtubeThumbnail(): String? {
    val id = youtubeVideoId ?: return thumbnailUrl
    return "https://img.youtube.com/vi/$id/hqdefault.jpg"
}
