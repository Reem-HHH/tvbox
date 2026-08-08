package ae.kiddytube.app.ui

import android.os.SystemClock

/** Blocks double-opens from double OK / double tap that stack activities. */
object OpenDebouncer {
    private var lastKey: String? = null
    private var lastOpenUptimeMs: Long = 0L

    fun tryOpen(key: String, windowMs: Long = 650L): Boolean {
        val now = SystemClock.uptimeMillis()
        if (key == lastKey && now - lastOpenUptimeMs < windowMs) {
            return false
        }
        lastKey = key
        lastOpenUptimeMs = now
        return true
    }
}
