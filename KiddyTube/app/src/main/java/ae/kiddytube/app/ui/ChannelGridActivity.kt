package ae.kiddytube.app.ui

import android.content.Intent
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Bundle
import android.text.InputType
import android.view.KeyEvent
import android.view.View
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.catalog.ApiKeyResolver
import ae.kiddytube.app.catalog.CatalogSettings
import ae.kiddytube.app.catalog.SyncStatus
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.parent.ParentActivity
import ae.kiddytube.app.parent.ParentPinManager
import ae.kiddytube.app.remote.RemoteAction
import ae.kiddytube.app.remote.RemoteKeyHandler
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class ChannelGridActivity : AppCompatActivity() {
    private lateinit var grid: RecyclerView
    private lateinit var emptyMessage: TextView
    private lateinit var brandTitle: TextView
    private lateinit var syncStatus: TextView
    private lateinit var adapter: ChannelGridAdapter
    private lateinit var pinManager: ParentPinManager
    private lateinit var remote: RemoteKeyHandler
    private var settings: CatalogSettings = CatalogSettings()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_grid)
        grid = findViewById(R.id.grid)
        emptyMessage = findViewById(R.id.emptyMessage)
        brandTitle = findViewById(R.id.brandTitle)
        syncStatus = findViewById(R.id.syncStatus)
        brandTitle.text = getString(R.string.app_name)

        pinManager = ParentPinManager()
        remote = RemoteKeyHandler(
            pinManager,
            getSystemService(AUDIO_SERVICE) as AudioManager,
            consumeBack = true
        )

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

        ImmersiveMode.apply(this)
        lifecycleScope.launch {
            settings = (application as KiddyTubeApp).catalogRepository.settingsFlow.first()
            pinManager = ParentPinManager(settings.failCount, settings.lockedUntilMs)
            remote = RemoteKeyHandler(
                pinManager,
                getSystemService(AUDIO_SERVICE) as AudioManager,
                consumeBack = true
            )
            render()
            runLaunchSync()
        }
    }

    private suspend fun runLaunchSync() {
        showSyncChip(getString(R.string.sync_updating), sticky = true)
        val repo = (application as KiddyTubeApp).catalogRepository
        val result = repo.refreshAllPlaylists()
        settings = repo.current()
        render()

        val message = when (result.status) {
            SyncStatus.UPDATED -> getString(R.string.sync_updated)
            SyncStatus.SKIPPED_OFFLINE -> getString(R.string.sync_offline)
            SyncStatus.SKIPPED_NO_KEY -> getString(R.string.sync_no_key)
            SyncStatus.FAILED -> getString(R.string.sync_failed)
            SyncStatus.SKIPPED_TTL -> getString(R.string.sync_skipped)
        }
        val stickyNoKey = result.status == SyncStatus.SKIPPED_NO_KEY &&
            settings.channels.any { it.enabled && it.videos.isEmpty() }
        showSyncChip(message, sticky = stickyNoKey)
        if (!stickyNoKey) {
            delay(2800)
            if (syncStatus.text == message) {
                syncStatus.visibility = View.GONE
            }
        }
    }

    private fun showSyncChip(text: String, sticky: Boolean) {
        syncStatus.text = text
        syncStatus.visibility = View.VISIBLE
        syncStatus.alpha = if (sticky) 1f else 1f
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        grid.layoutManager = GridLayoutManager(this, spanCount())
    }

    private fun spanCount(): Int {
        val uiMode = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        val isTv = uiMode == Configuration.UI_MODE_TYPE_TELEVISION
        val widthDp = resources.configuration.screenWidthDp
        return when {
            isTv || widthDp >= 900 -> 6
            widthDp >= 600 -> 4
            else -> 3
        }
    }

    private fun render() {
        val repo = (application as KiddyTubeApp).catalogRepository
        val channels = repo.enabledChannels(settings)
        adapter.submit(channels)
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
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_UP) {
            if (remote.handleKeyUp(event.keyCode) is RemoteAction.ParentTriggered) {
                beginParentAccess()
                return true
            }
        }
        if (event.action != KeyEvent.ACTION_DOWN) {
            return super.dispatchKeyEvent(event)
        }
        val action = remote.handleKeyDown(event.keyCode, event) ?: return super.dispatchKeyEvent(event)
        return when (action) {
            RemoteAction.ParentTriggered -> {
                beginParentAccess()
                true
            }
            RemoteAction.Consume -> true
            else -> super.dispatchKeyEvent(event)
        }
    }

    private fun beginParentAccess() {
        val now = System.currentTimeMillis()
        pinManager.refreshLockout(now)
        if (pinManager.isLockedOut(now)) return
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
        }
        AlertDialog.Builder(this)
            .setTitle(R.string.parent_pin_title)
            .setView(input)
            .setPositiveButton(R.string.unlock) { dialog, _ ->
                val pin = input.text.toString()
                lifecycleScope.launch {
                    val repo = (application as KiddyTubeApp).catalogRepository
                    val latest = repo.current()
                    if (pinManager.verifyPin(pin, latest.pinSalt, latest.pinHash)) {
                        pinManager.registerSuccess()
                        repo.update { it.copy(failCount = 0, lockedUntilMs = 0L) }
                        dialog.dismiss()
                        startActivity(Intent(this@ChannelGridActivity, ParentActivity::class.java))
                    } else {
                        val locked = pinManager.registerFailure(System.currentTimeMillis())
                        repo.update {
                            it.copy(
                                failCount = pinManager.failureCount,
                                lockedUntilMs = pinManager.lockedUntilMs
                            )
                        }
                        if (locked) dialog.dismiss()
                    }
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    override fun onResume() {
        super.onResume()
        ImmersiveMode.apply(this)
        lifecycleScope.launch {
            settings = (application as KiddyTubeApp).catalogRepository.current()
            render()
        }
    }
}
