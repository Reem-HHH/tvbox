package ae.kiddytube.app.player

import android.webkit.JavascriptInterface

/** Named WebView bridge so R8 keeps @JavascriptInterface methods. */
class YoutubePlayerBridge(
    private val onEndedOnMain: () -> Unit
) {
    @JavascriptInterface
    fun onEnded() {
        onEndedOnMain()
    }
}
