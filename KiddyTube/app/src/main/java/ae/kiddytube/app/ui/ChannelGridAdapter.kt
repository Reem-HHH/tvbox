package ae.kiddytube.app.ui

import ae.kiddytube.app.catalog.ContentChannel
import ae.kiddytube.app.catalog.youtubeThumbnail
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import ae.kiddytube.app.R
import coil.load
import coil.transform.RoundedCornersTransformation

class ChannelGridAdapter(
    private val onClick: (ContentChannel) -> Unit
) : RecyclerView.Adapter<ChannelGridAdapter.Holder>() {

    private val items = mutableListOf<ContentChannel>()

    fun submit(list: List<ContentChannel>) {
        items.clear()
        items.addAll(list)
        notifyDataSetChanged()
    }

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
        private val cornerPx = itemView.resources.displayMetrics.density * 14f

        fun bind(channel: ContentChannel) {
            title.text = channel.title
            val preview = channel.videos.firstOrNull()?.youtubeThumbnail()
            if (preview != null) {
                icon.load(preview) {
                    crossfade(true)
                    placeholder(channel.iconRes)
                    error(channel.iconRes)
                    transformations(RoundedCornersTransformation(cornerPx))
                }
            } else {
                icon.load(channel.iconRes) {
                    transformations(RoundedCornersTransformation(cornerPx))
                }
            }
            itemView.setOnClickListener { onClick(channel) }
            itemView.setOnFocusChangeListener { v, hasFocus ->
                val scale = if (hasFocus) 1.08f else 1f
                v.animate().scaleX(scale).scaleY(scale).setDuration(120).start()
            }
        }
    }
}
