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
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import ae.kiddytube.app.BuildConfig
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.catalog.ApiKeyResolver
import ae.kiddytube.app.catalog.CatalogSettings
import ae.kiddytube.app.catalog.HomeLibraryMode
import ae.kiddytube.app.catalog.PlayableVideo
import ae.kiddytube.app.catalog.RecentWatchLogic
import ae.kiddytube.app.catalog.SyncStatus
import ae.kiddytube.app.catalog.VideoItem
import ae.kiddytube.app.catalog.RecentWatchItem
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.parent.ParentPinManager
import ae.kiddytube.app.parent.ParentUnlockCoordinator
import ae.kiddytube.app.parent.ReleasePinPolicy
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
    private lateinit var homeModeToggle: TextView
    private lateinit var parentSettings: ImageButton
    private lateinit var channelAdapter: ChannelGridAdapter
    private lateinit var videoAdapter: VideoGridAdapter
    private lateinit var continueAdapter: ContinueWatchAdapter
    private lateinit var pinManager: ParentPinManager
    private lateinit var parentUnlock: ParentUnlockCoordinator
    private lateinit var remote: RemoteKeyHandler
    private var settings: CatalogSettings = CatalogSettings()
    private var lastCatalogFingerprint: String? = null
    private var lastContinueFingerprint: String? = null
    private var homeGridReady = false

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
        homeModeToggle = findViewById(R.id.homeModeToggle)
        parentSettings = findViewById(R.id.parentSettings)
        brandTitle.text = getString(R.string.app_name)
        homeModeToggle.visibility = View.VISIBLE
        homeModeToggle.setOnClickListener { toggleHomeMode() }

        pinManager = ParentPinManager()
        parentUnlock = ParentUnlockCoordinator(this, pinManager)
        remote = RemoteKeyHandler(
            pinManager,
            getSystemService(AUDIO_SERVICE) as AudioManager,
            consumeBack = true
        )
        parentSettings.setOnClickListener { parentUnlock.beginParentAccess() }

        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    moveTaskToBack(true)
                }
            }
        )

        channelAdapter = ChannelGridAdapter { channel ->
            if (!ensureKidPlaybackAllowed()) return@ChannelGridAdapter
            if (!OpenDebouncer.tryOpen("channel:${channel.id}")) return@ChannelGridAdapter
            NavFocusMemory.rememberChannel(channel.id)
            startActivity(
                Intent(this, VideoLibraryActivity::class.java)
                    .putExtra(VideoLibraryActivity.EXTRA_CHANNEL_ID, channel.id)
                    .putExtra(VideoLibraryActivity.EXTRA_CHANNEL_TITLE, channel.title)
            )
        }
        videoAdapter = VideoGridAdapter { item -> openMixVideo(item) }
        grid.adapter = channelAdapter
        grid.layoutManager = TvGridLayoutManager(this, spanCount())
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
        wireHeaderFocusDown(showContinue = false)

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
            maybeShowReleasePinChip()
            runLaunchSync()
        }
    }

    /** Release APKs block kid playback until the factory PIN is replaced. Debug is unchanged. */
    private fun ensureKidPlaybackAllowed(): Boolean {
        if (!ReleasePinPolicy.requirePinChangeForKidPlayback(
                BuildConfig.DEBUG,
                settings.pinChangedFromDefault
            )
        ) {
            return true
        }
        Toast.makeText(this, R.string.parent_release_pin_required, Toast.LENGTH_LONG).show()
        maybeShowReleasePinChip()
        return false
    }

    private fun maybeShowReleasePinChip() {
        if (!ReleasePinPolicy.requirePinChangeForKidPlayback(
                BuildConfig.DEBUG,
                settings.pinChangedFromDefault
            )
        ) {
            return
        }
        showSyncChip(getString(R.string.parent_release_pin_required))
    }

    private suspend fun runLaunchSync() {
        showSyncChip(getString(R.string.sync_updating))
        val repo = (application as KiddyTubeApp).catalogRepository
        val focused = GridFocus.capturePosition(grid)
        val result = repo.refreshAllPlaylists()
        settings = repo.current()
        render(restoreFocusAt = focused)

        val message = when (result.status) {
            SyncStatus.UPDATED -> {
                val detail = result.message?.trim().orEmpty()
                if (detail.isNotEmpty()) {
                    getString(R.string.sync_partial) + " — " + detail.take(80)
                } else {
                    getString(R.string.sync_updated)
                }
            }
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
        val stickyPartial = result.status == SyncStatus.UPDATED &&
            !result.message.isNullOrBlank()
        if (ReleasePinPolicy.requirePinChangeForKidPlayback(
                BuildConfig.DEBUG,
                settings.pinChangedFromDefault
            )
        ) {
            maybeShowReleasePinChip()
            return
        }
        showSyncChip(message)
        if (!stickyNoKey && !stickyFollow && !stickyPartial) {
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
        val lm = grid.layoutManager as? TvGridLayoutManager
        if (lm != null) {
            if (lm.spanCount != spans) lm.spanCount = spans
        } else {
            grid.layoutManager = TvGridLayoutManager(this, spans)
        }
    }

    private fun isTelevision(): Boolean = TvUi.isTelevision(this)

    private fun spanCount(): Int {
        val isTv = isTelevision()
        val widthDp = resources.configuration.screenWidthDp
        val mix = settings.homeLibraryMode == HomeLibraryMode.MIX_VIDEOS
        return when {
            isTv -> 3
            mix && widthDp >= 900 -> 5
            mix && widthDp >= 600 -> 3
            mix -> 2
            widthDp >= 900 -> 6
            widthDp >= 600 -> 4
            else -> 2
        }
    }

    private fun wireHeaderFocusDown(showContinue: Boolean) {
        val target = if (showContinue) R.id.continueWatchingList else R.id.grid
        syncStatus.nextFocusDownId = target
        homeModeToggle.nextFocusDownId = target
        parentSettings.nextFocusDownId = target
        grid.nextFocusUpId = if (showContinue) R.id.continueWatchingList else View.NO_ID
    }

    private fun catalogFingerprint(settings: CatalogSettings): String = buildString {
        append(settings.homeLibraryMode.name)
        for (ch in settings.channels) {
            append('|').append(ch.id)
                .append(':').append(ch.enabled)
                .append(':').append(ch.videos.size)
            ch.videos.firstOrNull()?.let { append(':').append(it.id) }
            ch.videos.lastOrNull()?.let { append(':').append(it.id) }
        }
    }

    private fun continueFingerprint(items: List<Pair<RecentWatchItem, VideoItem>>): String =
        items.joinToString("|") { (recent, video) ->
            "${video.id}:${recent.watchedAtMs}:${recent.positionMs}"
        }

    private fun updateHomeModeChip() {
        val mix = settings.homeLibraryMode == HomeLibraryMode.MIX_VIDEOS
        homeModeToggle.text = getString(
            if (mix) R.string.home_mode_switch_to_shows else R.string.home_mode_switch_to_mix
        )
        homeModeToggle.contentDescription = getString(
            if (mix) R.string.a11y_home_mode_mix else R.string.a11y_home_mode_shows
        )
    }

    private fun toggleHomeMode() {
        parentUnlock.beginParentAccess {
            lifecycleScope.launch {
                val app = application as KiddyTubeApp
                val next = if (settings.homeLibraryMode == HomeLibraryMode.MIX_VIDEOS) {
                    HomeLibraryMode.CHANNELS
                } else {
                    HomeLibraryMode.MIX_VIDEOS
                }
                app.catalogRepository.update { it.copy(homeLibraryMode = next) }
                settings = app.catalogRepository.current()
                render(focusFirstIfNeeded = true)
            }
        }
    }

    private fun render(
        restoreFocusAt: Int = RecyclerView.NO_POSITION,
        focusFirstIfNeeded: Boolean = false
    ) {
        val app = application as KiddyTubeApp
        updateHomeModeChip()
        reflowSpans()
        val liveFocus = GridFocus.capturePosition(grid)
        val mix = settings.homeLibraryMode == HomeLibraryMode.MIX_VIDEOS
        lastCatalogFingerprint = catalogFingerprint(settings)

        lifecycleScope.launch {
            refreshContinueRow()
        }

        if (mix) {
            if (grid.adapter !== videoAdapter) grid.adapter = videoAdapter
            val videos = app.catalogRepository.flatHomeVideos(settings)
            videoAdapter.submit(videos)
            val rememberedAfter = NavFocusMemory.lastHomeVideoId
                ?.let { videoAdapter.indexOfVideoId(it) }
                ?.takeIf { it >= 0 }
                ?: RecyclerView.NO_POSITION
            val channels = app.catalogRepository.enabledChannels(settings)
            when {
                channels.isEmpty() -> {
                    emptyMessage.visibility = View.VISIBLE
                    emptyMessage.text = getString(R.string.empty_channels)
                }
                videos.isEmpty() -> {
                    emptyMessage.visibility = View.VISIBLE
                    val noKey = ApiKeyResolver.effective(settings.youtubeApiKey).isNullOrBlank()
                    emptyMessage.text = getString(
                        if (noKey) R.string.empty_no_api_key else R.string.empty_mix_videos
                    )
                }
                else -> {
                    emptyMessage.visibility = View.GONE
                    when {
                        restoreFocusAt != RecyclerView.NO_POSITION ->
                            GridFocus.restore(grid, restoreFocusAt)
                        liveFocus != RecyclerView.NO_POSITION ->
                            GridFocus.restore(grid, liveFocus)
                        rememberedAfter != RecyclerView.NO_POSITION ->
                            GridFocus.restore(grid, rememberedAfter)
                        focusFirstIfNeeded -> GridFocus.requestGridDefault(grid)
                    }
                }
            }
            homeGridReady = true
            return
        }

        if (grid.adapter !== channelAdapter) grid.adapter = channelAdapter
        val channels = app.catalogRepository.enabledChannels(settings)
        channelAdapter.submit(channels)
        val rememberedAfter = NavFocusMemory.lastChannelId
            ?.let { channelAdapter.indexOfChannelId(it) }
            ?.takeIf { it >= 0 }
            ?: RecyclerView.NO_POSITION
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
                restoreFocusAt != RecyclerView.NO_POSITION ->
                    GridFocus.restore(grid, restoreFocusAt)
                liveFocus != RecyclerView.NO_POSITION ->
                    GridFocus.restore(grid, liveFocus)
                rememberedAfter != RecyclerView.NO_POSITION ->
                    GridFocus.restore(grid, rememberedAfter)
                focusFirstIfNeeded -> GridFocus.requestGridDefault(grid)
            }
        }
        homeGridReady = true
    }

    private suspend fun refreshContinueRow() {
        val app = application as KiddyTubeApp
        val recent = app.recentWatchStore.current()
        val playable = RecentWatchLogic.resolvePlayable(recent, settings)
        val fingerprint = continueFingerprint(playable)
        if (fingerprint != lastContinueFingerprint) {
            lastContinueFingerprint = fingerprint
            continueAdapter.submit(playable)
        }
        val showContinue = playable.isNotEmpty()
        continueSection.visibility = if (showContinue) View.VISIBLE else View.GONE
        wireHeaderFocusDown(showContinue)
    }

    private fun openMixVideo(item: PlayableVideo) {
        if (!ensureKidPlaybackAllowed()) return
        val video = item.video
        if (!OpenDebouncer.tryOpen("mix:${item.channelId}:${video.id}")) return
        NavFocusMemory.rememberHomeVideo(video.id)
        NavFocusMemory.rememberVideo(item.channelId, video.id)
        startActivity(
            Intent(this, PlayerActivity::class.java)
                .putExtra(PlayerActivity.EXTRA_TITLE, video.title)
                .putExtra(PlayerActivity.EXTRA_YOUTUBE_ID, video.youtubeVideoId)
                .putExtra(PlayerActivity.EXTRA_DIRECT_URL, video.directUrl)
                .putExtra(PlayerActivity.EXTRA_ALLOW_SEEK, video.allowSeek)
                .putExtra(PlayerActivity.EXTRA_CHANNEL_ID, item.channelId)
                .putExtra(PlayerActivity.EXTRA_VIDEO_ID, video.id)
        )
    }

    private fun openContinueWatch(recent: RecentWatchItem, video: VideoItem) {
        if (!ensureKidPlaybackAllowed()) return
        if (!OpenDebouncer.tryOpen("continue:${video.id}")) return
        NavFocusMemory.rememberVideo(recent.channelId, video.id)
        val resumeMs = recent.positionMs.takeIf { it >= 5_000L } ?: 0L
        startActivity(
            Intent(this, PlayerActivity::class.java)
                .putExtra(PlayerActivity.EXTRA_TITLE, video.title)
                .putExtra(PlayerActivity.EXTRA_YOUTUBE_ID, video.youtubeVideoId)
                .putExtra(PlayerActivity.EXTRA_DIRECT_URL, video.directUrl)
                .putExtra(PlayerActivity.EXTRA_ALLOW_SEEK, video.allowSeek)
                .putExtra(PlayerActivity.EXTRA_CHANNEL_ID, recent.channelId)
                .putExtra(PlayerActivity.EXTRA_VIDEO_ID, video.id)
                .putExtra(PlayerActivity.EXTRA_START_POSITION_MS, resumeMs)
        )
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_UP) {
            if (remote.handleKeyUp(event.keyCode) is RemoteAction.ParentTriggered) {
                parentUnlock.beginParentAccess()
                return true
            }
            if (event.keyCode == KeyEvent.KEYCODE_BACK) {
                moveTaskToBack(true)
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
            val fingerprint = catalogFingerprint(settings)
            if (!homeGridReady || fingerprint != lastCatalogFingerprint) {
                render(focusFirstIfNeeded = false)
            } else {
                // Keep Mix/Shows scroll + focus; only refresh Continue Watching / focus wiring.
                refreshContinueRow()
            }
            if (ReleasePinPolicy.requirePinChangeForKidPlayback(
                    BuildConfig.DEBUG,
                    settings.pinChangedFromDefault
                )
            ) {
                maybeShowReleasePinChip()
            } else if (syncStatus.text == getString(R.string.parent_release_pin_required)) {
                syncStatus.visibility = View.GONE
            }
            app.syncWatchNext()
        }
    }
}
