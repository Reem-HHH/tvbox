package ae.kiddytube.app

import android.app.Application
import ae.kiddytube.app.catalog.CatalogBootstrap
import ae.kiddytube.app.catalog.CatalogRepository
import ae.kiddytube.app.catalog.RecentWatchItem
import ae.kiddytube.app.catalog.RecentWatchStore
import ae.kiddytube.app.diagnostics.DiagnosticsLogger
import ae.kiddytube.app.parent.ParentPinManager
import ae.kiddytube.app.tv.WatchNextPublisher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class KiddyTubeApp : Application() {
    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    lateinit var catalogRepository: CatalogRepository
        private set
    lateinit var recentWatchStore: RecentWatchStore
        private set
    lateinit var watchNextPublisher: WatchNextPublisher
        private set
    private val catalogBootstrap = CatalogBootstrap()

    override fun onCreate() {
        super.onCreate()
        catalogRepository = CatalogRepository(this)
        catalogRepository.bindBootstrap(catalogBootstrap)
        recentWatchStore = RecentWatchStore(this)
        watchNextPublisher = WatchNextPublisher(this)
        DiagnosticsLogger.get(this).logStartup()
        // Application.onCreate runs before Activity; sync/UI must await this gate.
        appScope.launch {
            catalogBootstrap.run {
                catalogRepository.migrateSensitiveSecretsIfNeeded()
                ensureDefaultPin()
                catalogRepository.applySeedUpgradeIfNeeded()
            }
            republishWatchNext()
        }
    }

    /** Suspend until default PIN + seed upgrade finished (first-launch sync gate). */
    suspend fun awaitCatalogReady() = catalogBootstrap.await()

    suspend fun recordRecentWatch(item: RecentWatchItem) {
        recentWatchStore.record(item)
        withContext(Dispatchers.IO) {
            watchNextPublisher.upsert(item)
        }
    }

    suspend fun clearRecentWatch() {
        recentWatchStore.clear()
        withContext(Dispatchers.IO) {
            watchNextPublisher.clearAll()
        }
    }

    private suspend fun republishWatchNext() {
        val items = recentWatchStore.current()
        if (items.isEmpty()) return
        withContext(Dispatchers.IO) {
            items.asReversed().forEach { watchNextPublisher.upsert(it) }
        }
    }

    private suspend fun ensureDefaultPin() {
        val settings = catalogRepository.current()
        if (settings.pinSalt.isNullOrBlank() || settings.pinHash.isNullOrBlank()) {
            val salt = ParentPinManager.newSaltHex()
            val hash = ParentPinManager.hashPin(ParentPinManager.DEFAULT_DEV_PIN, salt)
            catalogRepository.update {
                it.copy(
                    pinSalt = salt,
                    pinHash = hash,
                    pinChangedFromDefault = false,
                    releaseReady = false
                )
            }
        }
    }
}
