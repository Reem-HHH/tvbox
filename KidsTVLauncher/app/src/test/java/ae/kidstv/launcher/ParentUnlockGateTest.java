package ae.kidstv.launcher;

import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

public class ParentUnlockGateTest {
    @Test
    public void matchesFullTriggerSequence() {
        ParentUnlockGate gate = new ParentUnlockGate();
        long now = 1_000L;
        int[] sequence = ParentUnlockGate.TRIGGER_SEQUENCE;
        for (int i = 0; i < sequence.length; i++) {
            boolean matched = gate.recordKeyAndCheckTrigger(sequence[i], now + i);
            assertEquals(i == sequence.length - 1, matched);
        }
    }

    @Test
    public void clearsSequenceAfterIdleTimeout() {
        ParentUnlockGate gate = new ParentUnlockGate();
        long now = 1_000L;
        int[] sequence = ParentUnlockGate.TRIGGER_SEQUENCE;
        gate.recordKeyAndCheckTrigger(sequence[0], now);
        gate.recordKeyAndCheckTrigger(sequence[1], now + 10);

        boolean matched = false;
        long later = now + ParentUnlockGate.KEY_IDLE_TIMEOUT_MS + 1;
        for (int i = 0; i < sequence.length; i++) {
            matched = gate.recordKeyAndCheckTrigger(sequence[i], later + i);
        }
        assertTrue(matched);
    }

    @Test
    public void rejectsWrongSequence() {
        ParentUnlockGate gate = new ParentUnlockGate();
        long now = 1_000L;
        // KEYCODE_DPAD_DOWN does not start the trigger sequence.
        assertFalse(gate.recordKeyAndCheckTrigger(20, now));
        assertFalse(gate.matchesTrigger());
    }

    @Test
    public void pinHashRoundTrip() {
        String salt = ParentUnlockGate.newSaltHex();
        assertNotNull(salt);
        assertEquals(32, salt.length());
        String hash = ParentUnlockGate.hashPin("1234", salt);
        assertNotNull(hash);

        ParentUnlockGate gate = new ParentUnlockGate();
        assertTrue(gate.verifyPin("1234", salt, hash));
        assertFalse(gate.verifyPin("0000", salt, hash));
        assertFalse(gate.verifyPin("12", salt, hash));
        assertFalse(ParentUnlockGate.isValidPinFormat("12a4"));
        assertTrue(ParentUnlockGate.isValidPinFormat("987654"));
    }

    @Test
    public void rateLimitEngagesAfterMaxFailures() {
        ParentUnlockGate gate = new ParentUnlockGate();
        long now = 10_000L;
        for (int i = 0; i < ParentUnlockGate.MAX_FAILURES_BEFORE_LOCKOUT - 1; i++) {
            assertFalse(gate.registerFailure(now));
            assertFalse(gate.isLockedOut(now));
        }
        assertTrue(gate.registerFailure(now));
        assertTrue(gate.isLockedOut(now));
        assertTrue(gate.remainingLockoutMs(now) > 0);

        long afterLockout = now + ParentUnlockGate.BASE_LOCKOUT_MS + 1;
        assertFalse(gate.isLockedOut(afterLockout));
        assertEquals(0, gate.getFailureCount());
    }

    @Test
    public void successClearsFailures() {
        ParentUnlockGate gate = new ParentUnlockGate();
        gate.registerFailure(1_000L);
        gate.registerFailure(1_001L);
        gate.registerSuccess();
        assertEquals(0, gate.getFailureCount());
        assertEquals(0L, gate.getLockedUntilMs());
    }
}
