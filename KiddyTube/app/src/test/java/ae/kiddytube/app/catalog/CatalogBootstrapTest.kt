package ae.kiddytube.app.catalog

import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class CatalogBootstrapTest {
    @Test
    fun awaitBlocksUntilRunCompletes() = runTest {
        val gate = CatalogBootstrap()
        val finished = AtomicBoolean(false)

        val waiter = async {
            gate.await()
            finished.get()
        }

        delay(20)
        assertFalse(gate.isReady)

        gate.run {
            delay(30)
            finished.set(true)
        }

        assertTrue(gate.isReady)
        assertTrue(waiter.await())
    }

    @Test
    fun runIsIdempotent() = runTest {
        val gate = CatalogBootstrap()
        val runs = AtomicInteger(0)

        gate.run { runs.incrementAndGet() }
        gate.run { runs.incrementAndGet() }

        assertTrue(gate.isReady)
        assertEquals(1, runs.get())
    }

    @Test
    fun concurrentAwaitersUnblockTogether() = runTest {
        val gate = CatalogBootstrap()
        val a = async { gate.await(); true }
        val b = async { gate.await(); true }

        delay(10)
        gate.run { delay(5) }

        assertTrue(a.await())
        assertTrue(b.await())
        assertTrue(gate.isReady)
    }

    @Test
    fun failedRunDoesNotMarkReadyAndCanRetry() = runTest {
        val gate = CatalogBootstrap()
        val runs = AtomicInteger(0)
        try {
            gate.run {
                runs.incrementAndGet()
                error("boom")
            }
            fail("expected failure")
        } catch (_: IllegalStateException) {
            // expected
        }
        assertFalse(gate.isReady)
        assertEquals(1, runs.get())

        gate.run { runs.incrementAndGet() }
        assertTrue(gate.isReady)
        assertEquals(2, runs.get())
        gate.await()
    }

    @Test
    fun failedRunUnblocksAwaitWithException() = runTest {
        val gate = CatalogBootstrap()
        val waiter = async {
            try {
                gate.await()
                false
            } catch (_: Exception) {
                true
            }
        }
        delay(10)
        try {
            gate.run { error("boom") }
            fail("expected failure")
        } catch (_: IllegalStateException) {
            // expected
        }
        assertTrue(waiter.await())
        assertFalse(gate.isReady)
    }
}
