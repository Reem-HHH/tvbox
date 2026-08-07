package ae.kiddytube.app.tv

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.provider.BaseColumns
import androidx.tvprovider.media.tv.PreviewChannelHelper
import androidx.tvprovider.media.tv.TvContractCompat
import androidx.tvprovider.media.tv.WatchNextProgram
import ae.kiddytube.app.catalog.RecentWatchItem
import ae.kiddytube.app.diagnostics.DiagnosticsLogger
import ae.kiddytube.app.player.PlayerActivity
import java.net.URLEncoder

/**
 * Publishes continue-watching items to the Android TV / Google TV Watch Next row.
 * No-ops below API 26 and on non-TV devices. Google TV may require partner certification
 * before the Continue watching row surfaces publicly.
 */
class WatchNextPublisher(context: Context) {
    private val appContext = context.applicationContext

    fun upsert(item: RecentWatchItem) {
        if (!isSupported()) return
        if (item.videoId.isBlank() || item.title.isBlank()) return
        try {
            val program = buildProgram(item)
            val existingId = findProgramId(item.videoId)
            val helper = PreviewChannelHelper(appContext)
            if (existingId != null) {
                helper.updateWatchNextProgram(program, existingId)
            } else {
                helper.publishWatchNextProgram(program)
            }
        } catch (e: Exception) {
            DiagnosticsLogger.get(appContext).log(
                "watch_next_upsert_failed",
                "videoId=${item.videoId} err=${e.javaClass.simpleName}:${e.message?.take(120)}"
            )
        }
    }

    fun remove(videoId: String) {
        if (!isSupported() || videoId.isBlank()) return
        try {
            val id = findProgramId(videoId) ?: return
            appContext.contentResolver.delete(
                TvContractCompat.buildWatchNextProgramUri(id),
                null,
                null
            )
        } catch (e: Exception) {
            DiagnosticsLogger.get(appContext).log(
                "watch_next_remove_failed",
                "videoId=$videoId err=${e.javaClass.simpleName}:${e.message?.take(120)}"
            )
        }
    }

    fun clearAll() {
        if (!isSupported()) return
        try {
            val ids = allOurProgramIds()
            for (id in ids) {
                appContext.contentResolver.delete(
                    TvContractCompat.buildWatchNextProgramUri(id),
                    null,
                    null
                )
            }
        } catch (e: Exception) {
            DiagnosticsLogger.get(appContext).log(
                "watch_next_clear_failed",
                "err=${e.javaClass.simpleName}:${e.message?.take(120)}"
            )
        }
    }

    private fun buildProgram(item: RecentWatchItem): WatchNextProgram {
        val builder = WatchNextProgram.Builder()
            .setType(TvContractCompat.WatchNextPrograms.TYPE_MOVIE)
            .setWatchNextType(TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_CONTINUE)
            .setTitle(item.title)
            .setInternalProviderId(item.videoId)
            .setLastEngagementTimeUtcMillis(item.watchedAtMs.coerceAtLeast(1L))
            .setIntentUri(launchIntentUri(item))
        val poster = item.thumbnailUrl?.takeIf { it.isNotBlank() }
        if (poster != null) {
            builder.setPosterArtUri(Uri.parse(poster))
        }
        return builder.build()
    }

    private fun findProgramId(internalId: String): Long? {
        val projection = arrayOf(
            BaseColumns._ID,
            TvContractCompat.WatchNextPrograms.COLUMN_INTERNAL_PROVIDER_ID
        )
        appContext.contentResolver.query(
            TvContractCompat.WatchNextPrograms.CONTENT_URI,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(BaseColumns._ID)
            val keyCol = cursor.getColumnIndexOrThrow(
                TvContractCompat.WatchNextPrograms.COLUMN_INTERNAL_PROVIDER_ID
            )
            while (cursor.moveToNext()) {
                if (cursor.getString(keyCol) == internalId) {
                    return cursor.getLong(idCol)
                }
            }
        }
        return null
    }

    private fun allOurProgramIds(): List<Long> {
        val out = mutableListOf<Long>()
        val projection = arrayOf(BaseColumns._ID)
        appContext.contentResolver.query(
            TvContractCompat.WatchNextPrograms.CONTENT_URI,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(BaseColumns._ID)
            while (cursor.moveToNext()) {
                out += cursor.getLong(idCol)
            }
        }
        return out
    }

    private fun isSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val uiMode = appContext.resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        return uiMode == Configuration.UI_MODE_TYPE_TELEVISION
    }

    private fun launchIntentUri(item: RecentWatchItem): Uri {
        val intent = Intent(appContext, PlayerActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = playUri(item)
            putExtra(PlayerActivity.EXTRA_TITLE, item.title)
            putExtra(PlayerActivity.EXTRA_CHANNEL_ID, item.channelId)
            putExtra(PlayerActivity.EXTRA_VIDEO_ID, item.videoId)
            item.youtubeVideoId?.takeIf { it.isNotBlank() }?.let {
                putExtra(PlayerActivity.EXTRA_YOUTUBE_ID, it)
            }
            item.directUrl?.takeIf { it.isNotBlank() }?.let {
                putExtra(PlayerActivity.EXTRA_DIRECT_URL, it)
            }
        }
        return Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
    }

    companion object {
        const val PLAY_SCHEME = "kiddytube"
        const val PLAY_HOST = "play"

        fun playUri(item: RecentWatchItem): Uri = Uri.parse(buildPlayUriString(item))

        fun buildPlayUriString(item: RecentWatchItem): String {
            fun enc(value: String): String = URLEncoder.encode(value, Charsets.UTF_8.name())
            val qb = StringBuilder("$PLAY_SCHEME://$PLAY_HOST?")
            qb.append("channelId=").append(enc(item.channelId))
            qb.append("&videoId=").append(enc(item.videoId))
            qb.append("&title=").append(enc(item.title))
            item.youtubeVideoId?.takeIf { it.isNotBlank() }?.let {
                qb.append("&youtubeId=").append(enc(it))
            }
            item.directUrl?.takeIf { it.isNotBlank() }?.let {
                qb.append("&directUrl=").append(enc(it))
            }
            return qb.toString()
        }

        /** True when [uri] is a KiddyTube Watch Next deep link. */
        fun isPlayUri(uri: Uri?): Boolean =
            uri != null && uri.scheme == PLAY_SCHEME && uri.host == PLAY_HOST
    }
}
