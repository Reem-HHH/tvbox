package ae.kiddytube.app.ui

import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView

/** Preserve D-pad focus across notifyDataSetChanged-style list rebinds. */
object GridFocus {
    fun capturePosition(grid: RecyclerView): Int {
        val focused = grid.findFocus() ?: return RecyclerView.NO_POSITION
        val holder = grid.findContainingViewHolder(focused) ?: return RecyclerView.NO_POSITION
        return holder.bindingAdapterPosition
    }

    fun restore(grid: RecyclerView, position: Int, fallbackToFirst: Boolean = true) {
        grid.post {
            if (position != RecyclerView.NO_POSITION) {
                val holder = grid.findViewHolderForAdapterPosition(position)
                if (holder?.itemView?.requestFocus() == true) return@post
                grid.scrollToPosition(position)
                grid.post {
                    grid.findViewHolderForAdapterPosition(position)?.itemView?.requestFocus()
                }
                return@post
            }
            if (fallbackToFirst && (grid.adapter?.itemCount ?: 0) > 0) {
                focusFirst(grid)
            }
        }
    }

    fun focusFirst(grid: RecyclerView) {
        grid.post {
            if ((grid.adapter?.itemCount ?: 0) <= 0) return@post
            val holder = grid.findViewHolderForAdapterPosition(0)
            if (holder?.itemView?.requestFocus() == true) return@post
            grid.scrollToPosition(0)
            grid.post {
                grid.findViewHolderForAdapterPosition(0)?.itemView?.requestFocus()
                    ?: grid.requestFocus()
            }
        }
    }

    fun requestGridDefault(grid: RecyclerView) {
        grid.isFocusable = true
        grid.isFocusableInTouchMode = false
        grid.descendantFocusability = ViewGroup.FOCUS_AFTER_DESCENDANTS
        focusFirst(grid)
    }
}
