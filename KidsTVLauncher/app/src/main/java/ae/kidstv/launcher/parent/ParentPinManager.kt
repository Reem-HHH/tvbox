package ae.kidstv.launcher.parent

import android.view.KeyEvent
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.ArrayDeque
import java.util.Locale

/**
 * Parent unlock: Konami-style sequence, optional alternate sequence, Back long-press,
 * salted SHA-256 PIN verification, and temporary rate limiting.
 */
class ParentPinManager(
    failureCount: Int = 0,
    lockedUntilMs: Long = 0L
) {
    private val recentKeys = ArrayDeque<Int>()
    private var lastKeyAtMs = 0L
    private var backDownAtMs = 0L
    var failureCount: Int = failureCount.coerceAtLeast(0)
        private set
    var lockedUntilMs: Long = lockedUntilMs.coerceAtLeast(0L)
        private set

    fun clearKeys() {
        recentKeys.clear()
        lastKeyAtMs = 0L
    }

    fun onBackDown(nowMs: Long) {
        backDownAtMs = nowMs
    }

    fun onBackUp(nowMs: Long): Boolean {
        val started = backDownAtMs
        backDownAtMs = 0L
        return started > 0L && nowMs - started >= BACK_LONG_PRESS_MS
    }

    fun recordKeyAndCheckTrigger(
        keyCode: Int,
        nowMs: Long,
        alternateSequence: IntArray? = null
    ): Boolean {
        if (lastKeyAtMs > 0L && nowMs - lastKeyAtMs > KEY_IDLE_TIMEOUT_MS) {
            recentKeys.clear()
        }
        lastKeyAtMs = nowMs
        recentKeys.addLast(keyCode)
        while (recentKeys.size > TRIGGER_SEQUENCE.size) {
            recentKeys.removeFirst()
        }
        if (matches(TRIGGER_SEQUENCE)) return true
        if (alternateSequence != null && alternateSequence.isNotEmpty() && matches(alternateSequence)) {
            return true
        }
        return false
    }

    private fun matches(sequence: IntArray): Boolean {
        if (recentKeys.size < sequence.size) return false
        val keys = recentKeys.toList()
        val start = keys.size - sequence.size
        for (i in sequence.indices) {
            if (keys[start + i] != sequence[i]) return false
        }
        return true
    }

    fun refreshLockout(nowMs: Long) {
        if (lockedUntilMs > 0L && nowMs >= lockedUntilMs) {
            lockedUntilMs = 0L
            failureCount = 0
        }
    }

    fun isLockedOut(nowMs: Long): Boolean {
        refreshLockout(nowMs)
        return nowMs < lockedUntilMs
    }

    fun remainingLockoutMs(nowMs: Long): Long = maxOf(0L, lockedUntilMs - nowMs)

    fun verifyPin(pin: String, saltHex: String?, expectedHashHex: String?): Boolean {
        if (!isValidPinFormat(pin) || saltHex.isNullOrBlank() || expectedHashHex.isNullOrBlank()) {
            return false
        }
        val actual = hashPin(pin, saltHex) ?: return false
        return actual.equals(expectedHashHex, ignoreCase = true)
    }

    fun registerFailure(nowMs: Long): Boolean {
        failureCount++
        if (failureCount >= MAX_FAILURES_BEFORE_LOCKOUT) {
            val rounds = failureCount - MAX_FAILURES_BEFORE_LOCKOUT + 1
            val multiplier = 1L shl minOf(rounds - 1, 4)
            lockedUntilMs = nowMs + BASE_LOCKOUT_MS * multiplier
            return true
        }
        return false
    }

    fun registerSuccess() {
        failureCount = 0
        lockedUntilMs = 0L
        clearKeys()
    }

    companion object {
        const val DEFAULT_DEV_PIN = "2580"
        const val MIN_PIN_LENGTH = 4
        const val MAX_PIN_LENGTH = 8
        const val KEY_IDLE_TIMEOUT_MS = 3_000L
        const val BACK_LONG_PRESS_MS = 5_000L
        const val MAX_FAILURES_BEFORE_LOCKOUT = 5
        const val BASE_LOCKOUT_MS = 30_000L

        val TRIGGER_SEQUENCE = intArrayOf(
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_DOWN,
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_DPAD_CENTER
        )

        fun isValidPinFormat(pin: String?): Boolean {
            if (pin == null) return false
            if (pin.length !in MIN_PIN_LENGTH..MAX_PIN_LENGTH) return false
            return pin.all { it in '0'..'9' }
        }

        fun newSaltHex(): String {
            val salt = ByteArray(16)
            SecureRandom().nextBytes(salt)
            return toHex(salt)
        }

        fun hashPin(pin: String, saltHex: String): String? {
            return try {
                val digest = MessageDigest.getInstance("SHA-256")
                digest.update(fromHex(saltHex))
                digest.update(pin.toByteArray(StandardCharsets.UTF_8))
                toHex(digest.digest())
            } catch (_: Exception) {
                null
            }
        }

        fun parseSequenceCsv(csv: String?): IntArray? {
            if (csv.isNullOrBlank()) return null
            return try {
                csv.split(',').map { it.trim().toInt() }.toIntArray().takeIf { it.isNotEmpty() }
            } catch (_: Exception) {
                null
            }
        }

        private fun toHex(bytes: ByteArray): String =
            bytes.joinToString("") { String.format(Locale.US, "%02x", it) }

        private fun fromHex(hex: String): ByteArray {
            val value = hex.trim()
            require(value.length % 2 == 0)
            return ByteArray(value.length / 2) { i ->
                value.substring(i * 2, i * 2 + 2).toInt(16).toByte()
            }
        }
    }
}
