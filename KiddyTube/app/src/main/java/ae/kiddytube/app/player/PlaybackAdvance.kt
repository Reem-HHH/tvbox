package ae.kiddytube.app.player

import ae.kiddytube.app.catalog.ContentChannel
import ae.kiddytube.app.catalog.VideoItem

/** Resolves the next in-channel video after the current one ends (catalog list order). */
object PlaybackAdvance {
    /**
     * Returns the video after the current item in the same enabled channel, or null when
     * there is no next item (caller should finish playback).
     */
    fun nextInChannel(
        channels: List<ContentChannel>,
        channelId: String,
        currentVideoId: String? = null,
        currentYoutubeId: String? = null,
        currentDirectUrl: String? = null
    ): VideoItem? {
        if (channelId.isBlank()) return null
        val channel = channels.firstOrNull { it.id == channelId && it.enabled } ?: return null
        val videos = channel.videos
        if (videos.isEmpty()) return null
        val index = videos.indexOfFirst { matchesCurrent(it, currentVideoId, currentYoutubeId, currentDirectUrl) }
        if (index < 0) return null
        return videos.getOrNull(index + 1)
    }

    internal fun matchesCurrent(
        video: VideoItem,
        currentVideoId: String?,
        currentYoutubeId: String?,
        currentDirectUrl: String?
    ): Boolean {
        val videoId = currentVideoId?.trim().orEmpty()
        val youtubeId = currentYoutubeId?.trim().orEmpty()
        val directUrl = currentDirectUrl?.trim().orEmpty()
        if (videoId.isNotBlank() && video.id == videoId) return true
        if (youtubeId.isNotBlank() &&
            (video.youtubeVideoId == youtubeId || video.id == youtubeId)
        ) {
            return true
        }
        if (directUrl.isNotBlank() && video.directUrl?.trim() == directUrl) return true
        return false
    }
}
