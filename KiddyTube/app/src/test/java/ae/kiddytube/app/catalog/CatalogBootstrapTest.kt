package ae.kiddytube.app.catalog

import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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
        assertTrue(runs.get() == 1)
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
}
