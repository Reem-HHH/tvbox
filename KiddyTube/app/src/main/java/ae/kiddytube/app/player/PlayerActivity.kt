package ae.kiddytube.app.player

import android.annotation.SuppressLint
import android.graphics.Color
import android.media.AudioManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.catalog.RecentWatchItem
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.parent.ParentPinManager
import ae.kiddytube.app.parent.ParentUnlockCoordinator
import ae.kiddytube.app.remote.RemoteAction
import ae.kiddytube.app.remote.RemoteKeyHandler
import ae.kiddytube.app.sources.MediaUrlValidator
import ae.kiddytube.app.sources.YoutubeUrlParser
import ae.kiddytube.app.tv.WatchNextPublisher
import kotlin.math.abs
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
    private val doubleTapMs = 320L
    private var lastTapUptimeMs = 0L
    private var lastTapX = 0f
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
    private val pendingSingleTap = Runnable { togglePlayback() }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_player)
        container = findViewById(R.id.playerContainer)
        titleOverlay = findViewById(R.id.titleOverlay)
        seekFeedback = findViewById(R.id.seekFeedback)
        val navBack = findViewById<TextView>(R.id.navBack)
        navBack.setOnClickListener { finish() }
        // Touch can tap Back; TV focus stays on the player until D-pad Down.
        navBack.isFocusable = false
        navBack.isFocusableInTouchMode = false
        pinManager = ParentPinManager()
        parentUnlock = ParentUnlockCoordinator(this, pinManager)
        remote = RemoteKeyHandler(
            pinManager,
            getSystemService(AUDIO_SERVICE) as AudioManager,
            consumeBack = true
        )
        ImmersiveMode.apply(this, forceImmersive = true)
        applyWatchNextDeepLinkExtras()
        // Deny seek until catalog resolve; never trust intent extras for kid seek policy.
        allowSeek = false

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

        // Transparent touch layer: single tap = play/pause; double-tap L/R = seek
        // (YouTube iframe stays non-clickable via pointer-events + touch intercept).
        val tapLayer = View(this).apply {
            isClickable = true
            isFocusable = false
            setOnTouchListener { v, event ->
                if (event.actionMasked == MotionEvent.ACTION_UP) {
                    handlePlayerTap(v, event.x)
                }
                true
            }
        }
        container.addView(
            tapLayer,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        container.isFocusable = true
        container.isFocusableInTouchMode = true
        container.requestFocus()

        lifecycleScope.launch {
            val app = application as KiddyTubeApp
            try {
                app.awaitCatalogReady()
            } catch (_: Exception) {
                if (isFinishing || isDestroyed) return@launch
                rejectPlayback()
                return@launch
            }
            if (isFinishing || isDestroyed) return@launch
            val settings = app.catalogRepository.current()
            pinManager = ParentPinManager(settings.failCount, settings.lockedUntilMs)
            parentUnlock.updatePinManager(pinManager)
            remote = RemoteKeyHandler(
                pinManager,
                getSystemService(AUDIO_SERVICE) as AudioManager,
                consumeBack = true
            )
            resolveAllowSeekFromCatalog(app)

            val youtubeId = intent.getStringExtra(EXTRA_YOUTUBE_ID)
            val directUrl = intent.getStringExtra(EXTRA_DIRECT_URL)

            if (isFinishing || isDestroyed) return@launch
            when {
                !youtubeId.isNullOrBlank() -> {
                    if (!YoutubeUrlParser.isValidVideoId(youtubeId)) {
                        rejectPlayback()
                        return@launch
                    }
                    val allowed = app.catalogRepository.containsYoutubeVideoId(youtubeId)
                    if (!allowed) {
                        rejectPlayback()
                        return@launch
                    }
                    if (isFinishing || isDestroyed) return@launch
                    playYoutube(youtubeId.trim())
                    playbackReady = true
                    recordContinueWatching()
                }
                MediaUrlValidator.isDirectMediaUrl(directUrl) -> {
                    val url = directUrl!!.trim()
                    val allowed = app.catalogRepository.containsDirectUrl(url)
                    if (!allowed) {
                        rejectPlayback()
                        return@launch
                    }
                    if (isFinishing || isDestroyed) return@launch
                    playDirect(url)
                    playbackReady = true
                    recordContinueWatching()
                }
                else -> rejectPlayback()
            }
        }
    }

    private fun applyWatchNextDeepLinkExtras() {
        val uri = intent?.data ?: return
        if (!WatchNextPublisher.isPlayUri(uri)) return
        fun q(name: String): String? = uri.getQueryParameter(name)?.takeIf { it.isNotBlank() }
        q("title")?.let { intent.putExtra(EXTRA_TITLE, it) }
        q("youtubeId")?.let { intent.putExtra(EXTRA_YOUTUBE_ID, it) }
        q("directUrl")?.let { intent.putExtra(EXTRA_DIRECT_URL, it) }
        q("channelId")?.let { intent.putExtra(EXTRA_CHANNEL_ID, it) }
        q("videoId")?.let { intent.putExtra(EXTRA_VIDEO_ID, it) }
    }

    private suspend fun resolveAllowSeekFromCatalog(app: KiddyTubeApp) {
        val videoId = intent.getStringExtra(EXTRA_VIDEO_ID).orEmpty()
        val youtubeId = intent.getStringExtra(EXTRA_YOUTUBE_ID)?.trim().orEmpty()
        val directUrl = intent.getStringExtra(EXTRA_DIRECT_URL)?.trim().orEmpty()
        val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID).orEmpty()
        val settings = app.catalogRepository.current()
        val channels = if (channelId.isNotBlank()) {
            listOfNotNull(settings.channels.firstOrNull { it.id == channelId }) +
                settings.channels.filter { it.id != channelId }
        } else {
            settings.channels
        }
        val video = channels.asSequence()
            .filter { it.enabled }
            .flatMap { it.videos.asSequence() }
            .firstOrNull { v ->
                (videoId.isNotBlank() && v.id == videoId) ||
                    (youtubeId.isNotBlank() &&
                        (v.youtubeVideoId == youtubeId || v.id == youtubeId)) ||
                    (directUrl.isNotBlank() && v.directUrl?.trim() == directUrl)
            }
        if (video != null) {
            allowSeek = video.allowSeek
            intent.putExtra(EXTRA_ALLOW_SEEK, video.allowSeek)
        }
    }

    private fun rejectPlayback() {
        Toast.makeText(this, R.string.player_blocked, Toast.LENGTH_SHORT).show()
        finish()
    }

    private fun failPlayback() {
        if (isFinishing || isDestroyed) return
        Toast.makeText(this, R.string.player_playback_error, Toast.LENGTH_SHORT).show()
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
        (application as KiddyTubeApp).recordRecentWatch(
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

    private fun handlePlayerTap(view: View, x: Float) {
        val now = SystemClock.uptimeMillis()
        val width = view.width.coerceAtLeast(1).toFloat()
        val isDouble = now - lastTapUptimeMs <= doubleTapMs &&
            abs(x - lastTapX) <= width * 0.35f
        if (isDouble) {
            handler.removeCallbacks(pendingSingleTap)
            lastTapUptimeMs = 0L
            when {
                x < width / 3f -> seekBy(-seekMs)
                x > width * 2f / 3f -> seekBy(seekMs)
                else -> togglePlayback()
            }
            return
        }
        lastTapUptimeMs = now
        lastTapX = x
        handler.removeCallbacks(pendingSingleTap)
        handler.postDelayed(pendingSingleTap, doubleTapMs)
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
            val duration = it.duration
            val next = (it.currentPosition + deltaMs).coerceAtLeast(0L).let { pos ->
                if (duration != C.TIME_UNSET && duration > 0L) {
                    pos.coerceAtMost((duration - 250L).coerceAtLeast(0L))
                } else {
                    pos
                }
            }
            it.seekTo(next)
            it.playWhenReady = true
        }
        val deltaSec = deltaMs / 1000.0
        // Call the page-global helper; harden against not-ready / NaN inside JS.
        webView?.evaluateJavascript("seekBy($deltaSec)", null)
        val seconds = abs(deltaMs / 1000L).toInt()
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
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?
                ): Boolean {
                    val host = request?.url?.host ?: return true
                    return !isAllowedYoutubeHost(host)
                }

                @Deprecated("Deprecated in Java")
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    val host = url?.let { Uri.parse(it).host } ?: return true
                    return !isAllowedYoutubeHost(host)
                }
            }
            addJavascriptInterface(
                YoutubePlayerBridge(
                    onEndedOnMain = { runOnUiThread { finish() } },
                    onErrorOnMain = { runOnUiThread { failPlayback() } }
                ),
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
            <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,viewport-fit=cover"/>
            <style>
              html,body{margin:0;padding:0;width:100%;height:100%;background:#000;overflow:hidden;
                display:flex;align-items:center;justify-content:center}
              #stage{position:relative;background:#000;overflow:hidden}
              #stage iframe{pointer-events:none;border:0;display:block}
            </style></head><body>
            <div id="stage"><div id="p"></div></div>
            <script src="https://www.youtube.com/iframe_api"></script>
            <script>
              var player;
              function stageSize(){
                var w=window.innerWidth||document.documentElement.clientWidth||0;
                var h=window.innerHeight||document.documentElement.clientHeight||0;
                if(w<1||h<1)return {w:640,h:360};
                var tw=Math.min(w,h*16/9), th=Math.min(h,w*9/16);
                return {w:Math.max(1,Math.floor(tw)),h:Math.max(1,Math.floor(th))};
              }
              function applyStageSize(){
                var s=document.getElementById('stage');
                if(!s)return stageSize();
                var sz=stageSize();
                s.style.width=sz.w+'px';
                s.style.height=sz.h+'px';
                if(player&&typeof player.setSize==='function'){
                  try{player.setSize(sz.w,sz.h);}catch(e){}
                }
                return sz;
              }
              window.addEventListener('resize',function(){applyStageSize();});
              function onYouTubeIframeAPIReady(){
                var sz=applyStageSize();
                player=new YT.Player('p',{
                  width:sz.w,height:sz.h,
                  videoId:'$safeId',
                  host:'https://www.youtube-nocookie.com',
                  playerVars:{
                    autoplay:1,controls:0,disablekb:1,fs:0,iv_load_policy:3,
                    modestbranding:1,rel:0,playsinline:1,cc_load_policy:0,
                    showinfo:0,origin:location.origin
                  },
                  events:{
                    onReady:function(e){
                      applyStageSize();
                      e.target.playVideo();
                    },
                    onStateChange:function(e){
                      if(e.data===0 && window.KiddyNative) KiddyNative.onEnded();
                    },
                    onError:function(e){
                      if(window.KiddyNative&&typeof KiddyNative.onError==='function'){
                        KiddyNative.onError((e&&e.data)||0);
                      }
                    }
                  }
                });
              }
              function ensurePlaying(){if(player&&player.playVideo)player.playVideo();}
              function pausePlayback(){if(player&&player.pauseVideo)player.pauseVideo();}
              function toggle(){if(!player)return;var s=player.getPlayerState();
                if(s===1)player.pauseVideo();else player.playVideo();}
              function seekBy(deltaSec){
                if(!player||typeof player.seekTo!=='function')return;
                var cur=0;
                try{
                  if(typeof player.getCurrentTime==='function'){
                    var g=player.getCurrentTime();
                    if(typeof g==='number'&&!isNaN(g))cur=g;
                  }
                }catch(e){}
                var t=cur+(Number(deltaSec)||0);
                if(t<0)t=0;
                try{
                  if(typeof player.getDuration==='function'){
                    var d=player.getDuration();
                    if(typeof d==='number'&&d>0&&t>d-1)t=Math.max(0,d-1);
                  }
                }catch(e){}
                try{
                  player.seekTo(t,true);
                  if(player.playVideo)player.playVideo();
                }catch(e){}
              }
            </script></body></html>
        """.trimIndent()
        // Wait until WebView is laid out so the 16:9 stage matches the visible area.
        wv.post {
            if (webView !== wv) return@post
            wv.loadDataWithBaseURL(
                "https://appassets.androidplatform.net",
                html,
                "text/html",
                "UTF-8",
                null
            )
        }
    }

    private fun playDirect(url: String) {
        val view = PlayerView(this).apply {
            setBackgroundColor(Color.BLACK)
            useController = false
            resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
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

            override fun onPlayerError(error: PlaybackException) {
                failPlayback()
            }
        })
    }

    private fun focusPlayerChromeBack(): Boolean {
        val navBack = findViewById<TextView>(R.id.navBack)
        navBack.isFocusable = true
        return navBack.requestFocus()
    }

    private fun releasePlayerChromeBackFocus() {
        val navBack = findViewById<TextView>(R.id.navBack)
        if (currentFocus?.id == R.id.navBack) {
            navBack.clearFocus()
        }
        navBack.isFocusable = false
        container.requestFocus()
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

        // Down reveals / focuses Back chip; Up from Back returns focus to the player.
        when (event.keyCode) {
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (currentFocus?.id != R.id.navBack) {
                    focusPlayerChromeBack()
                    return true
                }
            }
            KeyEvent.KEYCODE_DPAD_UP -> {
                if (currentFocus?.id == R.id.navBack) {
                    releasePlayerChromeBackFocus()
                    return true
                }
            }
        }

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
                // D-pad OK on the Back chip should exit, not toggle playback.
                if (currentFocus?.id == R.id.navBack) {
                    finish()
                    true
                } else {
                    togglePlayback()
                    true
                }
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

        internal fun isAllowedYoutubeHost(host: String): Boolean {
            val h = host.lowercase()
            return h == "youtube.com" ||
                h == "www.youtube.com" ||
                h == "m.youtube.com" ||
                h == "youtube-nocookie.com" ||
                h == "www.youtube-nocookie.com" ||
                h.endsWith(".youtube.com") ||
                h.endsWith(".youtube-nocookie.com") ||
                h.endsWith(".googlevideo.com") ||
                h == "i.ytimg.com" ||
                h.endsWith(".ytimg.com")
        }
    }
}
