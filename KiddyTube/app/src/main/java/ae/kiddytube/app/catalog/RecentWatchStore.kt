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
        RecentWatchJson.decode(prefs[Keys.ITEMS_JSON].orEmpty())
    }

    suspend fun current(): List<RecentWatchItem> = itemsFlow.first()

    suspend fun record(item: RecentWatchItem) {
        mutex.withLock {
            store.edit { prefs ->
                val existing = RecentWatchJson.decode(prefs[Keys.ITEMS_JSON].orEmpty())
                prefs[Keys.ITEMS_JSON] = RecentWatchJson.encode(
                    RecentWatchLogic.prepend(existing, item)
                )
            }
        }
    }

    suspend fun clear() {
        mutex.withLock {
            store.edit { it.clear() }
        }
    }

    private object Keys {
        val ITEMS_JSON = stringPreferencesKey("recent_watch_json")
    }
}
