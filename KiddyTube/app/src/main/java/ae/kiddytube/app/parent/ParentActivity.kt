package ae.kiddytube.app.parent

import android.content.Intent
import android.os.Bundle
import android.text.InputType
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import ae.kiddytube.app.BuildConfig
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import ae.kiddytube.app.catalog.CatalogSettings
import ae.kiddytube.app.catalog.ContentChannel
import ae.kiddytube.app.catalog.HomeLibraryMode
import ae.kiddytube.app.catalog.SyncPolicy
import ae.kiddytube.app.catalog.SyncStatus
import ae.kiddytube.app.launcher.ImmersiveMode
import ae.kiddytube.app.sources.AndroidAppIdentity
import ae.kiddytube.app.sources.MediaUrlValidator
import ae.kiddytube.app.ui.ChannelGridActivity
import kotlinx.coroutines.launch

class ParentActivity : AppCompatActivity() {
    private enum class ParentTab {
        CHANNELS,
        SECURITY,
        HOME_SYNC
    }

    private lateinit var container: LinearLayout
    private lateinit var tabsRow: LinearLayout
    private lateinit var settings: CatalogSettings
    private var selectedTab: ParentTab = ParentTab.CHANNELS
    private val tabButtons = linkedMapOf<ParentTab, Button>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!requireActiveSession()) return
        setContentView(R.layout.activity_parent)
        container = findViewById(R.id.parentContent)
        tabsRow = findViewById(R.id.parentTabs)
        if (savedInstanceState != null) {
            selectedTab = ParentTab.entries.getOrElse(
                savedInstanceState.getInt(STATE_SELECTED_TAB, 0)
            ) { ParentTab.CHANNELS }
        }
        findViewById<TextView>(R.id.parentBack).setOnClickListener { goBackToChannels() }
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    goBackToChannels()
                }
            }
        )
        ImmersiveMode.apply(this)
        setupTabs()
        lifecycleScope.launch { reload() }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(STATE_SELECTED_TAB, selectedTab.ordinal)
    }

    private fun setupTabs() {
        tabsRow.removeAllViews()
        tabButtons.clear()
        val specs = listOf(
            ParentTab.CHANNELS to R.string.parent_tab_channels,
            ParentTab.SECURITY to R.string.parent_tab_security,
            ParentTab.HOME_SYNC to R.string.parent_tab_home_sync
        )
        specs.forEachIndexed { index, (tab, labelRes) ->
            val button = Button(this).apply {
                text = getString(labelRes)
                isAllCaps = false
                setBackgroundResource(R.drawable.focusable_tab_button)
                setTextColor(inkNavy())
                setTextSize(
                    TypedValue.COMPLEX_UNIT_PX,
                    resources.getDimension(R.dimen.parent_tab_text)
                )
                minHeight = resources.getDimensionPixelSize(R.dimen.parent_tab_min_height)
                setPadding(
                    resources.getDimensionPixelSize(R.dimen.parent_tab_padding_h),
                    resources.getDimensionPixelSize(R.dimen.parent_tab_padding_v),
                    resources.getDimensionPixelSize(R.dimen.parent_tab_padding_h),
                    resources.getDimensionPixelSize(R.dimen.parent_tab_padding_v)
                )
                isFocusable = true
                isFocusableInTouchMode = true
                setOnClickListener { selectTab(tab, requestFocusOnTab = true) }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).also {
                    if (index < specs.lastIndex) {
                        it.marginEnd = resources.getDimensionPixelSize(R.dimen.parent_tab_gap)
                    }
                }
            }
            tabButtons[tab] = button
            tabsRow.addView(button)
        }
        val buttons = tabButtons.values.toList()
        buttons.forEach { button ->
            if (button.id == android.view.View.NO_ID) {
                button.id = android.view.View.generateViewId()
            }
        }
        buttons.forEachIndexed { i, button ->
            if (i > 0) button.nextFocusLeftId = buttons[i - 1].id
            if (i < buttons.lastIndex) button.nextFocusRightId = buttons[i + 1].id
        }
        updateTabSelectionUi()
    }

    private fun selectTab(tab: ParentTab, requestFocusOnTab: Boolean = false) {
        if (!::settings.isInitialized) {
            selectedTab = tab
            updateTabSelectionUi()
            return
        }
        selectedTab = tab
        container.removeAllViews()
        render()
        updateTabSelectionUi()
        if (requestFocusOnTab) {
            tabButtons[tab]?.requestFocus()
        } else {
            focusFirstContentControl()
        }
    }

    private fun updateTabSelectionUi() {
        tabButtons.forEach { (tab, button) ->
            button.isSelected = tab == selectedTab
        }
    }

    private fun focusFirstContentControl() {
        container.post {
            val focusable = container.findFocusableInTouchModeDeep()
                ?: container.findFocusableDeep()
            focusable?.requestFocus()
        }
    }

    private fun View.findFocusableDeep(): View? {
        if (isFocusable && isShown) return this
        if (this is ViewGroup) {
            for (i in 0 until childCount) {
                val found = getChildAt(i).findFocusableDeep()
                if (found != null) return found
            }
        }
        return null
    }

    private fun View.findFocusableInTouchModeDeep(): View? {
        if (isFocusable && isFocusableInTouchMode && isShown && this is Button) return this
        if (this is ViewGroup) {
            for (i in 0 until childCount) {
                val found = getChildAt(i).findFocusableInTouchModeDeep()
                if (found != null) return found
            }
        }
        return null
    }

    private suspend fun reload() {
        if (!ParentSession.isActive()) {
            expireSession()
            return
        }
        settings = (application as KiddyTubeApp).catalogRepository.current()
        container.removeAllViews()
        render()
        updateTabSelectionUi()
        // Keep focus on the selected tab chip after mutations so D-pad stays predictable.
        tabButtons[selectedTab]?.requestFocus()
    }

    private fun render() {
        when (selectedTab) {
            ParentTab.CHANNELS -> renderChannelsTab()
            ParentTab.SECURITY -> renderSecurityTab()
            ParentTab.HOME_SYNC -> renderHomeSyncTab()
        }
        // Point tab nextFocusDown at first focusable in the panel.
        container.post {
            val first = container.findFocusableDeep()
            if (first != null && first.id == android.view.View.NO_ID) {
                first.id = android.view.View.generateViewId()
            }
            val firstId = first?.id ?: android.view.View.NO_ID
            tabButtons.values.forEach { tab ->
                tab.nextFocusDownId = firstId
            }
        }
    }

    private fun renderChannelsTab() {
        addHeading(getString(R.string.parent_section_channels))
        settings.channels.sortedBy { it.sortOrder }.forEach { addChannelCard(it) }
    }

    private fun renderSecurityTab() {
        addSectionCard {
            addSectionTitle(it, getString(R.string.parent_section_security))
            addButton(it, getString(R.string.parent_change_pin)) { promptChangePin() }
            val releaseOn = settings.releaseReady && settings.pinChangedFromDefault
            addToggle(
                it,
                if (releaseOn) {
                    getString(R.string.parent_release_ready_on)
                } else {
                    getString(R.string.parent_release_ready_off)
                }
            ) {
                if (!releaseOn && !settings.pinChangedFromDefault) {
                    toast(getString(R.string.parent_change_pin_first))
                    lifecycleScope.launch { reload() }
                    return@addToggle
                }
                update { s ->
                    s.copy(releaseReady = !releaseOn && s.pinChangedFromDefault)
                }
            }
            addButton(it, "Reset all settings") {
                AlertDialog.Builder(this)
                    .setTitle("Reset?")
                    .setMessage("Clears channels and PIN (re-seeded to default 2580).")
                    .setPositiveButton("Reset") { _, _ ->
                        withActiveSession {
                            val app = application as KiddyTubeApp
                            app.catalogRepository.resetAll()
                            app.clearRecentWatch()
                            val salt = ParentPinManager.newSaltHex()
                            val hash = ParentPinManager.hashPin(ParentPinManager.DEFAULT_DEV_PIN, salt)
                            app.catalogRepository.update { s ->
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

    private fun renderHomeSyncTab() {
        val totalVideos = settings.channels.sumOf { it.videos.size }
        addSectionCard {
            addSectionTitle(it, getString(R.string.parent_section_actions))
            val mixOn = settings.homeLibraryMode == HomeLibraryMode.MIX_VIDEOS
            addToggle(
                it,
                if (mixOn) {
                    getString(R.string.parent_home_mix_on)
                } else {
                    getString(R.string.parent_home_mix_off)
                }
            ) {
                update { s ->
                    s.copy(
                        homeLibraryMode = if (s.homeLibraryMode == HomeLibraryMode.MIX_VIDEOS) {
                            HomeLibraryMode.CHANNELS
                        } else {
                            HomeLibraryMode.MIX_VIDEOS
                        }
                    )
                }
            }
            addButton(it, getString(R.string.parent_set_api_key)) { promptApiKey() }
            addButton(it, getString(R.string.parent_refresh_playlists)) {
                withActiveSession {
                    val result =
                        (application as KiddyTubeApp).catalogRepository.refreshAllPlaylists(force = true)
                    toast(
                        when (result.status) {
                            SyncStatus.UPDATED ->
                                result.message?.takeIf { msg -> msg.isNotBlank() }
                                    ?: "Synced ${result.videoCount} videos in ${result.updatedChannels} channels"
                            SyncStatus.SKIPPED_NO_KEY ->
                                "Set a YouTube API key first"
                            SyncStatus.SKIPPED_OFFLINE ->
                                "Offline — try again when connected"
                            SyncStatus.FAILED ->
                                result.message ?: "Sync failed"
                            SyncStatus.SKIPPED_TTL ->
                                result.message
                                    ?: getString(R.string.sync_enable_follow_uploads)
                        }
                    )
                    reload()
                }
            }
            addButton(it, getString(R.string.parent_export_catalog)) {
                withActiveSession {
                    val json = (application as KiddyTubeApp).catalogRepository.exportJson()
                    val share = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, json)
                        putExtra(Intent.EXTRA_SUBJECT, "kids-catalog.json")
                    }
                    startActivity(Intent.createChooser(share, "Export catalog"))
                }
            }
            addButton(it, getString(R.string.parent_clear_continue_watching)) {
                AlertDialog.Builder(this)
                    .setTitle(R.string.parent_clear_continue_watching)
                    .setMessage(R.string.parent_clear_continue_watching_message)
                    .setPositiveButton(R.string.parent_clear_continue_watching) { _, _ ->
                        withActiveSession {
                            (application as KiddyTubeApp).clearRecentWatch()
                            toast(getString(R.string.parent_continue_watching_cleared))
                        }
                    }
                    .setNegativeButton(R.string.cancel, null)
                    .show()
            }
        }

        addSectionCard {
            addSectionTitle(it, getString(R.string.parent_section_overview))
            addInfo(it, "KiddyTube ${BuildConfig.VERSION_NAME}")
            addInfo(it, getString(R.string.parent_video_count, totalVideos))
            if (!settings.pinChangedFromDefault) {
                addInfo(it, getString(R.string.parent_default_pin_warning))
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
            val sha1 = AndroidAppIdentity.signingCertSha1Hex(this)
            addInfo(
                it,
                if (sha1.isNullOrBlank()) {
                    getString(R.string.parent_signing_sha1_unavailable)
                } else {
                    getString(R.string.parent_signing_sha1, sha1)
                }
            )
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
        addButtonRow(
            actions,
            Pair(
                if (channel.enabled) "Disable" else "Enable",
                {
                    update { s ->
                        s.copy(channels = s.channels.map {
                            if (it.id == channel.id) it.copy(enabled = !it.enabled) else it
                        })
                    }
                }
            ),
            "Playlist" to { promptPlaylist(channel) }
        )
        if (!channel.youtubePlaylistId.isNullOrBlank()) {
            addToggle(
                actions,
                if (channel.followUploads) {
                    getString(R.string.parent_follow_uploads_on)
                } else {
                    getString(R.string.parent_follow_uploads_off)
                }
            ) {
                withActiveSession {
                    (application as KiddyTubeApp).catalogRepository
                        .setFollowUploads(channel.id, !channel.followUploads)
                    reload()
                }
            }
        }
        addButtonRow(
            actions,
            "Video IDs" to { promptVideoIds(channel) },
            "Direct URL" to { promptDirect(channel) }
        )
        addButtonRow(
            actions,
            "Manage videos" to { promptManageVideos(channel) },
            "Refresh" to {
                withActiveSession {
                    val import = SyncPolicy.shouldImportPlaylist(
                        channel.followUploads,
                        channel.videos.size,
                        channel.suppressEmptyPlaylistImport
                    )
                    val r = (application as KiddyTubeApp).catalogRepository
                        .refreshChannelFromYoutube(channel.id, allowPlaylistImport = import)
                    toast(
                        r.fold(
                            onSuccess = { count ->
                                if (import) "Loaded $count"
                                else "Updated titles ($count) — Follow uploads is off"
                            },
                            onFailure = { it.message ?: "Failed" }
                        )
                    )
                    reload()
                }
            }
        )
        val seekOn = if (channel.videos.isEmpty()) {
            channel.defaultAllowSeek
        } else {
            channel.videos.all { it.allowSeek }
        }
        addToggle(
            actions,
            if (seekOn) {
                getString(R.string.parent_seek_on)
            } else {
                getString(R.string.parent_seek_off)
            }
        ) {
            withActiveSession {
                (application as KiddyTubeApp).catalogRepository
                    .setChannelAllowSeek(channel.id, !seekOn)
                reload()
            }
        }
        container.addView(card)
    }

    private fun promptManageVideos(channel: ContentChannel) {
        val videos = channel.videos
        if (videos.isEmpty()) {
            toast(getString(R.string.parent_no_videos))
            return
        }
        val labels = videos.map { v ->
            val tag = when {
                v.manual -> " [manual]"
                v.isDirect() -> " [direct]"
                else -> ""
            }
            (v.title.ifBlank { v.id }) + tag
        }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle(getString(R.string.parent_manage_videos))
            .setItems(labels) { _, which ->
                val video = videos[which]
                AlertDialog.Builder(this)
                    .setTitle(R.string.parent_remove_video_title)
                    .setMessage(video.title)
                    .setPositiveButton(R.string.parent_remove) { _, _ ->
                        withActiveSession {
                            (application as KiddyTubeApp).catalogRepository
                                .removeVideo(channel.id, video.id)
                            reload()
                        }
                    }
                    .setNegativeButton(R.string.cancel, null)
                    .show()
            }
            .setNeutralButton(R.string.parent_clear_synced) { _, _ ->
                AlertDialog.Builder(this)
                    .setTitle(R.string.parent_clear_synced)
                    .setMessage(R.string.parent_clear_synced_message)
                    .setPositiveButton(R.string.parent_clear_synced) { _, _ ->
                        withActiveSession {
                            (application as KiddyTubeApp).catalogRepository
                                .clearSyncedVideos(channel.id)
                            reload()
                        }
                    }
                    .setNegativeButton(R.string.cancel, null)
                    .show()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
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
                withActiveSession {
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
                withActiveSession {
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
            hint = "https://.../file.mp4 or .m3u8 (HTTPS path required)"
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
                    toast(getString(R.string.parent_invalid_direct_url))
                    return@setPositiveButton
                }
                withActiveSession {
                    try {
                        (application as KiddyTubeApp).catalogRepository.addDirectVideo(
                            channel.id,
                            title.text.toString(),
                            u
                        )
                        reload()
                    } catch (_: IllegalArgumentException) {
                        toast(getString(R.string.parent_invalid_direct_url))
                    }
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
            if (!ParentSession.isActive()) {
                expireSession()
                return@launch
            }
            (application as KiddyTubeApp).catalogRepository.update(transform)
            reload()
        }
    }

    /** Run a parent catalog mutation only while the PIN session is still valid. */
    private fun withActiveSession(block: suspend () -> Unit) {
        lifecycleScope.launch {
            if (!ParentSession.isActive()) {
                expireSession()
                return@launch
            }
            block()
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

    private fun addButtonRow(
        parent: ViewGroup,
        first: Pair<String, () -> Unit>,
        second: Pair<String, () -> Unit>
    ) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).also { it.topMargin = dp(8) }
        }
        fun half(pair: Pair<String, () -> Unit>, endMargin: Int = 0): Button =
            btn(pair.first, pair.second).apply {
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                ).also { it.marginEnd = endMargin }
            }
        row.addView(half(first, dp(6)))
        row.addView(half(second))
        parent.addView(row)
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

    private fun addToggle(parent: ViewGroup, label: String, onClick: () -> Unit) {
        parent.addView(
            btn(label, onClick).apply {
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).also { it.topMargin = dp(4) }
            }
        )
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
        startActivity(
            Intent(this, ChannelGridActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        )
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
        goBackToChannels()
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

    companion object {
        private const val STATE_SELECTED_TAB = "parent_selected_tab"
    }
}
