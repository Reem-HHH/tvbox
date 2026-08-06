package ae.kidstv.launcher.parent

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ParentPinManagerTest {
    @Test
    fun matchesDefaultSequence() {
        val gate = ParentPinManager()
        var matched = false
        ParentPinManager.TRIGGER_SEQUENCE.forEachIndexed { index, code ->
            matched = gate.recordKeyAndCheckTrigger(code, 1000L + index)
        }
        assertTrue(matched)
    }

    @Test
    fun clearsOnIdleTimeout() {
        val gate = ParentPinManager()
        gate.recordKeyAndCheckTrigger(ParentPinManager.TRIGGER_SEQUENCE[0], 1000L)
        var matched = false
        val later = 1000L + ParentPinManager.KEY_IDLE_TIMEOUT_MS + 1
        ParentPinManager.TRIGGER_SEQUENCE.forEachIndexed { index, code ->
            matched = gate.recordKeyAndCheckTrigger(code, later + index)
        }
        assertTrue(matched)
    }

    @Test
    fun longPressBack() {
        val gate = ParentPinManager()
        gate.onBackDown(1000L)
        assertFalse(gate.onBackUp(1000L + ParentPinManager.BACK_LONG_PRESS_MS - 1))
        gate.onBackDown(2000L)
        assertTrue(gate.onBackUp(2000L + ParentPinManager.BACK_LONG_PRESS_MS))
    }

    @Test
    fun pinHashAndRateLimit() {
        val salt = ParentPinManager.newSaltHex()
        val hash = ParentPinManager.hashPin("2580", salt)
        assertNotNull(hash)
        val gate = ParentPinManager()
        assertTrue(gate.verifyPin("2580", salt, hash))
        assertFalse(gate.verifyPin("0000", salt, hash))

        val now = 10_000L
        repeat(ParentPinManager.MAX_FAILURES_BEFORE_LOCKOUT - 1) {
            assertFalse(gate.registerFailure(now))
        }
        assertTrue(gate.registerFailure(now))
        assertTrue(gate.isLockedOut(now))
        assertFalse(gate.isLockedOut(now + ParentPinManager.BASE_LOCKOUT_MS + 1))
        assertEquals(0, gate.failureCount)
    }

    @Test
    fun alternateSequence() {
        val gate = ParentPinManager()
        val alt = intArrayOf(21, 22, 23)
        assertFalse(gate.recordKeyAndCheckTrigger(21, 1, alt))
        assertFalse(gate.recordKeyAndCheckTrigger(22, 2, alt))
        assertTrue(gate.recordKeyAndCheckTrigger(23, 3, alt))
    }
}
