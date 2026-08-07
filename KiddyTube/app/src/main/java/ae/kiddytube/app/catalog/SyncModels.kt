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

/** Playlist import is opt-in via followUploads, or one-shot when the library is still empty. */
object SyncPolicy {
    fun shouldImportPlaylist(followUploads: Boolean, videoCount: Int): Boolean =
        followUploads || videoCount == 0
}
