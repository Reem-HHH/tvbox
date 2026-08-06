package ae.kiddytube.app.sources

import java.net.URI

object MediaUrlValidator {
    private val allowedSchemes = setOf("https")

    fun isDirectMediaUrl(url: String?): Boolean {
        if (url.isNullOrBlank()) return false
        if (isBlockedViewerPage(url)) return false
        return try {
            val uri = URI(url.trim())
            uri.scheme?.lowercase() in allowedSchemes && !uri.host.isNullOrBlank()
        } catch (_: Exception) {
            false
        }
    }

    fun isBlockedViewerPage(url: String): Boolean {
        val lower = url.lowercase()
        return lower.contains("drive.google.com") && lower.contains("/view") ||
            lower.contains("docs.google.com") ||
            lower.contains("youtube.com/watch") ||
            lower.contains("youtu.be/") && !lower.contains("embed")
    }
}
