package ae.kiddytube.app.parent

import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import ae.kiddytube.app.BuildConfig
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.catalog.CatalogSettings
import ae.kiddytube.app.catalog.ContentChannel
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.sources.MediaUrlValidator
import ae.kiddytube.app.ui.ChannelGridActivity
import kotlinx.coroutines.launch

class ParentActivity : AppCompatActivity() {
    private lateinit var container: LinearLayout
    private lateinit var settings: CatalogSettings

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val scroll = ScrollView(this)
        container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 32, 48, 48)
        }
        scroll.addView(container)
        setContentView(scroll)
        ImmersiveMode.apply(this)
        lifecycleScope.launch { reload() }
    }

    private suspend fun reload() {
        settings = (application as KiddyTubeApp).catalogRepository.current()
        container.removeAllViews()
        render()
    }

    private fun render() {
        addTitle("Parent dashboard")
        addInfo("KiddyTube ${BuildConfig.VERSION_NAME}")
        if (!settings.pinChangedFromDefault) {
            addInfo("Change default PIN (2580) before release-ready.")
        }
        addInfo("YouTube API key: ${if (settings.youtubeApiKey.isNullOrBlank()) "not set" else "set"}")

        addButton("Set YouTube API key") { promptApiKey() }
        addButton("Refresh all playlists") {
            lifecycleScope.launch {
                val n = (application as KiddyTubeApp).catalogRepository.refreshAllPlaylists(force = true)
                toast("Synced $n videos")
                reload()
            }
        }
        addButton("Export catalog JSON") {
            lifecycleScope.launch {
                val json = (application as KiddyTubeApp).catalogRepository.exportJson()
                val share = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, json)
                    putExtra(Intent.EXTRA_SUBJECT, "kids-catalog.json")
                }
                startActivity(Intent.createChooser(share, "Export catalog"))
            }
        }

        addTitle("Channels")
        settings.channels.sortedBy { it.sortOrder }.forEach { addChannelRow(it) }

        addTitle("Security")
        addButton("Change PIN") { promptChangePin() }
        addSwitch("Release ready", settings.releaseReady && settings.pinChangedFromDefault) { checked ->
            if (checked && !settings.pinChangedFromDefault) {
                toast("Change default PIN first")
                lifecycleScope.launch { reload() }
                return@addSwitch
            }
            update { it.copy(releaseReady = checked) }
        }
        addButton("Reset all settings") {
            AlertDialog.Builder(this)
                .setTitle("Reset?")
                .setMessage("Clears channels and PIN (re-seeded to default 2580).")
                .setPositiveButton("Reset") { _, _ ->
                    lifecycleScope.launch {
                        val repo = (application as KiddyTubeApp).catalogRepository
                        repo.resetAll()
                        val salt = ParentPinManager.newSaltHex()
                        val hash = ParentPinManager.hashPin(ParentPinManager.DEFAULT_DEV_PIN, salt)
                        repo.update {
                            it.copy(
                                pinSalt = salt,
                                pinHash = hash,
                                pinChangedFromDefault = false,
                                releaseReady = false
                            )
                        }
                        reload()
                    }
                }
                .setNegativeButton("Cancel", null)
                .show()
        }
        addButton("Back to channels") {
            startActivity(Intent(this, ChannelGridActivity::class.java))
            finish()
        }
    }

    private fun addChannelRow(channel: ContentChannel) {
        addInfo("${channel.title} — ${if (channel.enabled) "ON" else "OFF"} (${channel.videos.size} videos)")
        addInfo("  playlist=${channel.youtubePlaylistId ?: "(none)"}")
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        row.addView(btn(if (channel.enabled) "Disable" else "Enable") {
            update { s ->
                s.copy(channels = s.channels.map {
                    if (it.id == channel.id) it.copy(enabled = !it.enabled) else it
                })
            }
        })
        row.addView(btn("Playlist") { promptPlaylist(channel) })
        row.addView(btn("Video IDs") { promptVideoIds(channel) })
        row.addView(btn("Direct URL") { promptDirect(channel) })
        row.addView(btn("Refresh") {
            lifecycleScope.launch {
                val r = (application as KiddyTubeApp).catalogRepository.refreshChannelFromYoutube(channel.id)
                toast(r.fold({ "Loaded $it" }, { it.message ?: "Failed" }))
                reload()
            }
        })
        container.addView(row)
    }

    private fun promptApiKey() {
        val input = EditText(this).apply {
            setText(settings.youtubeApiKey.orEmpty())
            inputType = InputType.TYPE_CLASS_TEXT
            hint = "AIza..."
        }
        AlertDialog.Builder(this)
            .setTitle("YouTube Data API key")
            .setView(input)
            .setPositiveButton("Save") { _, _ ->
                val key = input.text.toString().trim().ifBlank { null }
                update { it.copy(youtubeApiKey = key) }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun promptPlaylist(channel: ContentChannel) {
        val input = EditText(this).apply {
            setText(channel.youtubePlaylistId.orEmpty())
            hint = "Playlist ID or YouTube playlist URL"
        }
        AlertDialog.Builder(this)
            .setTitle(channel.title)
            .setView(input)
            .setPositiveButton("Save") { _, _ ->
                lifecycleScope.launch {
                    (application as KiddyTubeApp).catalogRepository.setPlaylistId(
                        channel.id,
                        input.text.toString()
                    )
                    reload()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun promptVideoIds(channel: ContentChannel) {
        val input = EditText(this).apply {
            hint = "Comma-separated video IDs or watch URLs"
            minLines = 3
        }
        AlertDialog.Builder(this)
            .setTitle("Add YouTube videos")
            .setView(input)
            .setPositiveButton("Add") { _, _ ->
                lifecycleScope.launch {
                    (application as KiddyTubeApp).catalogRepository.addManualVideoIds(
                        channel.id,
                        input.text.toString()
                    )
                    reload()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun promptDirect(channel: ContentChannel) {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 24, 48, 8)
        }
        val title = EditText(this).apply { hint = "Title" }
        val url = EditText(this).apply {
            hint = "https://...mp4 or .m3u8 (not Drive /view)"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
        }
        layout.addView(title)
        layout.addView(url)
        AlertDialog.Builder(this)
            .setTitle("Add direct stream")
            .setView(layout)
            .setPositiveButton("Add") { _, _ ->
                val u = url.text.toString().trim()
                if (!MediaUrlValidator.isDirectMediaUrl(u)) {
                    toast("Invalid or blocked URL (use direct media links)")
                    return@setPositiveButton
                }
                lifecycleScope.launch {
                    (application as KiddyTubeApp).catalogRepository.addDirectVideo(
                        channel.id,
                        title.text.toString(),
                        u
                    )
                    reload()
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun promptChangePin() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 24, 48, 8)
        }
        val pin = EditText(this).apply {
            hint = "New PIN"
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
        }
        val confirm = EditText(this).apply {
            hint = "Confirm"
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
        }
        layout.addView(pin)
        layout.addView(confirm)
        AlertDialog.Builder(this)
            .setTitle("Change PIN")
            .setView(layout)
            .setPositiveButton("Save") { _, _ ->
                val p1 = pin.text.toString()
                val p2 = confirm.text.toString()
                if (!ParentPinManager.isValidPinFormat(p1) || p1 != p2) {
                    toast("PIN must be 4–8 matching digits")
                    return@setPositiveButton
                }
                if (p1 == ParentPinManager.DEFAULT_DEV_PIN) {
                    toast("Choose a non-default PIN")
                    return@setPositiveButton
                }
                val salt = ParentPinManager.newSaltHex()
                val hash = ParentPinManager.hashPin(p1, salt)
                update {
                    it.copy(pinSalt = salt, pinHash = hash, pinChangedFromDefault = true)
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun update(transform: (CatalogSettings) -> CatalogSettings) {
        lifecycleScope.launch {
            (application as KiddyTubeApp).catalogRepository.update(transform)
            reload()
        }
    }

    private fun addTitle(text: String) {
        container.addView(TextView(this).apply {
            this.text = text
            textSize = 22f
            setPadding(0, 28, 0, 12)
            setTextColor(0xFFFFFFFF.toInt())
        })
    }

    private fun addInfo(text: String) {
        container.addView(TextView(this).apply {
            this.text = text
            textSize = 15f
            setPadding(0, 4, 0, 4)
            setTextColor(0xFFDDDDDD.toInt())
        })
    }

    private fun addButton(label: String, onClick: () -> Unit) {
        container.addView(btn(label, onClick).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = 8 }
        })
    }

    private fun btn(label: String, onClick: () -> Unit): Button =
        Button(this).apply {
            text = label
            isFocusable = true
            setBackgroundResource(R.drawable.focusable_button)
            setOnClickListener { onClick() }
        }

    private fun addSwitch(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
        container.addView(Switch(this).apply {
            text = label
            isChecked = checked
            isFocusable = true
            setOnCheckedChangeListener { _, isChecked -> onChange(isChecked) }
        })
    }

    private fun toast(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
    }

    override fun onResume() {
        super.onResume()
        ImmersiveMode.apply(this)
    }
}
