package ae.kiddytube.app.parent

import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import ae.kiddytube.app.BuildConfig
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.catalog.CatalogSettings
import ae.kiddytube.app.catalog.ContentChannel
import ae.kiddytube.app.catalog.SyncStatus
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.sources.MediaUrlValidator
import ae.kiddytube.app.ui.ChannelGridActivity
import kotlinx.coroutines.launch

class ParentActivity : AppCompatActivity() {
    private lateinit var container: LinearLayout
    private lateinit var settings: CatalogSettings

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!requireActiveSession()) return
        setContentView(R.layout.activity_parent)
        container = findViewById(R.id.parentContent)
        findViewById<TextView>(R.id.parentBack).setOnClickListener { goBackToChannels() }
        ImmersiveMode.apply(this)
        lifecycleScope.launch { reload() }
    }

    private suspend fun reload() {
        if (!ParentSession.isActive()) {
            expireSession()
            return
        }
        settings = (application as KiddyTubeApp).catalogRepository.current()
        container.removeAllViews()
        render()
    }

    private fun render() {
        val totalVideos = settings.channels.sumOf { it.videos.size }
        addSectionCard {
            addSectionTitle(it, getString(R.string.parent_section_overview))
            addInfo(it, "KiddyTube ${BuildConfig.VERSION_NAME}")
            addInfo(it, getString(R.string.parent_video_count, totalVideos))
            if (!settings.pinChangedFromDefault) {
                addInfo(it, "Change default PIN (2580) before release-ready.")
            }
            addInfo(
                it,
                "YouTube API key: ${
                    when {
                        !settings.youtubeApiKey.isNullOrBlank() -> "set (parent)"
                        !BuildConfig.YOUTUBE_API_KEY.isNullOrBlank() -> "set (build)"
                        else -> "not set"
                    }
                }"
            )
        }

        addSectionCard {
            addSectionTitle(it, getString(R.string.parent_section_actions))
            addButton(it, "Set YouTube API key") { promptApiKey() }
            addButton(it, "Refresh all playlists") {
                lifecycleScope.launch {
                    val result =
                        (application as KiddyTubeApp).catalogRepository.refreshAllPlaylists(force = true)
                    toast(
                        when (result.status) {
                            SyncStatus.UPDATED ->
                                "Synced ${result.videoCount} videos in ${result.updatedChannels} channels"
                            SyncStatus.SKIPPED_NO_KEY ->
                                "Set a YouTube API key first"
                            SyncStatus.SKIPPED_OFFLINE ->
                                "Offline — try again when connected"
                            SyncStatus.FAILED ->
                                result.message ?: "Sync failed"
                            SyncStatus.SKIPPED_TTL ->
                                "Already up to date"
                        }
                    )
                    reload()
                }
            }
            addButton(it, "Export catalog JSON") {
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
        }

        addHeading(getString(R.string.parent_section_channels))
        settings.channels.sortedBy { it.sortOrder }.forEach { addChannelCard(it) }

        addSectionCard {
            addSectionTitle(it, getString(R.string.parent_section_security))
            addButton(it, "Change PIN") { promptChangePin() }
            addSwitch(it, "Release ready", settings.releaseReady && settings.pinChangedFromDefault) { checked ->
                if (checked && !settings.pinChangedFromDefault) {
                    toast("Change default PIN first")
                    lifecycleScope.launch { reload() }
                    return@addSwitch
                }
                update { s -> s.copy(releaseReady = checked) }
            }
            addButton(it, "Reset all settings") {
                AlertDialog.Builder(this)
                    .setTitle("Reset?")
                    .setMessage("Clears channels and PIN (re-seeded to default 2580).")
                    .setPositiveButton("Reset") { _, _ ->
                        lifecycleScope.launch {
                            val repo = (application as KiddyTubeApp).catalogRepository
                            repo.resetAll()
                            val salt = ParentPinManager.newSaltHex()
                            val hash = ParentPinManager.hashPin(ParentPinManager.DEFAULT_DEV_PIN, salt)
                            repo.update { s ->
                                s.copy(
                                    pinSalt = salt,
                                    pinHash = hash,
                                    pinChangedFromDefault = false,
                                    releaseReady = false
                                )
                            }
                            reload()
                        }
                    }
                    .setNegativeButton(R.string.cancel, null)
                    .show()
            }
        }
    }

    private fun addChannelCard(channel: ContentChannel) {
        val card = LayoutInflater.from(this)
            .inflate(R.layout.item_parent_channel, container, false)
        card.findViewById<TextView>(R.id.channelTitle).text = channel.title
        card.findViewById<TextView>(R.id.channelMeta).text =
            "${if (channel.enabled) "ON" else "OFF"} · ${channel.videos.size} videos"
        card.findViewById<TextView>(R.id.channelPlaylist).text =
            "playlist: ${channel.youtubePlaylistId ?: "(none)"}"
        val actions = card.findViewById<LinearLayout>(R.id.channelActions)
        addButton(actions, if (channel.enabled) "Disable" else "Enable") {
            update { s ->
                s.copy(channels = s.channels.map {
                    if (it.id == channel.id) it.copy(enabled = !it.enabled) else it
                })
            }
        }
        addButton(actions, "Playlist") { promptPlaylist(channel) }
        if (!channel.youtubePlaylistId.isNullOrBlank()) {
            addSwitch(
                actions,
                getString(R.string.parent_follow_uploads),
                channel.followUploads
            ) { checked ->
                lifecycleScope.launch {
                    (application as KiddyTubeApp).catalogRepository
                        .setFollowUploads(channel.id, checked)
                    reload()
                }
            }
        }
        addButton(actions, "Video IDs") { promptVideoIds(channel) }
        addButton(actions, "Direct URL") { promptDirect(channel) }
        val seekOn = channel.videos.isEmpty() || channel.videos.all { it.allowSeek }
        addSwitch(
            actions,
            getString(R.string.parent_seek_enabled),
            seekOn
        ) { checked ->
            lifecycleScope.launch {
                (application as KiddyTubeApp).catalogRepository
                    .setChannelAllowSeek(channel.id, checked)
                reload()
            }
        }
        addButton(actions, "Refresh") {
            lifecycleScope.launch {
                val r = (application as KiddyTubeApp).catalogRepository
                    .refreshChannelFromYoutube(channel.id)
                toast(r.fold({ "Loaded $it" }, { it.message ?: "Failed" }))
                reload()
            }
        }
        container.addView(card)
    }

    private fun promptApiKey() {
        val input = EditText(this).apply {
            setText(settings.youtubeApiKey.orEmpty())
            inputType = InputType.TYPE_CLASS_TEXT
            hint = "AIza..."
            setTextColor(inkNavy())
            setHintTextColor(inkMuted())
        }
        AlertDialog.Builder(this)
            .setTitle("YouTube Data API key")
            .setView(padded(input))
            .setPositiveButton("Save") { _, _ ->
                val key = input.text.toString().trim().ifBlank { null }
                update { it.copy(youtubeApiKey = key) }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun promptPlaylist(channel: ContentChannel) {
        val input = EditText(this).apply {
            setText(channel.youtubePlaylistId.orEmpty())
            hint = "Playlist ID or YouTube playlist URL (blank to clear)"
            setTextColor(inkNavy())
            setHintTextColor(inkMuted())
        }
        AlertDialog.Builder(this)
            .setTitle(channel.title)
            .setView(padded(input))
            .setPositiveButton("Save") { _, _ ->
                lifecycleScope.launch {
                    (application as KiddyTubeApp).catalogRepository.setPlaylistId(
                        channel.id,
                        input.text.toString()
                    )
                    reload()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun promptVideoIds(channel: ContentChannel) {
        val input = EditText(this).apply {
            hint = "Comma-separated video IDs or watch URLs"
            minLines = 3
            setTextColor(inkNavy())
            setHintTextColor(inkMuted())
        }
        AlertDialog.Builder(this)
            .setTitle("Add YouTube videos")
            .setView(padded(input))
            .setPositiveButton("Add") { _, _ ->
                lifecycleScope.launch {
                    (application as KiddyTubeApp).catalogRepository.addManualVideoIds(
                        channel.id,
                        input.text.toString()
                    )
                    reload()
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun promptDirect(channel: ContentChannel) {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        val title = EditText(this).apply {
            hint = "Title"
            setTextColor(inkNavy())
            setHintTextColor(inkMuted())
        }
        val url = EditText(this).apply {
            hint = "https://...mp4 or .m3u8 (HTTPS only)"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            setTextColor(inkNavy())
            setHintTextColor(inkMuted())
        }
        layout.addView(title)
        layout.addView(url)
        AlertDialog.Builder(this)
            .setTitle("Add direct stream")
            .setView(padded(layout))
            .setPositiveButton("Add") { _, _ ->
                val u = url.text.toString().trim()
                if (!MediaUrlValidator.isDirectMediaUrl(u)) {
                    toast("Invalid or blocked URL (HTTPS direct media only)")
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
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun promptChangePin() {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        val pin = EditText(this).apply {
            hint = "New PIN"
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            setTextColor(inkNavy())
            setHintTextColor(inkMuted())
        }
        val confirm = EditText(this).apply {
            hint = "Confirm"
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            setTextColor(inkNavy())
            setHintTextColor(inkMuted())
        }
        layout.addView(pin)
        layout.addView(confirm)
        AlertDialog.Builder(this)
            .setTitle("Change PIN")
            .setView(padded(layout))
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
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun update(transform: (CatalogSettings) -> CatalogSettings) {
        lifecycleScope.launch {
            (application as KiddyTubeApp).catalogRepository.update(transform)
            reload()
        }
    }

    private fun addSectionCard(build: (LinearLayout) -> Unit) {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.tile_idle)
            val pad = dp(16)
            setPadding(pad, dp(14), pad, pad)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.bottomMargin = dp(12) }
        }
        build(card)
        container.addView(card)
    }

    private fun addHeading(text: String) {
        container.addView(TextView(this).apply {
            this.text = text
            setTextColor(inkNavy())
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setPadding(dp(4), dp(8), dp(4), dp(10))
        })
    }

    private fun addSectionTitle(parent: LinearLayout, text: String) {
        parent.addView(TextView(this).apply {
            this.text = text
            setTextColor(inkNavy())
            typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.NORMAL)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            setPadding(0, 0, 0, dp(8))
        })
    }

    private fun addInfo(parent: LinearLayout, text: String) {
        parent.addView(TextView(this).apply {
            this.text = text
            setTextColor(inkMuted())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(0, dp(2), 0, dp(2))
        })
    }

    private fun addButton(parent: ViewGroup, label: String, onClick: () -> Unit) {
        parent.addView(btn(label, onClick).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = dp(8) }
        })
    }

    private fun btn(label: String, onClick: () -> Unit): Button =
        Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            text = label
            isAllCaps = false
            isFocusable = true
            setTextColor(inkNavy())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setBackgroundResource(R.drawable.focusable_button)
            setPadding(dp(16), dp(12), dp(16), dp(12))
            setOnClickListener { onClick() }
        }

    private fun addSwitch(
        parent: ViewGroup,
        label: String,
        checked: Boolean,
        onChange: (Boolean) -> Unit
    ) {
        parent.addView(Switch(this).apply {
            text = label
            isChecked = checked
            isFocusable = true
            setTextColor(inkNavy())
            setPadding(0, dp(10), 0, dp(4))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = dp(4) }
            setOnCheckedChangeListener { _, isChecked -> onChange(isChecked) }
        })
    }

    private fun padded(view: android.view.View): LinearLayout =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = dp(20)
            setPadding(pad, dp(12), pad, dp(4))
            addView(
                view,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            )
        }

    private fun goBackToChannels() {
        startActivity(Intent(this, ChannelGridActivity::class.java))
        finish()
    }

    private fun requireActiveSession(): Boolean {
        if (ParentSession.isActive()) return true
        expireSession()
        return false
    }

    private fun expireSession() {
        ParentSession.clear()
        Toast.makeText(this, R.string.parent_session_expired, Toast.LENGTH_SHORT).show()
        finish()
    }

    private fun toast(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
    }

    private fun inkNavy(): Int = ContextCompat.getColor(this, R.color.ink_navy)
    private fun inkMuted(): Int = ContextCompat.getColor(this, R.color.ink_muted)
    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()

    override fun onResume() {
        super.onResume()
        if (!::container.isInitialized) return
        if (!requireActiveSession()) return
        ImmersiveMode.apply(this)
    }
}
