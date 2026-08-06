package ae.kidstv.launcher.catalog

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import ae.kidstv.launcher.sources.YoutubeCatalogSource
import ae.kidstv.launcher.sources.YoutubeUrlParser
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

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
    val lastSyncMs: Long = 0L
)

class CatalogRepository(private val context: Context) {
    private val store = context.catalogStore
    private val youtube = YoutubeCatalogSource()
    private val syncTtlMs = 24 * 60 * 60 * 1000L

    val settingsFlow: Flow<CatalogSettings> = store.data.map { it.toSettings() }

    suspend fun current(): CatalogSettings = settingsFlow.first()

    fun enabledChannels(settings: CatalogSettings): List<ContentChannel> =
        settings.channels.filter { it.enabled }.sortedBy { it.sortOrder }

    suspend fun update(transform: (CatalogSettings) -> CatalogSettings) {
        val next = transform(current())
        store.edit { prefs ->
            prefs[Keys.CHANNELS_JSON] = CatalogJson.encode(next.channels)
            prefs[Keys.YOUTUBE_API_KEY] = next.youtubeApiKey.orEmpty()
            prefs[Keys.PIN_SALT] = next.pinSalt.orEmpty()
            prefs[Keys.PIN_HASH] = next.pinHash.orEmpty()
            prefs[Keys.PIN_CHANGED] = next.pinChangedFromDefault
            prefs[Keys.FAIL_COUNT] = next.failCount
            prefs[Keys.LOCKED_UNTIL] = next.lockedUntilMs
            prefs[Keys.RELEASE_READY] = next.releaseReady
            prefs[Keys.LAST_SYNC] = next.lastSyncMs
        }
    }

    suspend fun resetAll() {
        store.edit { it.clear() }
    }

    suspend fun channelById(id: String): ContentChannel? =
        current().channels.firstOrNull { it.id == id }

    suspend fun updateChannel(channelId: String, transform: (ContentChannel) -> ContentChannel) {
        update { s ->
            s.copy(channels = s.channels.map { if (it.id == channelId) transform(it) else it })
        }
    }

    suspend fun refreshChannelFromYoutube(channelId: String): Result<Int> {
        val settings = current()
        val channel = settings.channels.firstOrNull { it.id == channelId }
            ?: return Result.failure(IllegalArgumentException("Unknown channel"))
        val apiKey = settings.youtubeApiKey
        val playlistId = channel.youtubePlaylistId

        val videos = when {
            !apiKey.isNullOrBlank() && !playlistId.isNullOrBlank() -> {
                youtube.fetchPlaylistVideos(apiKey, playlistId)
            }
            channel.videos.isNotEmpty() -> channel.videos
            else -> emptyList()
        }

        updateChannel(channelId) { it.copy(videos = videos) }
        update { it.copy(lastSyncMs = System.currentTimeMillis()) }
        return Result.success(videos.size)
    }

    suspend fun refreshAllPlaylists(force: Boolean = false): Int {
        val settings = current()
        val now = System.currentTimeMillis()
        if (!force && now - settings.lastSyncMs < syncTtlMs) return 0
        if (settings.youtubeApiKey.isNullOrBlank()) return 0
        var total = 0
        for (ch in settings.channels) {
            if (!ch.enabled || ch.youtubePlaylistId.isNullOrBlank()) continue
            refreshChannelFromYoutube(ch.id).getOrNull()?.let { total += it }
        }
        return total
    }

    suspend fun setPlaylistId(channelId: String, raw: String?) {
        val playlistId = YoutubeUrlParser.extractPlaylistId(raw)
        updateChannel(channelId) {
            it.copy(youtubePlaylistId = playlistId, sourceType = SourceType.YOUTUBE_PLAYLIST)
        }
    }

    suspend fun addManualVideoIds(channelId: String, csv: String) {
        val ids = YoutubeUrlParser.parseVideoIdsCsv(csv)
        if (ids.isEmpty()) return
        val newVideos = youtube.videosFromIds(ids)
        updateChannel(channelId) { ch ->
            val merged = (ch.videos + newVideos).distinctBy { it.id }
            ch.copy(videos = merged, sourceType = SourceType.YOUTUBE_VIDEO_LIST)
        }
    }

    suspend fun addDirectVideo(channelId: String, title: String, url: String) {
        val id = "direct_${System.currentTimeMillis()}"
        val item = VideoItem(id = id, title = title.ifBlank { "Video" }, directUrl = url)
        updateChannel(channelId) { ch ->
            ch.copy(videos = ch.videos + item, sourceType = SourceType.DIRECT_URL)
        }
    }

    suspend fun removeVideo(channelId: String, videoId: String) {
        updateChannel(channelId) { ch ->
            ch.copy(videos = ch.videos.filterNot { it.id == videoId })
        }
    }

    suspend fun exportJson(): String = CatalogJson.encode(current().channels)

    private fun Preferences.toSettings(): CatalogSettings {
        val channelsJson = this[Keys.CHANNELS_JSON]
        val channels = if (channelsJson.isNullOrBlank()) DefaultChannels.seed()
        else CatalogJson.decode(channelsJson)
        return CatalogSettings(
            channels = channels,
            youtubeApiKey = this[Keys.YOUTUBE_API_KEY]?.ifBlank { null },
            pinSalt = this[Keys.PIN_SALT]?.ifBlank { null },
            pinHash = this[Keys.PIN_HASH]?.ifBlank { null },
            pinChangedFromDefault = this[Keys.PIN_CHANGED] ?: false,
            failCount = this[Keys.FAIL_COUNT] ?: 0,
            lockedUntilMs = this[Keys.LOCKED_UNTIL] ?: 0L,
            releaseReady = this[Keys.RELEASE_READY] ?: false,
            lastSyncMs = this[Keys.LAST_SYNC] ?: 0L
        )
    }

    private object Keys {
        val CHANNELS_JSON = stringPreferencesKey("channels_json")
        val YOUTUBE_API_KEY = stringPreferencesKey("youtube_api_key")
        val PIN_SALT = stringPreferencesKey("pin_salt")
        val PIN_HASH = stringPreferencesKey("pin_hash")
        val PIN_CHANGED = booleanPreferencesKey("pin_changed")
        val FAIL_COUNT = intPreferencesKey("fail_count")
        val LOCKED_UNTIL = longPreferencesKey("locked_until")
        val RELEASE_READY = booleanPreferencesKey("release_ready")
        val LAST_SYNC = longPreferencesKey("last_sync")
    }
}
