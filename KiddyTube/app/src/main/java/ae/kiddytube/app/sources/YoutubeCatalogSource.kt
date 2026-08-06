package ae.kiddytube.app.sources

import ae.kiddytube.app.catalog.VideoItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class YoutubeCatalogSource {
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
                    items.add(
                        VideoItem(
                            id = videoId,
                            title = title,
                            thumbnailUrl = thumb,
                            youtubeVideoId = videoId
                        )
                    )
                }
                pageToken = root.optString("nextPageToken").ifBlank { null }
                if (pageToken == null) break
            }
            if (pagesFetched == 0) {
                Result.failure(IOException("No playlist response"))
            } else {
                Result.success(items)
            }
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
        }
        return try {
            val code = conn.responseCode
            if (code !in 200..299) {
                val err = conn.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                return Result.failure(IOException("HTTP $code ${err.take(200)}"))
            }
            Result.success(conn.inputStream.bufferedReader().use { it.readText() })
        } catch (e: Exception) {
            Result.failure(e)
        } finally {
            conn.disconnect()
        }
    }
}
