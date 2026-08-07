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
import ae.kiddytube.app.security.EncryptedSensitiveSecretsStore
import ae.kiddytube.app.security.SensitiveSecrets
import ae.kiddytube.app.security.SensitiveSecretsMigrator
import ae.kiddytube.app.security.SensitiveSecretsStore
import ae.kiddytube.app.sources.MediaUrlValidator
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

class CatalogRepository(
    private val context: Context,
    private val secretsStore: SensitiveSecretsStore = EncryptedSensitiveSecretsStore(context)
) {
    private val store = context.catalogStore
    private val youtube = YoutubeCatalogSource(context)
    private val syncTtlMs = 24 * 60 * 60 * 1000L
    private val writeMutex = Mutex()
    private var bootstrap: CatalogBootstrap? = null
    @Volatile private var migrationDone = false

    val settingsFlow: Flow<CatalogSettings> = store.data.map { it.toSettings() }

    suspend fun current(): CatalogSettings = settingsFlow.first()

    /** Wired from [ae.kiddytube.app.KiddyTubeApp] so sync cannot race seed/PIN bootstrap. */
    fun bindBootstrap(gate: CatalogBootstrap) {
        bootstrap = gate
    }

    suspend fun awaitReady() {
        bootstrap?.await()
    }

    /**
     * Moves API key / PIN material from plaintext DataStore (and any legacy plain SharedPreferences)
     * into [secretsStore], then clears the plain copies. Idempotent; safe before PIN bootstrap.
     */
    suspend fun migrateSensitiveSecretsIfNeeded() {
        if (migrationDone) return
        writeMutex.withLock {
            if (migrationDone) return
            val encrypted = secretsStore.read()
            val legacyPlain = (secretsStore as? EncryptedSensitiveSecretsStore)
                ?.readLegacyPlainSharedPrefs()
                ?: SensitiveSecrets()
            store.edit { prefs ->
                val fromDataStore = SensitiveSecrets(
                    youtubeApiKey = prefs[Keys.YOUTUBE_API_KEY]?.ifBlank { null },
                    pinSalt = prefs[Keys.PIN_SALT]?.ifBlank { null },
                    pinHash = prefs[Keys.PIN_HASH]?.ifBlank { null }
                )
                val plainMerged = SensitiveSecrets(
                    youtubeApiKey = fromDataStore.youtubeApiKey ?: legacyPlain.youtubeApiKey,
                    pinSalt = fromDataStore.pinSalt ?: legacyPlain.pinSalt,
                    pinHash = fromDataStore.pinHash ?: legacyPlain.pinHash
                )
                val result = SensitiveSecretsMigrator.migrate(encrypted, plainMerged)
                if (result.writeEncrypted) {
                    secretsStore.write(result.secrets)
                }
                if (result.clearPlain || !fromDataStore.isEmpty()) {
                    prefs.remove(Keys.YOUTUBE_API_KEY)
                    prefs.remove(Keys.PIN_SALT)
                    prefs.remove(Keys.PIN_HASH)
                }
            }
            if (!legacyPlain.isEmpty()) {
                (secretsStore as? EncryptedSensitiveSecretsStore)?.clearLegacyPlainSharedPrefs()
            }
            migrationDone = true
        }
    }

    fun enabledChannels(settings: CatalogSettings): List<ContentChannel> =
        settings.channels.filter { it.enabled }.sortedBy { it.sortOrder }

    fun effectiveApiKey(settings: CatalogSettings): String? =
        ApiKeyResolver.effective(settings.youtubeApiKey)

    suspend fun containsYoutubeVideoId(videoId: String): Boolean {
        val id = videoId.trim()
        return current().channels.any { ch ->
            ch.enabled && ch.videos.any { it.youtubeVideoId == id || it.id == id }
        }
    }

    suspend fun containsDirectUrl(url: String): Boolean {
        val target = url.trim()
        if (target.isEmpty()) return false
        return current().channels.any { ch ->
            ch.enabled && ch.videos.any { it.directUrl == target }
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
            secretsStore.clear()
            store.edit { it.clear() }
            migrationDone = true
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
            ?: SyncPolicy.shouldImportPlaylist(
                channel.followUploads,
                channel.videos.size,
                channel.suppressEmptyPlaylistImport
            )

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
                                    allowSeek = seekById[it.id] ?: ch.defaultAllowSeek
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
        // Never sync against a pre-upgrade / pre-PIN catalog on first launch.
        awaitReady()
        applySeedUpgradeIfNeeded()

        val settings = current()
        val apiKey = ApiKeyResolver.effective(settings.youtubeApiKey)
        if (apiKey.isNullOrBlank()) {
            return SyncResult(SyncStatus.SKIPPED_NO_KEY, message = "No YouTube API key")
        }
        if (!NetworkStatus.isOnline(context)) {
            return SyncResult(SyncStatus.SKIPPED_OFFLINE, message = "Offline")
        }

        val emptyPlaylistLibraries = settings.channels.any {
            it.enabled &&
                !it.youtubePlaylistId.isNullOrBlank() &&
                it.videos.isEmpty() &&
                SyncPolicy.shouldImportPlaylist(
                    it.followUploads,
                    it.videos.size,
                    it.suppressEmptyPlaylistImport
                )
        }
        val now = System.currentTimeMillis()
        val withinTtl = now - settings.lastSyncMs < syncTtlMs
        if (!SyncPolicy.shouldBypassTtl(force, emptyPlaylistLibraries) && withinTtl) {
            return SyncResult(SyncStatus.SKIPPED_TTL, message = "Within sync TTL")
        }

        var updatedChannels = 0
        var totalVideos = 0
        var failures = 0
        var firstError: String? = null
        for (ch in settings.channels) {
            if (!ch.enabled) continue
            val hasPlaylist = !ch.youtubePlaylistId.isNullOrBlank()
            val hasYoutubeVideos = ch.videos.any { !it.youtubeVideoId.isNullOrBlank() }
            val importPlaylist = SyncPolicy.shouldImportPlaylist(
                ch.followUploads,
                ch.videos.size,
                ch.suppressEmptyPlaylistImport
            )
            // Force and auto both honor followUploads — never dump UU playlists without opt-in.
            if (!SyncPolicy.shouldRefreshChannel(
                    force = force,
                    hasPlaylist = hasPlaylist,
                    hasYoutubeVideos = hasYoutubeVideos,
                    importPlaylist = importPlaylist
                )
            ) {
                continue
            }
            val result = refreshChannelFromYoutube(ch.id, allowPlaylistImport = importPlaylist)
            if (result.isSuccess) {
                updatedChannels++
                totalVideos += result.getOrDefault(0)
            } else {
                failures++
                if (firstError == null) {
                    firstError = result.exceptionOrNull()?.message?.trim()?.takeIf { it.isNotEmpty() }
                }
            }
        }

        if (updatedChannels > 0 && failures == 0) {
            update { it.copy(lastSyncMs = System.currentTimeMillis()) }
            return SyncResult(
                status = SyncStatus.UPDATED,
                updatedChannels = updatedChannels,
                videoCount = totalVideos
            )
        }
        if (updatedChannels > 0) {
            // Partial success: do not advance TTL so failed channels can retry soon.
            return SyncResult(
                status = SyncStatus.UPDATED,
                updatedChannels = updatedChannels,
                videoCount = totalVideos,
                message = firstError?.let { "Partial sync; some channels failed: ${it.take(120)}" }
            )
        }
        if (failures > 0) {
            val detail = firstError?.take(180)
            return SyncResult(
                status = SyncStatus.FAILED,
                message = if (detail.isNullOrBlank()) {
                    "Sync failed for $failures channel(s)"
                } else {
                    "Sync failed for $failures channel(s): $detail"
                }
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
        updateChannel(channelId) {
            it.copy(
                followUploads = follow,
                playlistManagedByParent = true,
                // Cleared when parent opts back into follow imports.
                suppressEmptyPlaylistImport = if (follow) false else it.suppressEmptyPlaylistImport
            )
        }
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
            val tagged = newVideos.map { it.copy(manual = true, allowSeek = ch.defaultAllowSeek) }
            val merged = (ch.videos + tagged).distinctBy { it.id }.newestFirst()
            ch.copy(videos = merged, sourceType = SourceType.YOUTUBE_VIDEO_LIST)
        }
    }

    suspend fun addDirectVideo(channelId: String, title: String, url: String) {
        if (!MediaUrlValidator.isDirectMediaUrl(url)) {
            throw IllegalArgumentException("Invalid direct media URL")
        }
        val id = "direct_${System.currentTimeMillis()}"
        updateChannel(channelId) { ch ->
            val item = VideoItem(
                id = id,
                title = title.ifBlank { "Video" },
                directUrl = url.trim(),
                publishedAtMs = System.currentTimeMillis(),
                manual = true,
                allowSeek = ch.defaultAllowSeek
            )
            ch.copy(
                videos = (listOf(item) + ch.videos).distinctBy { it.id }.newestFirst(),
                sourceType = if (ch.videos.any { it.isYoutube() }) ch.sourceType else SourceType.DIRECT_URL
            )
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
            ch.copy(
                videos = ch.videos.filter { it.manual || it.isDirect() },
                suppressEmptyPlaylistImport = true
            )
        }
    }

    suspend fun setChannelAllowSeek(channelId: String, allowSeek: Boolean) {
        updateChannel(channelId) { ch ->
            ch.copy(
                defaultAllowSeek = allowSeek,
                videos = ch.videos.map { it.copy(allowSeek = allowSeek) }
            )
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
        secretsStore.write(
            SensitiveSecrets(
                youtubeApiKey = next.youtubeApiKey,
                pinSalt = next.pinSalt,
                pinHash = next.pinHash
            )
        )
        // Never leave sensitive values in plaintext DataStore after a write.
        prefs.remove(Keys.YOUTUBE_API_KEY)
        prefs.remove(Keys.PIN_SALT)
        prefs.remove(Keys.PIN_HASH)
        prefs[Keys.PIN_CHANGED] = next.pinChangedFromDefault
        prefs[Keys.FAIL_COUNT] = next.failCount
        prefs[Keys.LOCKED_UNTIL] = next.lockedUntilMs
        // Never mark release-ready while still on the factory default PIN.
        prefs[Keys.RELEASE_READY] = next.releaseReady && next.pinChangedFromDefault
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
        val secrets = secretsStore.read()
        // During the brief window before migrateSensitiveSecretsIfNeeded(), fall back to
        // any leftover plaintext DataStore keys so UI/PIN bootstrap still sees values.
        return CatalogSettings(
            channels = channels,
            youtubeApiKey = secrets.youtubeApiKey
                ?: this[Keys.YOUTUBE_API_KEY]?.ifBlank { null },
            pinSalt = secrets.pinSalt ?: this[Keys.PIN_SALT]?.ifBlank { null },
            pinHash = secrets.pinHash ?: this[Keys.PIN_HASH]?.ifBlank { null },
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
        /** Legacy plaintext keys — cleared by [migrateSensitiveSecretsIfNeeded] / [writeSettings]. */
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
