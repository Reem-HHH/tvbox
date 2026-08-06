package ae.kidstv.launcher.ui

import android.content.Intent
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import ae.kidstv.launcher.KidsTvApp
import ae.kidstv.launcher.R
import ae.kidstv.launcher.catalog.VideoItem
import ae.kidstv.launcher.launcher.ImmersiveMode
import ae.kidstv.launcher.parent.ParentPinManager
import ae.kidstv.launcher.player.PlayerActivity
import ae.kidstv.launcher.remote.RemoteAction
import ae.kidstv.launcher.remote.RemoteKeyHandler
import kotlinx.coroutines.launch

class VideoLibraryActivity : AppCompatActivity() {
    private lateinit var grid: RecyclerView
    private lateinit var emptyMessage: TextView
    private lateinit var adapter: VideoGridAdapter
    private lateinit var remote: RemoteKeyHandler
    private var channelId: String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_grid)
        channelId = intent.getStringExtra(EXTRA_CHANNEL_ID).orEmpty()
        title = intent.getStringExtra(EXTRA_CHANNEL_TITLE)

        grid = findViewById(R.id.grid)
        emptyMessage = findViewById(R.id.emptyMessage)
        remote = RemoteKeyHandler(
            ParentPinManager(),
            getSystemService(AUDIO_SERVICE) as AudioManager
        )

        adapter = VideoGridAdapter { video -> openPlayer(video) }
        grid.adapter = adapter
        grid.layoutManager = GridLayoutManager(this, spanCount())
        ImmersiveMode.apply(this)
        reload()
    }

    private fun spanCount(): Int {
        val uiMode = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
        val isTv = uiMode == Configuration.UI_MODE_TYPE_TELEVISION
        val widthDp = resources.configuration.screenWidthDp
        return when {
            isTv || widthDp >= 900 -> 5
            widthDp >= 600 -> 3
            else -> 2
        }
    }

    private fun reload() {
        lifecycleScope.launch {
            val channel = (application as KidsTvApp).catalogRepository.channelById(channelId)
            val videos = channel?.videos.orEmpty()
            adapter.submit(videos)
            emptyMessage.visibility = if (videos.isEmpty()) View.VISIBLE else View.GONE
            emptyMessage.text =
                "No videos yet.\nAsk a parent to add a YouTube playlist or video links."
        }
    }

    private fun openPlayer(video: VideoItem) {
        startActivity(
            Intent(this, PlayerActivity::class.java)
                .putExtra(PlayerActivity.EXTRA_TITLE, video.title)
                .putExtra(PlayerActivity.EXTRA_YOUTUBE_ID, video.youtubeVideoId)
                .putExtra(PlayerActivity.EXTRA_DIRECT_URL, video.directUrl)
        )
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_UP) {
            remote.handleKeyUp(event.keyCode)
        }
        if (event.action == KeyEvent.ACTION_DOWN && event.keyCode == KeyEvent.KEYCODE_BACK) {
            val action = remote.handleKeyDown(event.keyCode, event)
            if (action is RemoteAction.NavigateBack || action is RemoteAction.Consume) {
                finish()
                return true
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
