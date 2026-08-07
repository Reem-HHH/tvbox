package ae.kiddytube.app.player

import android.annotation.SuppressLint
import android.graphics.Color
import android.media.AudioManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.parent.ParentPinManager
import ae.kiddytube.app.parent.ParentUnlockCoordinator
import ae.kiddytube.app.remote.RemoteAction
import ae.kiddytube.app.remote.RemoteKeyHandler
import ae.kiddytube.app.sources.MediaUrlValidator
import ae.kiddytube.app.sources.YoutubeUrlParser
import ae.kiddytube.app.catalog.RecentWatchItem
import kotlinx.coroutines.launch

@UnstableApi
class PlayerActivity : AppCompatActivity() {
    private lateinit var container: FrameLayout
    private lateinit var titleOverlay: TextView
    private lateinit var seekFeedback: TextView
    private lateinit var pinManager: ParentPinManager
    private lateinit var parentUnlock: ParentUnlockCoordinator
    private lateinit var remote: RemoteKeyHandler
    private var player: ExoPlayer? = null
    private var webView: WebView? = null
    private var playbackReady = false
    private var allowSeek = true
    private val handler = Handler(Looper.getMainLooper())
    private val seekMs = 10_000L
    private val hideSeekFeedback = Runnable {
        if (::seekFeedback.isInitialized) {
            seekFeedback.visibility = View.GONE
        }
    }
    private val hideTitleOverlay = Runnable {
        if (::titleOverlay.isInitialized) {
            titleOverlay.visibility = View.GONE
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_player)
        container = findViewById(R.id.playerContainer)
        titleOverlay = findViewById(R.id.titleOverlay)
        seekFeedback = findViewById(R.id.seekFeedback)
        findViewById<TextView>(R.id.navBack).setOnClickListener { finish() }
        pinManager = ParentPinManager()
        parentUnlock = ParentUnlockCoordinator(this, pinManager)
        remote = RemoteKeyHandler(
            pinManager,
            getSystemService(AUDIO_SERVICE) as AudioManager,
            consumeBack = true
        )
        ImmersiveMode.apply(this, forceImmersive = true)
        allowSeek = intent.getBooleanExtra(EXTRA_ALLOW_SEEK, true)

        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    // Soft / gesture / predictive Back — TV long-press unlock still uses KeyEvent.
                    finish()
                }
            }
        )

        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val youtubeId = intent.getStringExtra(EXTRA_YOUTUBE_ID)
        val directUrl = intent.getStringExtra(EXTRA_DIRECT_URL)

        if (title.isNotBlank()) {
            titleOverlay.text = title
            titleOverlay.visibility = View.VISIBLE
            handler.postDelayed(hideTitleOverlay, 3_000)
        }

        // Edge masks cover YouTube watermark / chrome that sits over the iframe edges.
        addBrandMasks()

        // Transparent touch layer: play/pause without opening YouTube chrome
        val tapLayer = View(this).apply {
            isClickable = true
            isFocusable = false
            setOnClickListener { togglePlayback() }
        }
        container.addView(
            tapLayer,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        lifecycleScope.launch {
            val settings = (application as KiddyTubeApp).catalogRepository.current()
            pinManager = ParentPinManager(settings.failCount, settings.lockedUntilMs)
            parentUnlock.updatePinManager(pinManager)
            remote = RemoteKeyHandler(
                pinManager,
                getSystemService(AUDIO_SERVICE) as AudioManager,
                consumeBack = true
            )

            when {
                !youtubeId.isNullOrBlank() -> {
                    if (!YoutubeUrlParser.isValidVideoId(youtubeId)) {
                        rejectPlayback()
                        return@launch
                    }
                    val allowed = (application as KiddyTubeApp).catalogRepository
                        .containsYoutubeVideoId(youtubeId)
                    if (!allowed) {
                        rejectPlayback()
                        return@launch
                    }
                    playYoutube(youtubeId.trim())
                    playbackReady = true
                    recordContinueWatching()
                }
                MediaUrlValidator.isDirectMediaUrl(directUrl) -> {
                    val url = directUrl!!.trim()
                    val allowed = (application as KiddyTubeApp).catalogRepository
                        .containsDirectUrl(url)
                    if (!allowed) {
                        rejectPlayback()
                        return@launch
                    }
                    playDirect(url)
                    playbackReady = true
                    recordContinueWatching()
                }
                else -> rejectPlayback()
            }
        }
    }

    private fun addBrandMasks() {
        fun dp(v: Float): Int = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            v,
            resources.displayMetrics
        ).toInt()

        // Physical RIGHT — YouTube chrome is always LTR, even in RTL locales.
        // Keep masks thin so they cover watermark chips without eating the frame.
        container.addView(
            View(this).apply { setBackgroundColor(Color.BLACK) },
            FrameLayout.LayoutParams(dp(96f), dp(40f), Gravity.BOTTOM or Gravity.RIGHT)
        )
        container.addView(
            View(this).apply { setBackgroundColor(Color.BLACK) },
            FrameLayout.LayoutParams(dp(88f), dp(36f), Gravity.TOP or Gravity.RIGHT)
        )
        container.addView(
            View(this).apply { setBackgroundColor(Color.BLACK) },
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(16f),
                Gravity.BOTTOM
            )
        )
    }

    private fun rejectPlayback() {
        Toast.makeText(this, R.string.player_blocked, Toast.LENGTH_SHORT).show()
        finish()
    }

    private suspend fun recordContinueWatching() {
        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID).orEmpty()
        val videoId = intent.getStringExtra(EXTRA_VIDEO_ID).orEmpty()
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val youtubeId = intent.getStringExtra(EXTRA_YOUTUBE_ID)?.trim()
        val directUrl = intent.getStringExtra(EXTRA_DIRECT_URL)?.trim()
        val resolvedId = when {
            videoId.isNotBlank() -> videoId
            !youtubeId.isNullOrBlank() -> youtubeId
            !directUrl.isNullOrBlank() -> directUrl
            else -> return
        }
        if (channelId.isBlank()) return
        (application as KiddyTubeApp).recentWatchStore.record(
            RecentWatchItem(
                videoId = resolvedId,
                channelId = channelId,
                title = title.ifBlank { resolvedId },
                thumbnailUrl = youtubeId?.let { YoutubeUrlParser.defaultThumbnail(it) },
                youtubeVideoId = youtubeId?.ifBlank { null },
                directUrl = directUrl?.ifBlank { null },
                watchedAtMs = System.currentTimeMillis()
            )
        )
    }

    private fun togglePlayback() {
        player?.let { it.playWhenReady = !it.isPlaying }
        webView?.evaluateJavascript("toggle()", null)
        if (titleOverlay.text.isNotBlank()) {
            titleOverlay.visibility = View.VISIBLE
            handler.removeCallbacks(hideTitleOverlay)
            handler.postDelayed(hideTitleOverlay, 2_000)
        }
    }

    private fun seekBy(deltaMs: Long) {
        if (!allowSeek) {
            showSeekFeedback(getString(R.string.player_seek_disabled))
            return
        }
        player?.let {
            val next = (it.currentPosition + deltaMs).coerceAtLeast(0L)
            it.seekTo(next)
        }
        val deltaSec = deltaMs / 1000.0
        webView?.evaluateJavascript("seekBy($deltaSec)", null)
        val seconds = kotlin.math.abs(deltaMs / 1000L).toInt()
        val label = if (deltaMs >= 0) {
            getString(R.string.player_seek_forward, seconds)
        } else {
            getString(R.string.player_seek_back, seconds)
        }
        showSeekFeedback(label)
    }

    private fun showSeekFeedback(message: String) {
        seekFeedback.text = message
        seekFeedback.visibility = View.VISIBLE
        handler.removeCallbacks(hideSeekFeedback)
        handler.postDelayed(hideSeekFeedback, 1_200)
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun playYoutube(videoId: String) {
        val safeId = videoId.replace("\\", "\\\\").replace("'", "\\'")
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
            addJavascriptInterface(
                object {
                    @JavascriptInterface
                    fun onEnded() {
                        runOnUiThread { finish() }
                    }
                },
                "KiddyNative"
            )
        }
        webView = wv
        container.addView(
            wv,
            0,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        val html = """
            <!doctype html><html><head>
            <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"/>
            <style>
              html,body,#p{margin:0;padding:0;width:100%;height:100%;background:#000;overflow:hidden}
              iframe{pointer-events:none;border:0}
            </style></head><body>
            <div id="p"></div>
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
              var player;
              function onYouTubeIframeAPIReady(){
                player=new YT.Player('p',{
                  width:'100%',height:'100%',
                  videoId:'$safeId',
                  host:'https://www.youtube-nocookie.com',
                  playerVars:{
                    autoplay:1,controls:0,disablekb:1,fs:0,iv_load_policy:3,
                    modestbranding:1,rel:0,playsinline:1,cc_load_policy:0,
                    showinfo:0,origin:location.origin
                  },
                  events:{
                    onReady:function(e){e.target.playVideo();},
                    onStateChange:function(e){
                      if(e.data===0 && window.KiddyNative) KiddyNative.onEnded();
                    }
                  }
                });
              }
              function ensurePlaying(){if(player&&player.playVideo)player.playVideo();}
              function pausePlayback(){if(player&&player.pauseVideo)player.pauseVideo();}
              function toggle(){if(!player)return;var s=player.getPlayerState();
                if(s===1)player.pauseVideo();else player.playVideo();}
              function seekBy(deltaSec){
                if(!player||!player.getCurrentTime||!player.seekTo)return;
                var t=player.getCurrentTime()+deltaSec;
                if(t<0)t=0;
                player.seekTo(t,true);
                player.playVideo();
              }
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
            0,
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
        if (event.action == KeyEvent.ACTION_UP) {
            if (remote.handleKeyUp(event.keyCode) is RemoteAction.ParentTriggered) {
                parentUnlock.beginParentAccess()
                return true
            }
            if (event.keyCode == KeyEvent.KEYCODE_BACK) {
                finish()
                return true
            }
        }
        if (event.action != KeyEvent.ACTION_DOWN) return super.dispatchKeyEvent(event)
        val action = remote.handleKeyDown(event.keyCode, event) ?: return super.dispatchKeyEvent(event)
        return when (action) {
            RemoteAction.ParentTriggered -> {
                parentUnlock.beginParentAccess()
                true
            }
            RemoteAction.NavigateBack, RemoteAction.Consume -> true
            RemoteAction.EnsurePlaying -> {
                player?.playWhenReady = true
                webView?.evaluateJavascript("ensurePlaying()", null)
                true
            }
            RemoteAction.TogglePlayPause -> {
                togglePlayback()
                true
            }
            // In the player, D-pad L/R and media next/prev seek instead of changing items.
            RemoteAction.SeekForward, RemoteAction.NextItem -> {
                seekBy(seekMs)
                true
            }
            RemoteAction.SeekBack, RemoteAction.PreviousItem -> {
                seekBy(-seekMs)
                true
            }
            RemoteAction.VolumeUp, RemoteAction.VolumeDown -> true
        }
    }

    override fun onPause() {
        player?.playWhenReady = false
        webView?.evaluateJavascript("pausePlayback()", null)
        webView?.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        ImmersiveMode.apply(this, forceImmersive = true)
        webView?.onResume()
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
        const val EXTRA_ALLOW_SEEK = "allow_seek"
        const val EXTRA_CHANNEL_ID = "channel_id"
        const val EXTRA_VIDEO_ID = "video_id"
    }
}
