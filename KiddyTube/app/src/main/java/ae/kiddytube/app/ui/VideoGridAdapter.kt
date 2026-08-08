package ae.kiddytube.app.ui

import ae.kiddytube.app.catalog.VideoItem
import ae.kiddytube.app.catalog.youtubeThumbnail
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import ae.kiddytube.app.R
import coil.load
import coil.transform.RoundedCornersTransformation

class VideoGridAdapter(
    private val onClick: (VideoItem) -> Unit
) : RecyclerView.Adapter<VideoGridAdapter.Holder>() {

    private val items = mutableListOf<VideoItem>()

    /** Synchronous DiffUtil so [GridFocus] restore after submit still sees the new list. */
    fun submit(list: List<VideoItem>) {
        val newItems = list.toList()
        val diff = DiffUtil.calculateDiff(VideoDiff(items, newItems))
        items.clear()
        items.addAll(newItems)
        diff.dispatchUpdatesTo(this)
    }

    fun indexOfVideoId(videoId: String): Int =
        items.indexOfFirst { it.id == videoId }

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
            itemView.resources.getDimension(R.dimen.image_corner)

        fun bind(video: VideoItem) {
            title.text = video.title
            itemView.contentDescription =
                itemView.context.getString(R.string.a11y_video_tile, video.title)
            val url = video.youtubeThumbnail() ?: video.thumbnailUrl
            if (url != null) {
                thumb.load(url) {
                    crossfade(true)
                    placeholder(R.drawable.tile_placeholder)
                    error(R.drawable.tile_placeholder)
                    transformations(RoundedCornersTransformation(cornerPx))
                }
            } else {
                thumb.setImageResource(R.drawable.tile_placeholder)
            }
            itemView.setOnClickListener { onClick(video) }
            itemView.setOnFocusChangeListener { v, hasFocus ->
                TileFocusAnim.apply(v, hasFocus)
            }
        }
    }

    private class VideoDiff(
        private val old: List<VideoItem>,
        private val new: List<VideoItem>
    ) : DiffUtil.Callback() {
        override fun getOldListSize(): Int = old.size
        override fun getNewListSize(): Int = new.size
        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
            old[oldItemPosition].id == new[newItemPosition].id
        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
            old[oldItemPosition] == new[newItemPosition]
    }
}
