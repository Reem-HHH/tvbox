package ae.kiddytube.app.catalog

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Gates first-launch sync until default PIN setup and seed upgrade finish.
 * Safe for concurrent awaiters. Successful [run] is idempotent; a failed [run]
 * does not mark ready and may be retried.
 */
class CatalogBootstrap {
    private val mutex = Mutex()
    private var ready = CompletableDeferred<Unit>()
    @Volatile private var succeeded = false

    val isReady: Boolean get() = succeeded

    suspend fun run(block: suspend () -> Unit) {
        if (succeeded) return
        mutex.withLock {
            if (succeeded) return
            try {
                block()
                succeeded = true
                if (!ready.isCompleted) {
                    ready.complete(Unit)
                }
            } catch (e: Exception) {
                val failed = ready
                ready = CompletableDeferred()
                if (!failed.isCompleted) {
                    failed.completeExceptionally(e)
                }
                throw e
            }
        }
    }

    suspend fun await() {
        while (true) {
            val gate = ready
            try {
                gate.await()
                return
            } catch (e: Exception) {
                if (succeeded) return
                // Another run may have replaced [ready]; retry on the new gate.
                if (ready === gate) throw e
            }
        }
    }
}
