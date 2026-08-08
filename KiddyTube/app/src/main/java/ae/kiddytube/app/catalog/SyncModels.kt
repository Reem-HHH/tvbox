package ae.kiddytube.app.catalog

import ae.kiddytube.app.BuildConfig

/** Resolves YouTube Data API key: parent setting wins, then BuildConfig (local.properties). */
object ApiKeyResolver {
    fun effective(parentKey: String?, buildConfigKey: String = BuildConfig.YOUTUBE_API_KEY): String? {
        val fromParent = parentKey?.trim()?.takeIf { it.isNotEmpty() }
        if (fromParent != null) return fromParent
        return buildConfigKey.trim().takeIf { it.isNotEmpty() }
    }
}

enum class SyncStatus {
    UPDATED,
    SKIPPED_NO_KEY,
    SKIPPED_OFFLINE,
    SKIPPED_TTL,
    FAILED
}

data class SyncResult(
    val status: SyncStatus,
    val updatedChannels: Int = 0,
    val videoCount: Int = 0,
    val message: String? = null
)

/**
 * Playlist import is opt-in via [followUploads] only.
 * Empty seed libraries keep hand-picked starters until a parent enables Follow uploads.
 * [suppressEmptyImport] / [videoCount] are retained for call-site compatibility.
 */
object SyncPolicy {
    @Suppress("UNUSED_PARAMETER")
    fun shouldImportPlaylist(
        followUploads: Boolean,
        videoCount: Int,
        suppressEmptyImport: Boolean = false
    ): Boolean = followUploads

    /** Force refresh or empty playlist libraries ignore the usual sync TTL. */
    fun shouldBypassTtl(force: Boolean, emptyPlaylistLibraries: Boolean): Boolean =
        force || emptyPlaylistLibraries

    /**
     * Whether [refreshAllPlaylists] should touch this channel.
     * Closed libraries (followUploads off, non-empty) skip auto sync; force still
     * metadata-enriches when YouTube video ids are already present.
     */
    fun shouldRefreshChannel(
        force: Boolean,
        hasPlaylist: Boolean,
        hasYoutubeVideos: Boolean,
        importPlaylist: Boolean
    ): Boolean {
        if (!hasPlaylist && !hasYoutubeVideos) return false
        if (hasPlaylist && !importPlaylist) {
            if (!force) return false
            if (!hasYoutubeVideos) return false
        }
        return true
    }
}
