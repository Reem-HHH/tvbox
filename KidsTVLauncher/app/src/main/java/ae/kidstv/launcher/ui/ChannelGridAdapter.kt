package ae.kidstv.launcher.ui

import ae.kidstv.launcher.catalog.ContentChannel
import ae.kidstv.launcher.catalog.youtubeThumbnail
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import ae.kidstv.launcher.R
import coil.load

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

        fun bind(channel: ContentChannel) {
            title.text = channel.title
            val preview = channel.videos.firstOrNull()?.youtubeThumbnail()
            if (preview != null) {
                icon.load(preview) {
                    crossfade(true)
                    placeholder(channel.iconRes)
                    error(channel.iconRes)
                }
            } else {
                icon.setImageResource(channel.iconRes)
            }
            itemView.setOnClickListener { onClick(channel) }
        }
    }
}
