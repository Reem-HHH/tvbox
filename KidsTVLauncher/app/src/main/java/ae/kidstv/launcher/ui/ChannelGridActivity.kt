package ae.kidstv.launcher.ui

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
import ae.kidstv.launcher.KidsTvApp
import ae.kidstv.launcher.R
import ae.kidstv.launcher.catalog.CatalogSettings
import ae.kidstv.launcher.launcher.ImmersiveMode
import ae.kidstv.launcher.parent.ParentActivity
import ae.kidstv.launcher.parent.ParentPinManager
import ae.kidstv.launcher.remote.RemoteAction
import ae.kidstv.launcher.remote.RemoteKeyHandler
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class ChannelGridActivity : AppCompatActivity() {
    private lateinit var grid: RecyclerView
    private lateinit var emptyMessage: TextView
    private lateinit var adapter: ChannelGridAdapter
    private lateinit var pinManager: ParentPinManager
    private lateinit var remote: RemoteKeyHandler
    private var settings: CatalogSettings = CatalogSettings()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_grid)
        grid = findViewById(R.id.grid)
        emptyMessage = findViewById(R.id.emptyMessage)

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

        ImmersiveMode.apply(this)
        lifecycleScope.launch {
            settings = (application as KidsTvApp).catalogRepository.settingsFlow.first()
            pinManager = ParentPinManager(settings.failCount, settings.lockedUntilMs)
            remote = RemoteKeyHandler(
                pinManager,
                getSystemService(AUDIO_SERVICE) as AudioManager,
                consumeBack = true
            )
            render()
            (application as KidsTvApp).catalogRepository.refreshAllPlaylists()
            settings = (application as KidsTvApp).catalogRepository.current()
            render()
        }
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
        val repo = (application as KidsTvApp).catalogRepository
        val channels = repo.enabledChannels(settings)
        adapter.submit(channels)
        emptyMessage.visibility = if (channels.isEmpty()) View.VISIBLE else View.GONE
        emptyMessage.text = "No channels enabled.\nUse parent settings to add content."
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
            .setTitle("Parent PIN")
            .setView(input)
            .setPositiveButton("Unlock") { dialog, _ ->
                val pin = input.text.toString()
                lifecycleScope.launch {
                    val repo = (application as KidsTvApp).catalogRepository
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
            .setNegativeButton("Cancel", null)
            .show()
    }

    override fun onResume() {
        super.onResume()
        ImmersiveMode.apply(this)
        lifecycleScope.launch {
            settings = (application as KidsTvApp).catalogRepository.current()
            render()
        }
    }
}
