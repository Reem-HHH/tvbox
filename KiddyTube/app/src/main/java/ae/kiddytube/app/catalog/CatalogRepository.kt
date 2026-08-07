package ae.kiddytube.app.catalog

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.MutablePreferences
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import ae.kiddytube.app.sources.NetworkStatus
import ae.kiddytube.app.sources.YoutubeCatalogSource
import ae.kiddytube.app.sources.YoutubeUrlParser
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

private val Context.catalogStore: DataStore<Preferences> by preferencesDataStore(name = "kids_catalog")

data class CatalogSettings(
    val channels: List<ContentChannel> = DefaultChannels.seed(),
    val youtubeApiKey: String? = null,
    val pinSalt: String? = null,
    val pinHash: String? = null,
    val pinChangedFromDefault: Boolean = false,
    val failCount: Int = 0,
    val lockedUntilMs: Long = 0L,
    val releaseReady: Boolean = false,
    val lastSyncMs: Long = 0L,
    val seedVersion: Int = 0
)

class CatalogRepository(private val context: Context) {
    private val store = context.catalogStore
    private val youtube = YoutubeCatalogSource()
    private val syncTtlMs = 24 * 60 * 60 * 1000L
    private val writeMutex = Mutex()

    val settingsFlow: Flow<CatalogSettings> = store.data.map { it.toSettings() }

    suspend fun current(): CatalogSettings = settingsFlow.first()

    fun enabledChannels(settings: CatalogSettings): List<ContentChannel> =
        settings.channels.filter { it.enabled }.sortedBy { it.sortOrder }

    fun effectiveApiKey(settings: CatalogSettings): String? =
        ApiKeyResolver.effective(settings.youtubeApiKey)

    suspend fun containsYoutubeVideoId(videoId: String): Boolean {
        val id = videoId.trim()
        return current().channels.any { ch ->
            ch.videos.any { it.youtubeVideoId == id || it.id == id }
        }
    }

    suspend fun containsDirectUrl(url: String): Boolean {
        val target = url.trim()
        if (target.isEmpty()) return false
        return current().channels.any { ch ->
            ch.videos.any { it.directUrl == target }
        }
    }

    suspend fun update(transform: (CatalogSettings) -> CatalogSettings) {
        writeMutex.withLock {
            store.edit { prefs ->
                val next = transform(prefs.toSettings())
                writeSettings(prefs, next)
            }
        }
    }

    /** One-time merge of newer hardcoded playlist seeds into existing catalogs. */
    suspend fun applySeedUpgradeIfNeeded() {
        update { current ->
            if (current.seedVersion >= DefaultChannels.SEED_VERSION) current
            else current.copy(
                channels = DefaultChannels.mergeSeedUpdates(current.channels),
                seedVersion = DefaultChannels.SEED_VERSION
            )
        }
    }

    suspend fun resetAll() {
        writeMutex.withLock {
            store.edit { it.clear() }
        }
    }

    suspend fun channelById(id: String): ContentChannel? =
        current().channels.firstOrNull { it.id == id }

    suspend fun updateChannel(channelId: String, transform: (ContentChannel) -> ContentChannel) {
        update { s ->
            s.copy(channels = s.channels.map { if (it.id == channelId) transform(it) else it })
        }
    }

