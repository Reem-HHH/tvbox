package ae.kiddytube.app.ui

/**
 * In-process memory of the last focused channel / video so D-pad focus
 * returns to the same tile after Library ↔ Player (and home after library).
 */
object NavFocusMemory {
    @Volatile
    var lastChannelId: String? = null
        private set

    private val lastVideoByChannel = mutableMapOf<String, String>()

    fun rememberChannel(channelId: String) {
        if (channelId.isBlank()) return
        lastChannelId = channelId
    }

    fun rememberVideo(channelId: String, videoId: String) {
        if (channelId.isBlank() || videoId.isBlank()) return
        lastChannelId = channelId
        lastVideoByChannel[channelId] = videoId
    }

    fun lastVideoId(channelId: String): String? =
        lastVideoByChannel[channelId]
}
