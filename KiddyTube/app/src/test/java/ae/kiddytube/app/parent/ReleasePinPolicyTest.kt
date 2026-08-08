package ae.kiddytube.app.parent

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReleasePinPolicyTest {

    @Test
    fun debugAllowsDefaultUntilReleaseReady() {
        assertFalse(
            ReleasePinPolicy.rejectDefaultDevPin(
                isDebugBuild = true,
                releaseReady = false,
                pinChangedFromDefault = false
            )
        )
        assertTrue(
            ReleasePinPolicy.rejectDefaultDevPin(
                isDebugBuild = true,
                releaseReady = true,
                pinChangedFromDefault = true
            )
        )
    }

    @Test
    fun releaseRejectsDefaultAfterPinChanged() {
        assertFalse(
            ReleasePinPolicy.rejectDefaultDevPin(
                isDebugBuild = false,
                releaseReady = false,
                pinChangedFromDefault = false
            )
        )
        assertTrue(
            ReleasePinPolicy.rejectDefaultDevPin(
                isDebugBuild = false,
                releaseReady = false,
                pinChangedFromDefault = true
            )
        )
    }

    @Test
    fun releaseBlocksKidPlaybackUntilPinChanged() {
        assertTrue(
            ReleasePinPolicy.requirePinChangeForKidPlayback(
                isDebugBuild = false,
                pinChangedFromDefault = false
            )
        )
        assertFalse(
            ReleasePinPolicy.requirePinChangeForKidPlayback(
                isDebugBuild = false,
                pinChangedFromDefault = true
            )
        )
        assertFalse(
            ReleasePinPolicy.requirePinChangeForKidPlayback(
                isDebugBuild = true,
                pinChangedFromDefault = false
            )
        )
    }

    @Test
    fun sanitizeClearsFlagsWhenHashStillDefault() {
        val salt = ParentPinManager.newSaltHex()
        val hash = ParentPinManager.hashPin(ParentPinManager.DEFAULT_DEV_PIN, salt)!!
        val sanitized = ReleasePinPolicy.sanitizePinFlags(
            pinSalt = salt,
            pinHash = hash,
            pinChangedFromDefault = true,
            releaseReady = true
        )
        assertFalse(sanitized.pinChangedFromDefault)
        assertFalse(sanitized.releaseReady)
    }

    @Test
    fun sanitizeKeepsChangedWhenHashNotDefault() {
        val salt = ParentPinManager.newSaltHex()
        val hash = ParentPinManager.hashPin("9999", salt)!!
        val sanitized = ReleasePinPolicy.sanitizePinFlags(
            pinSalt = salt,
            pinHash = hash,
            pinChangedFromDefault = true,
            releaseReady = true
        )
        assertTrue(sanitized.pinChangedFromDefault)
        assertTrue(sanitized.releaseReady)
        assertEquals(true, ReleasePinPolicy.matchesDefaultDevPin(salt, hash).not())
    }
}
