package ae.kiddytube.app.ui

import ae.kiddytube.app.catalog.RecentWatchItem
import ae.kiddytube.app.catalog.youtubeThumbnail
import ae.kiddytube.app.catalog.VideoItem
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

class ContinueWatchAdapter(
    private val onClick: (RecentWatchItem, VideoItem) -> Unit
) : RecyclerView.Adapter<ContinueWatchAdapter.Holder>() {

    private val items = mutableListOf<Pair<RecentWatchItem, VideoItem>>()

    fun submit(list: List<Pair<RecentWatchItem, VideoItem>>) {
        val newItems = list.toList()
        val diff = DiffUtil.calculateDiff(ContinueDiff(items, newItems))
        items.clear()
        items.addAll(newItems)
        diff.dispatchUpdatesTo(this)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_continue_watch_tile, parent, false)
        return Holder(view)
    }

    override fun onBindViewHolder(holder: Holder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    inner class Holder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val thumb: ImageView = itemView.findViewById(R.id.videoThumb)
        private val title: TextView = itemView.findViewById(R.id.videoTitle)
        private val cornerPx = itemView.resources.getDimension(R.dimen.image_corner)

        fun bind(pair: Pair<RecentWatchItem, VideoItem>) {
            val (recent, video) = pair
            title.text = video.title
            itemView.contentDescription =
                itemView.context.getString(R.string.a11y_continue_watch_tile, video.title)
            val url = video.youtubeThumbnail() ?: video.thumbnailUrl ?: recent.thumbnailUrl
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
            itemView.setOnClickListener { onClick(recent, video) }
            itemView.setOnFocusChangeListener { v, hasFocus ->
                TileFocusAnim.apply(v, hasFocus)
            }
        }
    }

    private class ContinueDiff(
        private val old: List<Pair<RecentWatchItem, VideoItem>>,
        private val new: List<Pair<RecentWatchItem, VideoItem>>
    ) : DiffUtil.Callback() {
        override fun getOldListSize(): Int = old.size
        override fun getNewListSize(): Int = new.size
        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
            old[oldItemPosition].second.id == new[newItemPosition].second.id
        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
            old[oldItemPosition].second == new[newItemPosition].second &&
                old[oldItemPosition].first.watchedAtMs == new[newItemPosition].first.watchedAtMs
    }
}
