package ae.kiddytube.app.ui

import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.widget.ImageButton
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.catalog.VideoItem
import ae.kiddytube.app.catalog.newestFirst
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.parent.ParentPinManager
import ae.kiddytube.app.parent.ParentUnlockCoordinator
import ae.kiddytube.app.player.PlayerActivity
import ae.kiddytube.app.remote.RemoteAction
import ae.kiddytube.app.remote.RemoteKeyHandler
import kotlinx.coroutines.launch

class VideoLibraryActivity : AppCompatActivity() {
    private lateinit var grid: RecyclerView
    private lateinit var emptyMessage: TextView
    private lateinit var brandTitle: TextView
    private lateinit var syncStatus: TextView
    private lateinit var parentSettings: ImageButton
    private lateinit var adapter: VideoGridAdapter
    private lateinit var pinManager: ParentPinManager
    private lateinit var parentUnlock: ParentUnlockCoordinator
    private lateinit var remote: RemoteKeyHandler
    private var channelId: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyPreferredOrientation()
        setContentView(R.layout.activity_grid)
        channelId = intent.getStringExtra(EXTRA_CHANNEL_ID).orEmpty()
        val channelTitle = intent.getStringExtra(EXTRA_CHANNEL_TITLE).orEmpty()

        grid = findViewById(R.id.grid)
        emptyMessage = findViewById(R.id.emptyMessage)
        brandTitle = findViewById(R.id.brandTitle)
        syncStatus = findViewById(R.id.syncStatus)
        parentSettings = findViewById(R.id.parentSettings)
        brandTitle.text = channelTitle.ifBlank { getString(R.string.app_name) }
        syncStatus.visibility = View.GONE
        findViewById<TextView>(R.id.navBack).apply {
            visibility = View.VISIBLE
            setOnClickListener { finish() }
            nextFocusDownId = R.id.grid
        }

        pinManager = ParentPinManager()
        parentUnlock = ParentUnlockCoordinator(this, pinManager)
        // consumeBack=true so short Back is deferred to ACTION_UP (long-press unlock can fire).
        remote = RemoteKeyHandler(
            pinManager,
            getSystemService(AUDIO_SERVICE) as AudioManager,
            consumeBack = true
        )
        parentSettings.setOnClickListener { parentUnlock.beginParentAccess() }

        adapter = VideoGridAdapter { video -> openPlayer(video) }
        grid.adapter = adapter
        grid.layoutManager = GridLayoutManager(this, spanCount())
        grid.clipChildren = false
        grid.clipToPadding = false
        grid.descendantFocusability = android.view.ViewGroup.FOCUS_AFTER_DESCENDANTS
        grid.isFocusable = true
        ImmersiveMode.apply(this)
        lifecycleScope.launch {
            val settings = (application as KiddyTubeApp).catalogRepository.current()
            pinManager = ParentPinManager(settings.failCount, settings.lockedUntilMs)
            parentUnlock.updatePinManager(pinManager)
            remote = RemoteKeyHandler(
                pinManager,
                getSystemService(AUDIO_SERVICE) as AudioManager,
                consumeBack = true
            )
            reload(focusFirst = true)
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val focused = GridFocus.capturePosition(grid)
        reflowSpans()
        GridFocus.restore(grid, focused)
    }

    private fun applyPreferredOrientation() {
        requestedOrientation = if (isTelevision()) {
            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        } else {
            ActivityInfo.SCREEN_ORIENTATION_FULL_USER
        }
    }

    private fun reflowSpans() {
        val spans = spanCount()
        val lm = grid.layoutManager as? GridLayoutManager
        if (lm != null) {
            if (lm.spanCount != spans) lm.spanCount = spans
        } else {
            grid.layoutManager = GridLayoutManager(this, spans)
        }
    }

    private fun isTelevision(): Boolean {
        val uiMode = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        return uiMode == Configuration.UI_MODE_TYPE_TELEVISION
    }

    private fun spanCount(): Int {
        val isTv = isTelevision()
        val widthDp = resources.configuration.screenWidthDp
        return when {
            isTv -> 4
            widthDp >= 900 -> 5
            widthDp >= 600 -> 3
            else -> 2
        }
    }

    private fun reload(focusFirst: Boolean = false) {
        lifecycleScope.launch {
            val channel = (application as KiddyTubeApp).catalogRepository.channelById(channelId)
            val videos = channel?.videos.orEmpty().newestFirst()
            val focused = GridFocus.capturePosition(grid)
            adapter.submit(videos)
            emptyMessage.visibility = if (videos.isEmpty()) View.VISIBLE else View.GONE
            emptyMessage.text = getString(R.string.empty_videos)
            when {
                focused != RecyclerView.NO_POSITION -> GridFocus.restore(grid, focused)
                focusFirst && videos.isNotEmpty() -> GridFocus.requestGridDefault(grid)
            }
        }
    }

    private fun openPlayer(video: VideoItem) {
        startActivity(
            Intent(this, PlayerActivity::class.java)
                .putExtra(PlayerActivity.EXTRA_TITLE, video.title)
                .putExtra(PlayerActivity.EXTRA_YOUTUBE_ID, video.youtubeVideoId)
                .putExtra(PlayerActivity.EXTRA_DIRECT_URL, video.directUrl)
                .putExtra(PlayerActivity.EXTRA_ALLOW_SEEK, video.allowSeek)
                .putExtra(PlayerActivity.EXTRA_CHANNEL_ID, channelId)
                .putExtra(PlayerActivity.EXTRA_VIDEO_ID, video.id)
        )
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
        if (event.action == KeyEvent.ACTION_DOWN) {
            val action = remote.handleKeyDown(event.keyCode, event)
            when (action) {
                RemoteAction.ParentTriggered -> {
                    parentUnlock.beginParentAccess()
                    return true
                }
                RemoteAction.NavigateBack, RemoteAction.Consume,
                RemoteAction.VolumeUp, RemoteAction.VolumeDown -> return true
                else -> Unit
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onResume() {
        super.onResume()
        ImmersiveMode.apply(this)
        reload()
    }

    companion object {
        const val EXTRA_CHANNEL_ID = "channel_id"
        const val EXTRA_CHANNEL_TITLE = "channel_title"
    }
}
