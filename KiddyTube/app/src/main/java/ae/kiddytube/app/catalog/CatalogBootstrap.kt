package ae.kiddytube.app.catalog

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Gates first-launch sync until default PIN setup and seed upgrade finish.
 * Safe for concurrent awaiters. Successful [run] is idempotent; a failed [run]
 * does not mark ready and may be retried. Failed attempts complete the current
 * gate exceptionally so awaiters can fall back instead of hanging forever.
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
            // Previous attempt failed: open a fresh gate for this retry.
            if (ready.isCompleted && !succeeded) {
                ready = CompletableDeferred()
            }
            try {
                block()
                succeeded = true
                if (!ready.isCompleted) {
                    ready.complete(Unit)
                }
            } catch (e: Exception) {
                if (!ready.isCompleted) {
                    ready.completeExceptionally(e)
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
                if (ready !== gate) continue
                // No newer attempt yet — unblock callers for best-effort catalog use.
                throw e
            }
        }
    }
}
