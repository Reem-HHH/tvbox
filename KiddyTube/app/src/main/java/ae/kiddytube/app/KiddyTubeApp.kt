package ae.kiddytube.app

import android.app.Application
import ae.kiddytube.app.catalog.CatalogRepository
import ae.kiddytube.app.diagnostics.DiagnosticsLogger
import ae.kiddytube.app.parent.ParentPinManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class KiddyTubeApp : Application() {
    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    lateinit var catalogRepository: CatalogRepository
        private set

    override fun onCreate() {
        super.onCreate()
        catalogRepository = CatalogRepository(this)
        DiagnosticsLogger.get(this).logStartup()
        appScope.launch {
            ensureDefaultPin()
            catalogRepository.applySeedUpgradeIfNeeded()
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
