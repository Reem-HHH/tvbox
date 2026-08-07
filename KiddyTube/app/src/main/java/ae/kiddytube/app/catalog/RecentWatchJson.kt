package ae.kiddytube.app.catalog

/**
 * Small JSON codec for [RecentWatchItem] lists (DataStore persistence + unit tests).
 */
object RecentWatchJson {
    fun encode(items: List<RecentWatchItem>): String = buildString {
        append('[')
        items.forEachIndexed { index, item ->
            if (index > 0) append(',')
            append('{')
            appendJsonString("videoId", item.videoId)
            append(',')
            appendJsonString("channelId", item.channelId)
            append(',')
            appendJsonString("title", item.title)
            append(',')
            appendJsonString("thumbnailUrl", item.thumbnailUrl)
            append(',')
            appendJsonString("youtubeVideoId", item.youtubeVideoId)
            append(',')
            appendJsonString("directUrl", item.directUrl)
            append(',')
            append("\"watchedAtMs\":").append(item.watchedAtMs)
            append('}')
        }
        append(']')
    }

    fun decodeOrNull(json: String): List<RecentWatchItem>? {
        return try {
            parseArray(json)
        } catch (_: Exception) {
            null
        }
    }

    fun decode(json: String): List<RecentWatchItem> =
        decodeOrNull(json).orEmpty()

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
                else -> if (ch.code < 0x20) {
                    append("\\u").append("%04x".format(ch.code))
                } else {
                    append(ch)
                }
            }
        }
    }

    private fun parseArray(json: String): List<RecentWatchItem> {
        val trimmed = json.trim()
        if (trimmed.isEmpty()) return emptyList()
        require(trimmed.startsWith("[") && trimmed.endsWith("]"))
        val body = trimmed.substring(1, trimmed.length - 1).trim()
        if (body.isEmpty()) return emptyList()
        return splitTopLevelObjects(body).map { parseObject(it) }
    }

    private fun splitTopLevelObjects(body: String): List<String> {
        val out = mutableListOf<String>()
        var depth = 0
        var inString = false
        var escape = false
        var start = -1
        for (i in body.indices) {
            val ch = body[i]
            if (inString) {
                when {
                    escape -> escape = false
                    ch == '\\' -> escape = true
                    ch == '"' -> inString = false
                }
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
                        out += body.substring(start, i + 1)
                        start = -1
                    }
                }
            }
        }
        return out
    }

    private fun parseObject(raw: String): RecentWatchItem {
        val fields = parseFields(raw)
        return RecentWatchItem(
            videoId = fields["videoId"].orEmpty(),
            channelId = fields["channelId"].orEmpty(),
            title = fields["title"].orEmpty(),
            thumbnailUrl = fields["thumbnailUrl"],
            youtubeVideoId = fields["youtubeVideoId"],
            directUrl = fields["directUrl"],
            watchedAtMs = fields["watchedAtMs"]?.toLongOrNull() ?: 0L
        )
    }

    private fun parseFields(raw: String): Map<String, String?> {
        val body = raw.trim().removePrefix("{").removeSuffix("}").trim()
        if (body.isEmpty()) return emptyMap()
        val map = linkedMapOf<String, String?>()
        var i = 0
        fun skipWs() {
            while (i < body.length && body[i].isWhitespace()) i++
        }
        fun readString(): String {
            require(body[i] == '"')
            i++
            val sb = StringBuilder()
            while (i < body.length) {
                val ch = body[i++]
                when (ch) {
                    '\\' -> {
                        require(i < body.length)
                        when (val esc = body[i++]) {
                            '"', '\\', '/' -> sb.append(esc)
                            'n' -> sb.append('\n')
                            'r' -> sb.append('\r')
                            't' -> sb.append('\t')
                            'u' -> {
                                require(i + 4 <= body.length)
                                sb.append(body.substring(i, i + 4).toInt(16).toChar())
                                i += 4
                            }
                            else -> sb.append(esc)
                        }
                    }
                    '"' -> return sb.toString()
                    else -> sb.append(ch)
                }
            }
            error("Unterminated string")
        }
        while (i < body.length) {
            skipWs()
            if (i >= body.length) break
            val key = readString()
            skipWs()
            require(body[i] == ':')
            i++
            skipWs()
            val value: String? = when {
                body.startsWith("null", i) -> {
                    i += 4
                    null
                }
                body[i] == '"' -> readString()
                else -> {
                    val start = i
                    while (i < body.length && body[i] != ',' && body[i] != '}') i++
                    body.substring(start, i).trim()
                }
            }
            map[key] = value
            skipWs()
            if (i < body.length && body[i] == ',') i++
        }
        return map
    }
}
