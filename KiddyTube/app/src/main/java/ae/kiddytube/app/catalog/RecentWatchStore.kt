package ae.kiddytube.app.catalog

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

private val Context.recentWatchStore: DataStore<Preferences> by preferencesDataStore(
    name = "kids_recent_watch"
)

class RecentWatchStore(private val context: Context) {
    private val store = context.recentWatchStore
    private val mutex = Mutex()

    val itemsFlow: Flow<List<RecentWatchItem>> = store.data.map { prefs ->
        readItems(prefs)
    }

    suspend fun current(): List<RecentWatchItem> = itemsFlow.first()

    suspend fun record(item: RecentWatchItem) {
        mutex.withLock {
            store.edit { prefs ->
                val existing = readItems(prefs)
                val next = RecentWatchLogic.prepend(existing, item)
                val encoded = RecentWatchJson.encode(next)
                prefs[Keys.ITEMS_JSON] = encoded
                // Only promote last-good when the payload round-trips.
                if (RecentWatchJson.decodeOrNull(encoded) != null) {
                    prefs[Keys.ITEMS_JSON_LAST_GOOD] = encoded
                }
            }
        }
    }

    suspend fun clear() {
        mutex.withLock {
            store.edit { it.clear() }
        }
    }

    private fun readItems(prefs: Preferences): List<RecentWatchItem> {
        val primary = prefs[Keys.ITEMS_JSON]
        val lastGood = prefs[Keys.ITEMS_JSON_LAST_GOOD]
        return when {
            !primary.isNullOrBlank() -> {
                RecentWatchJson.decodeOrNull(primary)
                    ?: RecentWatchJson.decodeOrNull(lastGood.orEmpty())
                    ?: emptyList()
            }
            !lastGood.isNullOrBlank() -> {
                RecentWatchJson.decodeOrNull(lastGood) ?: emptyList()
            }
            else -> emptyList()
        }
    }

    private object Keys {
        val ITEMS_JSON = stringPreferencesKey("recent_watch_json")
        val ITEMS_JSON_LAST_GOOD = stringPreferencesKey("recent_watch_json_last_good")
    }
}
