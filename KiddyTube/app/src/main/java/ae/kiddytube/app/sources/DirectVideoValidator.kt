package ae.kiddytube.app.sources

import java.net.URI

object DirectVideoValidator {
    private val allowedSchemes = setOf("http", "https")

    fun isValidDirectMediaUrl(url: String?): Boolean {
        if (url.isNullOrBlank()) return false
        val trimmed = url.trim()
        if (isRejectedViewerPage(trimmed)) return false
        return try {
            val uri = URI(trimmed)
            uri.scheme?.lowercase() in allowedSchemes && !uri.host.isNullOrBlank()
        } catch (_: Exception) {
            false
        }
    }

    fun isRejectedViewerPage(url: String): Boolean {
        val lower = url.lowercase()
        return lower.contains("drive.google.com") && lower.contains("/view") ||
            lower.contains("docs.google.com") ||
            lower.contains("dropbox.com/s/") && !lower.contains("dl=1")
    }
}
