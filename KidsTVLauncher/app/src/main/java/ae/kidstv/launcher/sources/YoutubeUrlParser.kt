package ae.kidstv.launcher.sources

import java.util.regex.Pattern

object YoutubeUrlParser {
    private val VIDEO_PATTERNS = listOf(
        Pattern.compile("(?:youtube\\.com/watch\\?.*v=|youtu\\.be/|youtube\\.com/embed/)([\\w-]{11})"),
        Pattern.compile("^([\\w-]{11})$")
    )
    private val PLAYLIST_PATTERN = Pattern.compile(
        "[?&]list=([\\w-]+)|youtube\\.com/playlist\\?list=([\\w-]+)"
    )

    fun extractVideoId(input: String?): String? {
        if (input.isNullOrBlank()) return null
        val trimmed = input.trim()
        for (pattern in VIDEO_PATTERNS) {
            val m = pattern.matcher(trimmed)
            if (m.find()) return m.group(1)
        }
        return null
    }

    fun extractPlaylistId(input: String?): String? {
        if (input.isNullOrBlank()) return null
        val trimmed = input.trim()
        val m = PLAYLIST_PATTERN.matcher(trimmed)
        if (m.find()) {
            return m.group(1) ?: m.group(2)
        }
        // Bare playlist ids (e.g. PLabcdef) — no path/query separators.
        if (trimmed.length in 8..64 && !trimmed.contains("/") && !trimmed.contains("=") &&
            trimmed.matches(Regex("[\\w-]+"))
        ) {
            return trimmed
        }
        return null
    }

    fun defaultThumbnail(videoId: String): String =
        "https://img.youtube.com/vi/$videoId/hqdefault.jpg"

    fun parseVideoIdsCsv(csv: String?): List<String> {
        if (csv.isNullOrBlank()) return emptyList()
        return csv.split(',', ';', '\n', ' ')
            .mapNotNull { extractVideoId(it.trim()) }
            .distinct()
    }
}
