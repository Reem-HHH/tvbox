package ae.kiddytube.app

import android.app.Application
import ae.kiddytube.app.catalog.CatalogBootstrap
import ae.kiddytube.app.catalog.CatalogRepository
import ae.kiddytube.app.catalog.RecentWatchItem
import ae.kiddytube.app.catalog.RecentWatchLogic
import ae.kiddytube.app.catalog.RecentWatchStore
import ae.kiddytube.app.diagnostics.DiagnosticsLogger
import ae.kiddytube.app.parent.ParentPinManager
import ae.kiddytube.app.tv.WatchNextPublisher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.min

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
        // Retry with backoff so a failed run does not leave awaiters permanently wedged.
        appScope.launch {
            var attempt = 0
            while (true) {
                try {
                    catalogBootstrap.run {
                        catalogRepository.migrateSensitiveSecretsIfNeeded()
                        ensureDefaultPin()
                        catalogRepository.applySeedUpgradeIfNeeded()
                    }
                    syncWatchNext()
                    return@launch
                } catch (e: Exception) {
                    attempt++
                    DiagnosticsLogger.get(this@KiddyTubeApp).log(
                        "bootstrap_failed",
                        "attempt=$attempt err=${e.javaClass.simpleName}:${e.message?.take(160)}"
                    )
                    val backoffMs = min(30_000L, 1_000L * (1L shl attempt.coerceAtMost(5)))
                    delay(backoffMs)
                }
            }
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

    /** Upsert playable continues; remove stale Watch Next cards for disabled/removed videos. */
    suspend fun syncWatchNext() {
        val settings = catalogRepository.current()
        val recent = recentWatchStore.current()
        val playable = RecentWatchLogic.resolvePlayable(recent, settings).map { it.first }
        val playableIds = playable.map { it.videoId }.toSet()
        withContext(Dispatchers.IO) {
            recent.forEach { item ->
                if (item.videoId !in playableIds) {
                    watchNextPublisher.remove(item.videoId)
                }
            }
            playable.asReversed().forEach { watchNextPublisher.upsert(it) }
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
