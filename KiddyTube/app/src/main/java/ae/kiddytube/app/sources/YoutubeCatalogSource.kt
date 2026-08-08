package ae.kiddytube.app.sources

import android.content.Context
import ae.kiddytube.app.catalog.VideoItem
import ae.kiddytube.app.catalog.newestFirst
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class YoutubeCatalogSource(
    context: Context? = null
) {
    private val appContext = context?.applicationContext
    @Volatile private var cachedCertSha1: String? = null

    suspend fun fetchPlaylistVideos(
        apiKey: String,
        playlistId: String,
        maxResults: Int = 50
    ): Result<List<VideoItem>> = withContext(Dispatchers.IO) {
        try {
            val items = mutableListOf<VideoItem>()
            var pageToken: String? = null
            var pagesFetched = 0
            while (items.size < maxResults) {
                val url = buildString {
                    append("https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails")
                    append("&playlistId=").append(URLEncoder.encode(playlistId, "UTF-8"))
                    append("&maxResults=").append(minOf(50, maxResults - items.size))
                    append("&key=").append(URLEncoder.encode(apiKey, "UTF-8"))
                    if (pageToken != null) append("&pageToken=").append(pageToken)
                }
                val json = getJson(url).getOrElse { return@withContext Result.failure(it) }
                pagesFetched++
                val root = JSONObject(json)
                if (root.has("error")) {
                    val message = root.optJSONObject("error")?.optString("message") ?: "YouTube API error"
                    return@withContext Result.failure(IOException(message))
                }
                val arr = root.optJSONArray("items")
                    ?: return@withContext Result.failure(IOException("Missing playlist items"))
                for (i in 0 until arr.length()) {
                    val item = arr.getJSONObject(i)
                    val snippet = item.optJSONObject("snippet") ?: continue
                    val content = item.optJSONObject("contentDetails")
                    val videoId = content?.optString("videoId")?.takeIf { it.isNotBlank() }
                        ?: snippet.optJSONObject("resourceId")?.optString("videoId")
                    if (videoId.isNullOrBlank()) continue
                    val title = snippet.optString("title", "Video")
                    if (title.equals("Private video", true) || title.equals("Deleted video", true)) continue
                    val thumbs = snippet.optJSONObject("thumbnails")
                    val thumb = thumbs?.optJSONObject("medium")?.optString("url")
                        ?: thumbs?.optJSONObject("default")?.optString("url")
                    val published = content?.optString("videoPublishedAt")?.takeIf { it.isNotBlank() }
                        ?: snippet.optString("publishedAt").takeIf { it.isNotBlank() }
                    items.add(
                        VideoItem(
                            id = videoId,
                            title = title,
                            thumbnailUrl = thumb,
                            youtubeVideoId = videoId,
                            publishedAtMs = parseIso8601ToMillis(published)
                        )
                    )
                }
                pageToken = root.optString("nextPageToken").ifBlank { null }
                if (pageToken == null) break
            }
            if (pagesFetched == 0) {
                Result.failure(IOException("No playlist response"))
            } else {
                Result.success(items.newestFirst())
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Fetch snippet metadata (title, publish date, thumbnail) for video IDs.
     * YouTube allows up to 50 ids per request.
     */
    suspend fun fetchVideoDetails(
        apiKey: String,
        videoIds: List<String>
    ): Result<List<VideoItem>> = withContext(Dispatchers.IO) {
        try {
            if (videoIds.isEmpty()) return@withContext Result.success(emptyList())
            val out = mutableListOf<VideoItem>()
            for (chunk in videoIds.distinct().chunked(50)) {
                val url = buildString {
                    append("https://www.googleapis.com/youtube/v3/videos?part=snippet")
                    append("&id=").append(URLEncoder.encode(chunk.joinToString(","), "UTF-8"))
                    append("&key=").append(URLEncoder.encode(apiKey, "UTF-8"))
                }
                val json = getJson(url).getOrElse { return@withContext Result.failure(it) }
                val root = JSONObject(json)
                if (root.has("error")) {
                    val message = root.optJSONObject("error")?.optString("message") ?: "YouTube API error"
                    return@withContext Result.failure(IOException(message))
                }
                val arr = root.optJSONArray("items") ?: continue
                for (i in 0 until arr.length()) {
                    val item = arr.getJSONObject(i)
                    val id = item.optString("id")
                    if (id.isBlank()) continue
                    val snippet = item.optJSONObject("snippet") ?: continue
                    val title = snippet.optString("title", "Video")
                    val thumbs = snippet.optJSONObject("thumbnails")
                    val thumb = thumbs?.optJSONObject("medium")?.optString("url")
                        ?: thumbs?.optJSONObject("default")?.optString("url")
                    val published = snippet.optString("publishedAt").takeIf { it.isNotBlank() }
                    out.add(
                        VideoItem(
                            id = id,
                            title = title,
                            thumbnailUrl = thumb ?: YoutubeUrlParser.defaultThumbnail(id),
                            youtubeVideoId = id,
                            publishedAtMs = parseIso8601ToMillis(published)
                        )
                    )
                }
            }
            Result.success(out.newestFirst())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun videosFromIds(ids: List<String>): List<VideoItem> =
        ids.map { id ->
            VideoItem(
                id = id,
                title = "Video $id",
                thumbnailUrl = "https://img.youtube.com/vi/$id/hqdefault.jpg",
                youtubeVideoId = id
            )
        }

    private fun getJson(urlString: String): Result<String> {
        val conn = (URL(urlString).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15_000
            readTimeout = 15_000
            requestMethod = "GET"
            applyAndroidApiKeyHeaders(this)
        }
        return try {
            val code = conn.responseCode
            if (code !in 200..299) {
                val err = conn.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                return Result.failure(IOException(summarizeHttpError(code, err)))
            }
            Result.success(conn.inputStream.bufferedReader().use { it.readText() })
        } catch (e: Exception) {
            Result.failure(e)
        } finally {
            conn.disconnect()
        }
    }

    private fun applyAndroidApiKeyHeaders(conn: HttpURLConnection) {
        val ctx = appContext ?: return
        conn.setRequestProperty("X-Android-Package", ctx.packageName)
        val cert = cachedCertSha1
            ?: AndroidAppIdentity.signingCertSha1Hex(ctx)?.also { cachedCertSha1 = it }
        if (!cert.isNullOrBlank()) {
            conn.setRequestProperty("X-Android-Cert", cert)
        }
    }

    companion object {
        fun summarizeHttpError(code: Int, body: String): String {
            val trimmed = body.trim()
            if (trimmed.isEmpty()) return "HTTP $code"
            val message = extractGoogleApiMessage(trimmed)
            if (!message.isNullOrEmpty()) {
                return "HTTP $code $message".take(220)
            }
            return "HTTP $code ${trimmed.take(180)}"
        }

        /** JVM-safe (no org.json) extract of Google API error.message. */
        fun extractGoogleApiMessage(body: String): String? {
            val key = "\"message\""
            val keyAt = body.indexOf(key)
            if (keyAt < 0) return null
            var i = keyAt + key.length
            while (i < body.length && body[i].isWhitespace()) i++
            if (i >= body.length || body[i] != ':') return null
            i++
            while (i < body.length && body[i].isWhitespace()) i++
            if (i >= body.length || body[i] != '"') return null
            i++
            val sb = StringBuilder()
            while (i < body.length) {
                val ch = body[i++]
                when (ch) {
                    '\\' -> {
                        if (i >= body.length) break
                        when (val esc = body[i++]) {
                            '"', '\\', '/' -> sb.append(esc)
                            'n' -> sb.append('\n')
                            'r' -> sb.append('\r')
                            't' -> sb.append('\t')
                            else -> sb.append(esc)
                        }
                    }
                    '"' -> return sb.toString().trim().ifEmpty { null }
                    else -> sb.append(ch)
                }
            }
            return null
        }

        fun parseIso8601ToMillis(iso: String?): Long? {
            if (iso.isNullOrBlank()) return null
            val patterns = arrayOf(
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss'Z'"
            )
            for (pattern in patterns) {
                try {
                    val sdf = SimpleDateFormat(pattern, Locale.US)
                    sdf.timeZone = TimeZone.getTimeZone("UTC")
                    return sdf.parse(iso)?.time
                } catch (_: Exception) {
                    // try next pattern
                }
            }
            return null
        }
    }
}
