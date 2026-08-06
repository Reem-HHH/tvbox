package ae.kiddytube.app.diagnostics

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.FileProvider
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class DiagnosticsLogger(context: Context) {
    private val appContext = context.applicationContext
    private val lock = ReentrantLock()
    private val logDir = File(appContext.filesDir, "diagnostics").apply { mkdirs() }
    private val logFile = File(logDir, "kids_tv.log")
    private val maxBytes = 512 * 1024L

    fun log(event: String, details: String = "") {
        val stamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
        val line = buildString {
            append(stamp)
            append(" | ")
            append(event)
            if (details.isNotBlank()) {
                append(" | ")
                append(details.replace('\n', ' '))
            }
            append('\n')
        }
        lock.withLock {
            rotateIfNeeded()
            logFile.appendText(line)
        }
    }

    fun logStartup() {
        log(
            "startup",
            "android=${Build.VERSION.RELEASE} api=${Build.VERSION.SDK_INT} " +
                "manufacturer=${Build.MANUFACTURER} model=${Build.MODEL}"
        )
    }

    fun readTail(maxChars: Int = 12_000): String = lock.withLock {
        if (!logFile.exists()) return@withLock ""
        val text = logFile.readText()
        if (text.length <= maxChars) text else text.takeLast(maxChars)
    }

    fun createShareIntent(): Intent? = lock.withLock {
        if (!logFile.exists() || logFile.length() == 0L) return@withLock null
        val uri = FileProvider.getUriForFile(
            appContext,
            "${appContext.packageName}.fileprovider",
            logFile
        )
        Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "KiddyTube diagnostics")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    private fun rotateIfNeeded() {
        if (!logFile.exists() || logFile.length() < maxBytes) return
        val backup = File(logDir, "kids_tv.prev.log")
        if (backup.exists()) backup.delete()
        logFile.renameTo(backup)
        logFile.writeText("")
    }

    companion object {
        @Volatile private var instance: DiagnosticsLogger? = null

        fun get(context: Context): DiagnosticsLogger {
            return instance ?: synchronized(this) {
                instance ?: DiagnosticsLogger(context).also { instance = it }
            }
        }
    }
}
