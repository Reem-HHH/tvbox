package ae.kidstv.launcher.player

import android.annotation.SuppressLint
import android.graphics.Color
import android.media.AudioManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import ae.kidstv.launcher.R
import ae.kidstv.launcher.launcher.ImmersiveMode
import ae.kidstv.launcher.parent.ParentPinManager
import ae.kidstv.launcher.remote.RemoteAction
import ae.kidstv.launcher.remote.RemoteKeyHandler
import ae.kidstv.launcher.sources.MediaUrlValidator

@UnstableApi
class PlayerActivity : AppCompatActivity() {
    private lateinit var container: FrameLayout
    private lateinit var titleOverlay: TextView
    private lateinit var remote: RemoteKeyHandler
    private var player: ExoPlayer? = null
    private var webView: WebView? = null
    private val handler = Handler(Looper.getMainLooper())
    private val seekMs = 10_000L

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_player)
        container = findViewById(R.id.playerContainer)
        titleOverlay = findViewById(R.id.titleOverlay)
        remote = RemoteKeyHandler(
            ParentPinManager(),
            getSystemService(AUDIO_SERVICE) as AudioManager
        )
        ImmersiveMode.apply(this)

        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val youtubeId = intent.getStringExtra(EXTRA_YOUTUBE_ID)
        val directUrl = intent.getStringExtra(EXTRA_DIRECT_URL)

        if (!title.isNullOrBlank()) {
            titleOverlay.text = title
            titleOverlay.visibility = View.VISIBLE
            handler.postDelayed({ titleOverlay.visibility = View.GONE }, 3_000)
        }

        when {
            !youtubeId.isNullOrBlank() -> playYoutube(youtubeId)
            MediaUrlValidator.isDirectMediaUrl(directUrl) -> playDirect(directUrl!!)
            else -> finish()
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun playYoutube(videoId: String) {
        val wv = WebView(this).apply {
            setBackgroundColor(Color.BLACK)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.cacheMode = WebSettings.LOAD_DEFAULT
            setOnTouchListener { _, _ -> true }
            webChromeClient = WebChromeClient()
            webViewClient = WebViewClient()
        }
        webView = wv
        container.addView(
            wv,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        val html = """
            <!doctype html><html><head>
            <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"/>
            <style>html,body,#p{margin:0;padding:0;width:100%;height:100%;background:#000;overflow:hidden}
            iframe{pointer-events:none}</style></head><body>
            <div id="p"></div>
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
              var player;
              function onYouTubeIframeAPIReady(){
                player=new YT.Player('p',{
                  width:'100%',height:'100%',
                  videoId:'$videoId',
                  playerVars:{autoplay:1,controls:0,disablekb:1,fs:0,iv_load_policy:3,
                    modestbranding:1,rel:0,playsinline:1,origin:location.origin},
                  events:{onReady:function(e){e.target.playVideo();}}
                });
              }
              function ensurePlaying(){if(player&&player.playVideo)player.playVideo();}
              function toggle(){if(!player)return;var s=player.getPlayerState();
                if(s===1)player.pauseVideo();else player.playVideo();}
            </script></body></html>
        """.trimIndent()
        wv.loadDataWithBaseURL(
            "https://appassets.androidplatform.net",
            html,
            "text/html",
            "UTF-8",
            null
        )
    }

    private fun playDirect(url: String) {
        val view = PlayerView(this).apply {
            setBackgroundColor(Color.BLACK)
            useController = false
            setOnTouchListener { _, _ -> true }
        }
        val exo = ExoPlayer.Builder(this).build()
        player = exo
        view.player = exo
        container.addView(
            view,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        exo.setMediaItem(MediaItem.fromUri(Uri.parse(url)))
        exo.prepare()
        exo.playWhenReady = true
        exo.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == Player.STATE_ENDED) finish()
            }
        })
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_UP && event.keyCode == KeyEvent.KEYCODE_BACK) {
            finish()
            return true
        }
        if (event.action != KeyEvent.ACTION_DOWN) return super.dispatchKeyEvent(event)
        val action = remote.handleKeyDown(event.keyCode, event) ?: return super.dispatchKeyEvent(event)
        return when (action) {
            RemoteAction.NavigateBack, RemoteAction.Consume -> {
                if (event.keyCode == KeyEvent.KEYCODE_BACK) {
                    finish(); true
                } else true
            }
            RemoteAction.EnsurePlaying -> {
                player?.playWhenReady = true
                webView?.evaluateJavascript("ensurePlaying()", null)
                true
            }
            RemoteAction.TogglePlayPause -> {
                player?.let { it.playWhenReady = !it.isPlaying }
                webView?.evaluateJavascript("toggle()", null)
                true
            }
            RemoteAction.SeekForward -> {
                player?.let { it.seekTo(it.currentPosition + seekMs) }
                true
            }
            RemoteAction.SeekBack -> {
                player?.let { it.seekTo((it.currentPosition - seekMs).coerceAtLeast(0)) }
                true
            }
            RemoteAction.VolumeUp, RemoteAction.VolumeDown -> true
            else -> true
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        player?.release()
        player = null
        webView?.apply {
            loadUrl("about:blank")
            stopLoading()
            destroy()
        }
        webView = null
        super.onDestroy()
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_YOUTUBE_ID = "youtube_id"
        const val EXTRA_DIRECT_URL = "direct_url"
    }
}
