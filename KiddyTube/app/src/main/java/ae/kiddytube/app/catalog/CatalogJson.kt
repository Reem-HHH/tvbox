package ae.kiddytube.app.catalog

/**
 * JVM-safe catalog JSON codec for unit tests and DataStore persistence.
 */
object CatalogJson {
    fun encode(channels: List<ContentChannel>): String = buildString {
        append('[')
        channels.forEachIndexed { index, c ->
            if (index > 0) append(',')
            append('{')
            appendJsonString("id", c.id)
            append(',')
            appendJsonString("title", c.title)
            append(',')
            appendJsonString("iconRes", c.iconRes.toString())
            append(',')
            appendJsonString("sourceType", c.sourceType.name)
            append(',')
            append("\"enabled\":").append(c.enabled)
            append(',')
            appendJsonString("youtubePlaylistId", c.youtubePlaylistId)
            append(',')
            append("\"sortOrder\":").append(c.sortOrder)
            append(',')
            append("\"videos\":")
            encodeVideos(c.videos)
            append('}')
        }
        append(']')
    }

    fun decode(json: String): List<ContentChannel> {
        return try {
            parseChannelArray(json)
        } catch (_: Exception) {
            DefaultChannels.seed()
        }
    }

    private fun StringBuilder.encodeVideos(videos: List<VideoItem>) {
        append('[')
        videos.forEachIndexed { index, v ->
            if (index > 0) append(',')
            append('{')
            appendJsonString("id", v.id)
            append(',')
            appendJsonString("title", v.title)
            append(',')
            appendJsonString("thumbnailUrl", v.thumbnailUrl)
            append(',')
            appendJsonString("youtubeVideoId", v.youtubeVideoId)
            append(',')
            appendJsonString("directUrl", v.directUrl)
            append('}')
        }
        append(']')
    }

    private fun StringBuilder.appendJsonString(key: String, value: String?) {
        append('"').append(key).append('"').append(':')
        if (value == null) append("null") else append('"').append(escapeJson(value)).append('"')
    }

    private fun escapeJson(value: String): String = buildString(value.length + 8) {
        for (ch in value) {
            when (ch) {
                '\\' -> append("\\\\")
                '"' -> append("\\\"")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> if (ch.code < 0x20) append("\\u").append("%04x".format(ch.code)) else append(ch)
            }
        }
    }

    private fun parseChannelArray(json: String): List<ContentChannel> {
        val trimmed = json.trim()
        require(trimmed.startsWith("[") && trimmed.endsWith("]"))
        val body = trimmed.substring(1, trimmed.length - 1).trim()
        if (body.isEmpty()) return emptyList()
        return splitTopLevelObjects(body).map { parseChannelObject(it) }
    }

    private fun splitTopLevelObjects(body: String): List<String> {
        val out = ArrayList<String>()
        var depth = 0
        var inString = false
        var escape = false
        var start = -1
        for (i in body.indices) {
            val ch = body[i]
            if (inString) {
                if (escape) escape = false else if (ch == '\\') escape = true else if (ch == '"') inString = false
                continue
            }
            when (ch) {
                '"' -> inString = true
                '{' -> {
                    if (depth == 0) start = i
                    depth++
                }
                '}' -> {
                    depth--
                    if (depth == 0 && start >= 0) {
                        out.add(body.substring(start, i + 1))
                        start = -1
                    }
                }
            }
        }
        return out
    }

    private fun parseChannelObject(raw: String): ContentChannel {
        val fields = parseObjectFields(raw)
        fun str(key: String): String? = fields[key]
        val iconRes = str("iconRes")?.toIntOrNull() ?: 0
        val videosRaw = fields["videos"] ?: "[]"
        return ContentChannel(
            id = str("id") ?: error("id required"),
            title = str("title").orEmpty(),
            iconRes = iconRes,
            sourceType = SourceType.valueOf(str("sourceType") ?: SourceType.YOUTUBE_PLAYLIST.name),
            enabled = fields["enabled"]?.toBooleanStrictOrNull() ?: true,
            youtubePlaylistId = str("youtubePlaylistId")?.ifBlank { null },
            videos = parseVideoArray(videosRaw),
            sortOrder = fields["sortOrder"]?.toIntOrNull() ?: 0
        ).let { decoded ->
            if (decoded.iconRes != 0) decoded
            else DefaultChannels.seed().firstOrNull { it.id == decoded.id }?.let {
                decoded.copy(iconRes = it.iconRes)
            } ?: decoded
        }
    }

    private fun parseVideoArray(raw: String): List<VideoItem> {
        val trimmed = raw.trim()
        if (trimmed == "[]") return emptyList()
        require(trimmed.startsWith("[") && trimmed.endsWith("]"))
        val body = trimmed.substring(1, trimmed.length - 1).trim()
        if (body.isEmpty()) return emptyList()
        return splitTopLevelObjects(body).map { obj ->
            val f = parseObjectFields(obj)
            fun s(k: String) = f[k]
            VideoItem(
                id = s("id") ?: error("video id"),
                title = s("title").orEmpty(),
                thumbnailUrl = s("thumbnailUrl")?.ifBlank { null },
                youtubeVideoId = s("youtubeVideoId")?.ifBlank { null },
                directUrl = s("directUrl")?.ifBlank { null }
            )
        }
    }

    private fun parseObjectFields(raw: String): Map<String, String?> {
        val body = raw.trim().removePrefix("{").removeSuffix("}").trim()
        if (body.isEmpty()) return emptyMap()
        val map = LinkedHashMap<String, String?>()
        var i = 0
        fun skipWs() { while (i < body.length && body[i].isWhitespace()) i++ }
        fun readString(): String {
            require(body[i] == '"')
            i++
            val sb = StringBuilder()
            while (i < body.length) {
                val ch = body[i++]
                if (ch == '\\') {
                    require(i < body.length)
                    when (val esc = body[i++]) {
                        '"', '\\', '/' -> sb.append(esc)
                        'n' -> sb.append('\n')
                        'r' -> sb.append('\r')
                        't' -> sb.append('\t')
                        'u' -> {
                            sb.append(body.substring(i, i + 4).toInt(16).toChar())
                            i += 4
                        }
                        else -> sb.append(esc)
                    }
                } else if (ch == '"') return sb.toString() else sb.append(ch)
            }
            error("Unterminated string")
        }
        fun readValue(): String? {
            skipWs()
            when {
                body.startsWith("null", i) -> { i += 4; return null }
                body[i] == '"' -> return readString()
                body[i] == '[' -> {
                    var depth = 0
                    val start = i
                    while (i < body.length) {
                        when (body[i++]) {
                            '[' -> depth++
                            ']' -> {
                                depth--
                                if (depth == 0) return body.substring(start, i)
                            }
                        }
                    }
                    error("bad array")
                }
                else -> {
                    val start = i
                    while (i < body.length && body[i] != ',' && body[i] != '}') i++
                    return body.substring(start, i).trim()
                }
            }
        }
        while (i < body.length) {
            skipWs()
            if (i >= body.length) break
            val key = readString()
            skipWs()
            require(body[i] == ':')
            i++
            map[key] = readValue()
            skipWs()
            if (i < body.length && body[i] == ',') i++
        }
        return map
    }
}
