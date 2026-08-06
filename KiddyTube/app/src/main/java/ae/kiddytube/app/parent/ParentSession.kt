package ae.kiddytube.app.parent

/**
 * In-memory parent unlock session. Survives activity recreation within the process
 * but not process death — Recents cold-resume still requires PIN after expiry.
 */
object ParentSession {
    private const val UNLOCK_TTL_MS = 5 * 60 * 1000L
    @Volatile
    private var unlockedUntilMs: Long = 0L

    fun grant(nowMs: Long = System.currentTimeMillis()) {
        unlockedUntilMs = nowMs + UNLOCK_TTL_MS
    }

    fun clear() {
        unlockedUntilMs = 0L
    }

    fun isActive(nowMs: Long = System.currentTimeMillis()): Boolean =
        nowMs < unlockedUntilMs
}