    suspend fun refreshChannelFromYoutube(
        channelId: String,
        allowPlaylistImport: Boolean? = null
    ): Result<Int> {
        val settings = current()
        val channel = settings.channels.firstOrNull { it.id == channelId }
            ?: return Result.failure(IllegalArgumentException("Unknown channel"))
        val apiKey = ApiKeyResolver.effective(settings.youtubeApiKey)
        val playlistId = channel.youtubePlaylistId
        val importPlaylist = allowPlaylistImport
            ?: SyncPolicy.shouldImportPlaylist(channel.followUploads, channel.videos.size)

        if (apiKey.isNullOrBlank()) {
            return if (channel.videos.isNotEmpty()) {
                Result.success(channel.videos.size)
            } else {
                Result.failure(IllegalStateException("Missing API key or playlist"))
            }
        }

        if (!playlistId.isNullOrBlank() && importPlaylist) {
            val fetched = youtube.fetchPlaylistVideos(apiKey, playlistId, maxResults = 150)
            return fetched.fold(
                    onSuccess = { videos ->
                    updateChannel(channelId) { ch ->
                        val seedIds = DefaultChannels.seed()
                            .firstOrNull { it.id == channelId }
                            ?.videos
                            ?.map { it.id }
                            ?.toSet()
                            .orEmpty()
                        val previous = ch.videos
                        val seekById = previous.associate { it.id to it.allowSeek }
                        val retained = previous.filter {
                            it.manual || it.isDirect() || it.id in seedIds
                        }
                        val retainedIds = retained.map { it.id }.toSet()
                        val remote = videos
                            .filter { it.id !in retainedIds }
                            .map {
                                it.copy(
                                    manual = false,
                                    allowSeek = seekById[it.id] ?: true
                                )
                            }
                        ch.copy(
                            videos = (remote + retained).distinctBy { it.id }.newestFirst(),
                            sourceType = SourceType.YOUTUBE_PLAYLIST
                        )
                    }
                    Result.success(videos.size)
                },
                onFailure = { Result.failure(it) }
            )
        }

        val youtubeIds = channel.videos.mapNotNull { it.youtubeVideoId }.filter { it.isNotBlank() }
        if (youtubeIds.isEmpty()) {
            return if (!playlistId.isNullOrBlank() && !importPlaylist) {
                Result.failure(
                    IllegalStateException(
                        "Follow uploads is off — enable it to import playlist items"
                    )
                )
            } else if (channel.videos.isNotEmpty()) {
                Result.success(channel.videos.size)
            } else {
                Result.failure(IllegalStateException("Missing API key or playlist"))
            }
        }

        return youtube.fetchVideoDetails(apiKey, youtubeIds).fold(
            onSuccess = { details ->
                val byId = details.associateBy { it.id }
                val enriched = channel.videos.map { existing ->
                    val detail = byId[existing.youtubeVideoId ?: existing.id]
                    if (detail == null) existing
                    else existing.copy(
                        title = detail.title.ifBlank { existing.title },
                        thumbnailUrl = detail.thumbnailUrl ?: existing.thumbnailUrl,
                        publishedAtMs = detail.publishedAtMs ?: existing.publishedAtMs
                    )
                }.newestFirst()
                updateChannel(channelId) { it.copy(videos = enriched) }
                Result.success(enriched.size)
            },
            onFailure = { Result.failure(it) }
        )
    }

