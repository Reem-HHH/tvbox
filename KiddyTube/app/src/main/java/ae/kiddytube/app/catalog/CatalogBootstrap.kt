package ae.kiddytube.app.catalog

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Gates first-launch sync until default PIN setup and seed upgrade finish.
 * Safe for concurrent awaiters; [run] is idempotent.
 */
class CatalogBootstrap {
    private val mutex = Mutex()
    private val ready = CompletableDeferred<Unit>()

    val isReady: Boolean get() = ready.isCompleted

    suspend fun run(block: suspend () -> Unit) {
        if (ready.isCompleted) return
        mutex.withLock {
            if (ready.isCompleted) return
            try {
                block()
            } finally {
                ready.complete(Unit)
            }
        }
    }

    suspend fun await() {
        ready.await()
    }
}
