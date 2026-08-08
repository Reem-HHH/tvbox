package ae.kiddytube.app.ui

import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView

/** Preserve D-pad focus across list rebinds (DiffUtil / dataset updates). */
object GridFocus {
    fun capturePosition(grid: RecyclerView): Int {
        val focused = grid.findFocus() ?: return RecyclerView.NO_POSITION
        val holder = grid.findContainingViewHolder(focused) ?: return RecyclerView.NO_POSITION
        return holder.bindingAdapterPosition
    }

    fun restore(grid: RecyclerView, position: Int, fallbackToFirst: Boolean = true) {
        if (position == RecyclerView.NO_POSITION) {
            if (fallbackToFirst && (grid.adapter?.itemCount ?: 0) > 0) {
                focusFirst(grid)
            }
            return
        }
        val count = grid.adapter?.itemCount ?: 0
        if (position < 0 || position >= count) {
            if (fallbackToFirst && count > 0) focusFirst(grid)
            return
        }
        grid.post {
            // Bring the row into view first so D-pad focus doesn't land off-screen.
            grid.scrollToPosition(position)
            grid.post {
                val holder = grid.findViewHolderForAdapterPosition(position)
                if (holder?.itemView?.requestFocus() == true) return@post
                grid.post {
                    grid.findViewHolderForAdapterPosition(position)?.itemView?.requestFocus()
                        ?: if (fallbackToFirst) focusFirst(grid) else Unit
                }
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