    suspend fun refreshAllPlaylists(force: Boolean = false): SyncResult {
        val settings = current()
        val apiKey = ApiKeyResolver.effective(settings.youtubeApiKey)
        if (apiKey.isNullOrBlank()) {
            return SyncResult(SyncStatus.SKIPPED_NO_KEY, message = "No YouTube API key")
        }
        if (!NetworkStatus.isOnline(context)) {
            return SyncResult(SyncStatus.SKIPPED_OFFLINE, message = "Offline")
        }

        val emptyPlaylistLibraries = settings.channels.any {
            it.enabled && !it.youtubePlaylistId.isNullOrBlank() && it.videos.isEmpty()
        }
        val needsForce = force || emptyPlaylistLibraries
        val now = System.currentTimeMillis()
        if (!needsForce && now - settings.lastSyncMs < syncTtlMs) {
            return SyncResult(SyncStatus.SKIPPED_TTL, message = "Within sync TTL")
        }

        var updatedChannels = 0
        var totalVideos = 0
        var failures = 0
        for (ch in settings.channels) {
            if (!ch.enabled) continue
            val hasPlaylist = !ch.youtubePlaylistId.isNullOrBlank()
            val hasYoutubeVideos = ch.videos.any { !it.youtubeVideoId.isNullOrBlank() }
            if (!hasPlaylist && !hasYoutubeVideos) continue
            val importPlaylist =
                SyncPolicy.shouldImportPlaylist(ch.followUploads, ch.videos.size)
            // Force and auto both honor followUploads — never dump UU playlists without opt-in.
            if (hasPlaylist && !importPlaylist) {
                if (!force) continue // auto: leave closed libraries alone
                if (!hasYoutubeVideos) continue // force: nothing to metadata-enrich
            }
            val result = refreshChannelFromYoutube(ch.id, allowPlaylistImport = importPlaylist)
            if (result.isSuccess) {
                updatedChannels++
                totalVideos += result.getOrDefault(0)
            } else {
                failures++
            }
        }

        if (updatedChannels > 0) {
            update { it.copy(lastSyncMs = System.currentTimeMillis()) }
            return SyncResult(
                status = SyncStatus.UPDATED,
                updatedChannels = updatedChannels,
                videoCount = totalVideos
            )
        }
        if (failures > 0) {
            return SyncResult(
                status = SyncStatus.FAILED,
                message = "Sync failed for $failures channel(s)"
            )
        }
        return SyncResult(
            status = SyncStatus.SKIPPED_TTL,
            message = if (force) {
                "Nothing to sync — enable Follow uploads on channels to import playlists"
            } else {
                "Nothing to sync"
            }
        )
    }

    suspend fun setPlaylistId(channelId: String, raw: String?) {
        val playlistId = YoutubeUrlParser.extractPlaylistId(raw)
        updateChannel(channelId) {
            it.copy(
                youtubePlaylistId = playlistId,
                sourceType = SourceType.YOUTUBE_PLAYLIST,
                playlistManagedByParent = true
            )
        }
    }

    suspend fun setFollowUploads(channelId: String, follow: Boolean) {
        updateChannel(channelId) { it.copy(followUploads = follow, playlistManagedByParent = true) }
    }

    suspend fun addManualVideoIds(channelId: String, csv: String) {
        val ids = YoutubeUrlParser.parseVideoIdsCsv(csv)
        if (ids.isEmpty()) return
        val apiKey = ApiKeyResolver.effective(current().youtubeApiKey)
        val newVideos = if (!apiKey.isNullOrBlank()) {
            youtube.fetchVideoDetails(apiKey, ids).getOrElse { youtube.videosFromIds(ids) }
                .map { it.copy(manual = true) }
        } else {
            youtube.videosFromIds(ids).map { it.copy(manual = true) }
        }
        updateChannel(channelId) { ch ->
            val merged = (ch.videos + newVideos).distinctBy { it.id }.newestFirst()
            ch.copy(videos = merged, sourceType = SourceType.YOUTUBE_VIDEO_LIST)
        }
    }

    suspend fun addDirectVideo(channelId: String, title: String, url: String) {
        val id = "direct_${System.currentTimeMillis()}"
        val item = VideoItem(
            id = id,
            title = title.ifBlank { "Video" },
            directUrl = url,
            publishedAtMs = System.currentTimeMillis(),
            manual = true
        )
        updateChannel(channelId) { ch ->
            ch.copy(videos = (ch.videos + item).newestFirst(), sourceType = SourceType.DIRECT_URL)
        }
    }

    suspend fun removeVideo(channelId: String, videoId: String) {
        updateChannel(channelId) { ch ->
            ch.copy(videos = ch.videos.filterNot { it.id == videoId })
        }
    }

    /** Drops synced/remote items; keeps parent-added manual and direct URLs. */
    suspend fun clearSyncedVideos(channelId: String) {
        updateChannel(channelId) { ch ->
            ch.copy(videos = ch.videos.filter { it.manual || it.isDirect() })
        }
    }

    suspend fun setChannelAllowSeek(channelId: String, allowSeek: Boolean) {
        updateChannel(channelId) { ch ->
            ch.copy(videos = ch.videos.map { it.copy(allowSeek = allowSeek) })
        }
    }

