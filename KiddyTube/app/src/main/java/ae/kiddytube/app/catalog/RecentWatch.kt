package ae.kiddytube.app.catalog

/**
 * Snapshot of a recently played catalog video for the home "Continue watching" row.
 * Playback still validates against the live catalog in [ae.kiddytube.app.player.PlayerActivity].
 */
data class RecentWatchItem(
    val videoId: String,
    val channelId: String,
    val title: String,
    val thumbnailUrl: String? = null,
    val youtubeVideoId: String? = null,
    val directUrl: String? = null,
    val watchedAtMs: Long
)

object RecentWatchLogic {
    const val MAX_ITEMS = 12

    fun prepend(existing: List<RecentWatchItem>, item: RecentWatchItem): List<RecentWatchItem> {
        if (item.videoId.isBlank()) return existing
        val without = existing.filterNot { sameVideo(it, item) }
        return (listOf(item) + without).take(MAX_ITEMS)
    }

    fun sameVideo(a: RecentWatchItem, b: RecentWatchItem): Boolean {
        if (a.videoId == b.videoId) return true
        val aYt = a.youtubeVideoId?.trim().orEmpty()
        val bYt = b.youtubeVideoId?.trim().orEmpty()
        if (aYt.isNotEmpty() && aYt == bYt) return true
        val aUrl = a.directUrl?.trim().orEmpty()
        val bUrl = b.directUrl?.trim().orEmpty()
        return aUrl.isNotEmpty() && aUrl == bUrl
    }

    /**
     * Keep only items still present in an enabled channel, newest first.
     * Prefers the original channel when that video is still there.
     */
    fun resolvePlayable(
        recent: List<RecentWatchItem>,
        settings: CatalogSettings
    ): List<Pair<RecentWatchItem, VideoItem>> {
        val enabled = settings.channels.filter { it.enabled }
        return recent.mapNotNull { entry ->
            val preferred = enabled.firstOrNull { it.id == entry.channelId }
            val video = preferred?.videos?.firstOrNull { matchesCatalogVideo(entry, it) }
                ?: enabled.asSequence()
                    .flatMap { ch -> ch.videos.asSequence().map { ch to it } }
                    .firstOrNull { matchesCatalogVideo(entry, it.second) }
                    ?.second
                ?: return@mapNotNull null
            val channelId = preferred?.takeIf {
                it.videos.any { v -> matchesCatalogVideo(entry, v) }
            }?.id ?: enabled.firstOrNull { ch ->
                ch.videos.any { v -> matchesCatalogVideo(entry, v) }
            }?.id ?: entry.channelId
            entry.copy(
                channelId = channelId,
                title = video.title,
                thumbnailUrl = video.youtubeThumbnail() ?: video.thumbnailUrl,
                youtubeVideoId = video.youtubeVideoId,
                directUrl = video.directUrl
            ) to video
        }
    }

    private fun matchesCatalogVideo(entry: RecentWatchItem, video: VideoItem): Boolean {
        if (entry.videoId == video.id) return true
        val yt = entry.youtubeVideoId?.trim().orEmpty()
        if (yt.isNotEmpty() && (video.youtubeVideoId == yt || video.id == yt)) return true
        val url = entry.directUrl?.trim().orEmpty()
        return url.isNotEmpty() && video.directUrl?.trim() == url
    }
}
