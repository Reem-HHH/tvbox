package ae.kiddytube.app.ui

import ae.kiddytube.app.catalog.PlayableVideo
import ae.kiddytube.app.catalog.youtubeThumbnail
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import ae.kiddytube.app.R

class VideoGridAdapter(
    private val onClick: (PlayableVideo) -> Unit
) : RecyclerView.Adapter<VideoGridAdapter.Holder>() {

    private val items = mutableListOf<PlayableVideo>()

    /** Synchronous DiffUtil so [GridFocus] restore after submit still sees the new list. */
    fun submit(list: List<PlayableVideo>) {
        val newItems = list.toList()
        val diff = DiffUtil.calculateDiff(VideoDiff(items, newItems))
        items.clear()
        items.addAll(newItems)
        diff.dispatchUpdatesTo(this)
    }

    fun indexOfVideoId(videoId: String): Int =
        items.indexOfFirst { it.video.id == videoId }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_video_tile, parent, false)
        return Holder(view)
    }

    override fun onBindViewHolder(holder: Holder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    inner class Holder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val thumb: ImageView = itemView.findViewById(R.id.videoThumb)
        private val title: TextView = itemView.findViewById(R.id.videoTitle)
        private val cornerPx =
            itemView.resources.getDimension(R.dimen.tile_corner)

        init {
            ThumbOutline.apply(thumb, cornerPx)
        }

        fun bind(item: PlayableVideo) {
            val video = item.video
            title.text = video.title
            itemView.contentDescription =
                itemView.context.getString(R.string.a11y_video_tile, video.title)
            val url = video.youtubeThumbnail() ?: video.thumbnailUrl
            if (url != null) {
                TileImageLoad.loadUrl(thumb, url, R.drawable.tile_placeholder)
            } else {
                TileImageLoad.clear(thumb)
            }
            itemView.setOnClickListener { onClick(item) }
            itemView.setOnFocusChangeListener { v, hasFocus ->
                TileFocusAnim.apply(v, hasFocus)
            }
        }
    }

    private class VideoDiff(
        private val old: List<PlayableVideo>,
        private val new: List<PlayableVideo>
    ) : DiffUtil.Callback() {
        override fun getOldListSize(): Int = old.size
        override fun getNewListSize(): Int = new.size
        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            val a = old[oldItemPosition]
            val b = new[newItemPosition]
            return a.channelId == b.channelId && a.video.id == b.video.id
        }
        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            val a = old[oldItemPosition].video
            val b = new[newItemPosition].video
            return a.title == b.title &&
                a.thumbnailUrl == b.thumbnailUrl &&
                a.youtubeVideoId == b.youtubeVideoId
        }
    }
}