    suspend fun setVideoAllowSeek(channelId: String, videoId: String, allowSeek: Boolean) {
        updateChannel(channelId) { ch ->
            ch.copy(
                videos = ch.videos.map {
                    if (it.id == videoId) it.copy(allowSeek = allowSeek) else it
                }
            )
        }
    }

    suspend fun exportJson(): String = CatalogJson.encode(current().channels)

    private fun writeSettings(prefs: MutablePreferences, next: CatalogSettings) {
        val encoded = CatalogJson.encode(next.channels)
        prefs[Keys.CHANNELS_JSON] = encoded
        // Only promote last-good when the payload round-trips — never mirror corrupt writes.
        if (CatalogJson.decodeOrNull(encoded) != null) {
            prefs[Keys.CHANNELS_JSON_LAST_GOOD] = encoded
        }
        prefs[Keys.YOUTUBE_API_KEY] = next.youtubeApiKey.orEmpty()
        prefs[Keys.PIN_SALT] = next.pinSalt.orEmpty()
        prefs[Keys.PIN_HASH] = next.pinHash.orEmpty()
        prefs[Keys.PIN_CHANGED] = next.pinChangedFromDefault
        prefs[Keys.FAIL_COUNT] = next.failCount
        prefs[Keys.LOCKED_UNTIL] = next.lockedUntilMs
        prefs[Keys.RELEASE_READY] = next.releaseReady
        prefs[Keys.LAST_SYNC] = next.lastSyncMs
        prefs[Keys.SEED_VERSION] = next.seedVersion
    }

    private fun Preferences.toSettings(): CatalogSettings {
        val channelsJson = this[Keys.CHANNELS_JSON]
        val lastGood = this[Keys.CHANNELS_JSON_LAST_GOOD]
        val channels = when {
            !channelsJson.isNullOrBlank() -> {
                CatalogJson.decodeOrNull(channelsJson)
                    ?: CatalogJson.decodeOrNull(lastGood.orEmpty())
                    ?: DefaultChannels.seed()
            }
            !lastGood.isNullOrBlank() -> {
                CatalogJson.decodeOrNull(lastGood) ?: DefaultChannels.seed()
            }
            else -> DefaultChannels.seed()
        }
        return CatalogSettings(
            channels = channels,
            youtubeApiKey = this[Keys.YOUTUBE_API_KEY]?.ifBlank { null },
            pinSalt = this[Keys.PIN_SALT]?.ifBlank { null },
            pinHash = this[Keys.PIN_HASH]?.ifBlank { null },
            pinChangedFromDefault = this[Keys.PIN_CHANGED] ?: false,
            failCount = this[Keys.FAIL_COUNT] ?: 0,
            lockedUntilMs = this[Keys.LOCKED_UNTIL] ?: 0L,
            releaseReady = this[Keys.RELEASE_READY] ?: false,
            lastSyncMs = this[Keys.LAST_SYNC] ?: 0L,
            seedVersion = this[Keys.SEED_VERSION] ?: 0
        )
    }

    private object Keys {
        val CHANNELS_JSON = stringPreferencesKey("channels_json")
        val CHANNELS_JSON_LAST_GOOD = stringPreferencesKey("channels_json_last_good")
        val YOUTUBE_API_KEY = stringPreferencesKey("youtube_api_key")
        val PIN_SALT = stringPreferencesKey("pin_salt")
        val PIN_HASH = stringPreferencesKey("pin_hash")
        val PIN_CHANGED = booleanPreferencesKey("pin_changed")
        val FAIL_COUNT = intPreferencesKey("fail_count")
        val LOCKED_UNTIL = longPreferencesKey("locked_until")
        val RELEASE_READY = booleanPreferencesKey("release_ready")
        val LAST_SYNC = longPreferencesKey("last_sync")
        val SEED_VERSION = intPreferencesKey("seed_version")
    }
}
