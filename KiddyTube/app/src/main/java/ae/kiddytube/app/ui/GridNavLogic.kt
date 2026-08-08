package ae.kiddytube.app.ui

import android.view.View

/**
 * Pure adapter-index navigation for a fixed-span grid.
 * Used by [TvGridLayoutManager] so D-pad Down always advances by one row even when
 * focused tiles are scaled/elevated and confuse Android's geometric FocusFinder.
 */
object GridNavLogic {
    /**
     * @return adapter position to focus, or null to let the framework search outside
     * the RecyclerView (e.g. Up from the first row toward Continue Watching / header).
     */
    fun targetAdapterPosition(
        position: Int,
        direction: Int,
        spanCount: Int,
        itemCount: Int
    ): Int? {
        if (position < 0 || position >= itemCount || spanCount <= 0 || itemCount <= 0) {
            return null
        }
        return when (direction) {
            View.FOCUS_DOWN -> {
                val next = position + spanCount
                if (next < itemCount) next else position
            }
            View.FOCUS_UP -> {
                val prev = position - spanCount
                if (prev >= 0) prev else null
            }
            View.FOCUS_RIGHT -> {
                if (position + 1 < itemCount) position + 1 else position
            }
            View.FOCUS_LEFT -> {
                if (position > 0) position - 1 else position
            }
            else -> null
        }
    }
}
