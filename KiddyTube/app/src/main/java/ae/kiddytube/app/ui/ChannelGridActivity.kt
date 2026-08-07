package ae.kiddytube.app.ui

import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.catalog.ApiKeyResolver
import ae.kiddytube.app.catalog.CatalogSettings
import ae.kiddytube.app.catalog.RecentWatchLogic
import ae.kiddytube.app.catalog.SyncStatus
import ae.kiddytube.app.catalog.VideoItem
import ae.kiddytube.app.catalog.RecentWatchItem
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.parent.ParentPinManager
import ae.kiddytube.app.parent.ParentUnlockCoordinator
import ae.kiddytube.app.player.PlayerActivity
import ae.kiddytube.app.remote.RemoteAction
import ae.kiddytube.app.remote.RemoteKeyHandler
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class ChannelGridActivity : AppCompatActivity() {
    private lateinit var grid: RecyclerView
    private lateinit var continueSection: LinearLayout
    private lateinit var continueList: RecyclerView
    private lateinit var emptyMessage: TextView
    private lateinit var brandTitle: TextView
    private lateinit var syncStatus: TextView
    private lateinit var parentSettings: ImageButton
    private lateinit var adapter: ChannelGridAdapter
    private lateinit var continueAdapter: ContinueWatchAdapter
    private lateinit var pinManager: ParentPinManager
    private lateinit var parentUnlock: ParentUnlockCoordinator
    private lateinit var remote: RemoteKeyHandler
    private var settings: CatalogSettings = CatalogSettings()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyPreferredOrientation()
        setContentView(R.layout.activity_grid)
        grid = findViewById(R.id.grid)
        continueSection = findViewById(R.id.continueWatchingSection)
        continueList = findViewById(R.id.continueWatchingList)
        emptyMessage = findViewById(R.id.emptyMessage)
        brandTitle = findViewById(R.id.brandTitle)
        syncStatus = findViewById(R.id.syncStatus)
        parentSettings = findViewById(R.id.parentSettings)
        brandTitle.text = getString(R.string.app_name)

        pinManager = ParentPinManager()
        parentUnlock = ParentUnlockCoordinator(this, pinManager)
        remote = RemoteKeyHandler(
            pinManager,
            getSystemService(AUDIO_SERVICE) as AudioManager,
            consumeBack = true
        )
        parentSettings.setOnClickListener { parentUnlock.beginParentAccess() }

        adapter = ChannelGridAdapter { channel ->
            startActivity(
                Intent(this, VideoLibraryActivity::class.java)
                    .putExtra(VideoLibraryActivity.EXTRA_CHANNEL_ID, channel.id)
                    .putExtra(VideoLibraryActivity.EXTRA_CHANNEL_TITLE, channel.title)
            )
        }
        grid.adapter = adapter
        grid.layoutManager = GridLayoutManager(this, spanCount())
        grid.clipToPadding = false
        grid.clipChildren = false
        grid.descendantFocusability = android.view.ViewGroup.FOCUS_AFTER_DESCENDANTS
        grid.isFocusable = true

        continueAdapter = ContinueWatchAdapter { recent, video -> openContinueWatch(recent, video) }
        continueList.adapter = continueAdapter
        continueList.layoutManager = LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
        continueList.clipToPadding = false
        continueList.clipChildren = false
        continueList.descendantFocusability = android.view.ViewGroup.FOCUS_AFTER_DESCENDANTS
        continueList.isFocusable = true

        ImmersiveMode.apply(this)
        lifecycleScope.launch {
            val app = application as KiddyTubeApp
            // Wait for default PIN + seed upgrade before first paint / launch sync.
            try {
                app.awaitCatalogReady()
            } catch (_: Exception) {
                // Continue with best-effort catalog if bootstrap failed.
            }
            settings = app.catalogRepository.current()
            pinManager = ParentPinManager(settings.failCount, settings.lockedUntilMs)
            parentUnlock.updatePinManager(pinManager)
            remote = RemoteKeyHandler(
                pinManager,
                getSystemService(AUDIO_SERVICE) as AudioManager,
                consumeBack = true
            )
            render(focusFirstIfNeeded = true)
            runLaunchSync()
        }
    }

    private suspend fun runLaunchSync() {
        showSyncChip(getString(R.string.sync_updating))
        val repo = (application as KiddyTubeApp).catalogRepository
        val focused = GridFocus.capturePosition(grid)
        val result = repo.refreshAllPlaylists()
        settings = repo.current()
        render(restoreFocusAt = focused)

        val message = when (result.status) {
            SyncStatus.UPDATED -> getString(R.string.sync_updated)
            SyncStatus.SKIPPED_OFFLINE -> getString(R.string.sync_offline)
            SyncStatus.SKIPPED_NO_KEY -> getString(R.string.sync_no_key)
            SyncStatus.FAILED -> {
                val detail = result.message?.substringAfter(": ")?.trim().orEmpty()
                if (detail.isNotEmpty()) {
                    getString(R.string.sync_failed) + " — " + detail.take(80)
                } else {
                    getString(R.string.sync_failed)
                }
            }
            SyncStatus.SKIPPED_TTL -> {
                val needsFollow = settings.channels.any {
                    it.enabled &&
                        !it.youtubePlaylistId.isNullOrBlank() &&
                        it.videos.isEmpty() &&
                        !it.followUploads
                }
                if (needsFollow) {
                    getString(R.string.sync_enable_follow_uploads)
                } else {
                    result.message?.takeIf { it.contains("Follow uploads", ignoreCase = true) }
                        ?.let { getString(R.string.sync_enable_follow_uploads) }
                        ?: getString(R.string.sync_skipped)
                }
            }
        }
        val stickyNoKey = result.status == SyncStatus.SKIPPED_NO_KEY &&
            settings.channels.any { it.enabled && it.videos.isEmpty() }
        val stickyFollow = result.status == SyncStatus.SKIPPED_TTL &&
            settings.channels.any {
                it.enabled &&
                    !it.youtubePlaylistId.isNullOrBlank() &&
                    it.videos.isEmpty() &&
                    !it.followUploads
            }
        showSyncChip(message)
        if (!stickyNoKey && !stickyFollow) {
            delay(2800)
            if (syncStatus.text == message) {
                syncStatus.visibility = View.GONE
            }
        }
    }

    private fun showSyncChip(text: String) {
        syncStatus.text = text
        syncStatus.visibility = View.VISIBLE
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val focused = GridFocus.capturePosition(grid)
        reflowSpans()
        GridFocus.restore(grid, focused)
    }

    private fun applyPreferredOrientation() {
        // TV stays landscape; phones/tablets follow user rotation (fullUser).
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
            // TV: fewer columns so channel thumbs read at 10-foot distance.
            isTv -> 4
            widthDp >= 900 -> 6
            widthDp >= 600 -> 4
            else -> 2
        }
    }

    private fun render(
        restoreFocusAt: Int = RecyclerView.NO_POSITION,
        focusFirstIfNeeded: Boolean = false
    ) {
        val app = application as KiddyTubeApp
        val channels = app.catalogRepository.enabledChannels(settings)
        val focused = if (restoreFocusAt != RecyclerView.NO_POSITION) {
            restoreFocusAt
        } else {
            GridFocus.capturePosition(grid)
        }
        adapter.submit(channels)
        lifecycleScope.launch {
            val recent = app.recentWatchStore.current()
            val playable = RecentWatchLogic.resolvePlayable(recent, settings)
            continueAdapter.submit(playable)
            val showContinue = playable.isNotEmpty()
            continueSection.visibility = if (showContinue) View.VISIBLE else View.GONE
            // Avoid trapping D-pad up when the continue row is gone.
            grid.nextFocusUpId = if (showContinue) R.id.continueWatchingList else View.NO_ID
        }
        if (channels.isEmpty()) {
            emptyMessage.visibility = View.VISIBLE
            emptyMessage.text = getString(R.string.empty_channels)
        } else {
            emptyMessage.visibility = View.GONE
            val noKey = ApiKeyResolver.effective(settings.youtubeApiKey).isNullOrBlank()
            val emptyLibs = channels.all { it.videos.isEmpty() }
            if (noKey && emptyLibs) {
                emptyMessage.visibility = View.VISIBLE
                emptyMessage.text = getString(R.string.empty_no_api_key)
            }
            when {
                focused != RecyclerView.NO_POSITION -> GridFocus.restore(grid, focused)
                focusFirstIfNeeded -> GridFocus.requestGridDefault(grid)
            }
        }
    }

    private fun openContinueWatch(recent: RecentWatchItem, video: VideoItem) {
        startActivity(
            Intent(this, PlayerActivity::class.java)
                .putExtra(PlayerActivity.EXTRA_TITLE, video.title)
                .putExtra(PlayerActivity.EXTRA_YOUTUBE_ID, video.youtubeVideoId)
                .putExtra(PlayerActivity.EXTRA_DIRECT_URL, video.directUrl)
                .putExtra(PlayerActivity.EXTRA_ALLOW_SEEK, video.allowSeek)
                .putExtra(PlayerActivity.EXTRA_CHANNEL_ID, recent.channelId)
                .putExtra(PlayerActivity.EXTRA_VIDEO_ID, video.id)
        )
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_UP) {
            if (remote.handleKeyUp(event.keyCode) is RemoteAction.ParentTriggered) {
                parentUnlock.beginParentAccess()
                return true
            }
        }
        if (event.action != KeyEvent.ACTION_DOWN) {
            return super.dispatchKeyEvent(event)
        }
        val action = remote.handleKeyDown(event.keyCode, event) ?: return super.dispatchKeyEvent(event)
        return when (action) {
            RemoteAction.ParentTriggered -> {
                parentUnlock.beginParentAccess()
                true
            }
            RemoteAction.Consume -> true
            RemoteAction.VolumeUp, RemoteAction.VolumeDown -> true
            else -> super.dispatchKeyEvent(event)
        }
    }

    override fun onResume() {
        super.onResume()
        ImmersiveMode.apply(this)
        lifecycleScope.launch {
            val app = application as KiddyTubeApp
            try {
                app.awaitCatalogReady()
            } catch (_: Exception) {
                // continue
            }
            settings = app.catalogRepository.current()
            render(focusFirstIfNeeded = false)
            app.syncWatchNext()
        }
    }
}
