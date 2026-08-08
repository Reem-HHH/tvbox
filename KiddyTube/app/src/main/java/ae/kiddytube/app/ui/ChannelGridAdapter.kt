package ae.kiddytube.app.ui

import ae.kiddytube.app.catalog.ContentChannel
import ae.kiddytube.app.catalog.newestOrNull
import ae.kiddytube.app.catalog.youtubeThumbnail
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import ae.kiddytube.app.R

class ChannelGridAdapter(
    private val onClick: (ContentChannel) -> Unit
) : RecyclerView.Adapter<ChannelGridAdapter.Holder>() {

    private val items = mutableListOf<ContentChannel>()

    /** Synchronous DiffUtil so [GridFocus] restore after submit still sees the new list. */
    fun submit(list: List<ContentChannel>) {
        val newItems = list.toList()
        val diff = DiffUtil.calculateDiff(ChannelDiff(items, newItems))
        items.clear()
        items.addAll(newItems)
        diff.dispatchUpdatesTo(this)
    }

    fun indexOfChannelId(channelId: String): Int =
        items.indexOfFirst { it.id == channelId }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_channel_tile, parent, false)
        return Holder(view)
    }

    override fun onBindViewHolder(holder: Holder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    inner class Holder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val icon: ImageView = itemView.findViewById(R.id.channelIcon)
        private val title: TextView = itemView.findViewById(R.id.channelTitle)
        private val cornerPx =
            itemView.resources.getDimension(R.dimen.tile_corner)

        init {
            ThumbOutline.apply(icon, cornerPx)
        }

        fun bind(channel: ContentChannel) {
            title.text = channel.title
            itemView.contentDescription =
                itemView.context.getString(R.string.a11y_channel_tile, channel.title)
            val iconRes = channel.resolvedIconRes()
            val preview = channel.videos.newestOrNull()?.youtubeThumbnail()
            if (preview != null) {
                TileImageLoad.loadUrl(icon, preview, iconRes)
            } else {
                TileImageLoad.loadRes(icon, iconRes)
            }
            itemView.setOnClickListener { onClick(channel) }
            itemView.setOnFocusChangeListener { v, hasFocus ->
                TileFocusAnim.apply(v, hasFocus)
            }
        }
    }

    private class ChannelDiff(
        private val old: List<ContentChannel>,
        private val new: List<ContentChannel>
    ) : DiffUtil.Callback() {
        override fun getOldListSize(): Int = old.size
        override fun getNewListSize(): Int = new.size
        override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
            old[oldItemPosition].id == new[newItemPosition].id

        override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean {
            val a = old[oldItemPosition]
            val b = new[newItemPosition]
            // Display fields only — ignore full videos list so playlist sync does not rebind every tile.
            return a.title == b.title &&
                a.iconRes == b.iconRes &&
                a.enabled == b.enabled &&
                previewVideoId(a) == previewVideoId(b)
        }

        private fun previewVideoId(channel: ContentChannel): String? =
            channel.videos.newestOrNull()?.let { it.youtubeVideoId ?: it.id }
    }
}
