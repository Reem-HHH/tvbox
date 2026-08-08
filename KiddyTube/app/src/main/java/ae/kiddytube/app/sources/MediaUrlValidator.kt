package ae.kiddytube.app.sources

import java.net.URI

/**
 * Direct media must be HTTPS file/stream URLs (e.g. .mp4 / .m3u8 / .mpd).
 * Viewer pages and HTTP cleartext are rejected (manifest also disables cleartext).
 */
object MediaUrlValidator {
    private val allowedSchemes = setOf("https")
    private val allowedExtensions = listOf(".mp4", ".m3u8", ".mpd")

    fun isDirectMediaUrl(url: String?): Boolean {
        if (url.isNullOrBlank()) return false
        if (isBlockedViewerPage(url)) return false
        return try {
            val uri = URI(url.trim())
            uri.scheme?.lowercase() in allowedSchemes &&
                !uri.host.isNullOrBlank() &&
                hasAllowedMediaExtension(uri)
        } catch (_: Exception) {
            false
        }
    }

    fun hasAllowedMediaExtension(uri: URI): Boolean {
        val path = uri.path?.lowercase()?.trimEnd('/') ?: return false
        return allowedExtensions.any { path.endsWith(it) }
    }

    fun isBlockedViewerPage(url: String): Boolean {
        val lower = url.lowercase()
        return lower.contains("drive.google.com") && lower.contains("/view") ||
            lower.contains("docs.google.com") ||
            lower.contains("youtube.com/watch") ||
            lower.contains("youtube.com/shorts") ||
            lower.contains("youtu.be/") && !lower.contains("embed") ||
            lower.contains("dropbox.com/s/") && !lower.contains("dl=1")
    }
}
