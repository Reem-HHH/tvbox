package ae.kiddytube.app.ui

import android.content.Context
import android.view.View
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView

/**
 * Grid layout that routes D-pad focus by adapter index/row instead of screen geometry.
 * Fixes Mix/home rows where scaled tiles make Down jump sideways or up.
 */
class TvGridLayoutManager(
    context: Context,
    spanCount: Int
) : GridLayoutManager(context, spanCount) {

    override fun onInterceptFocusSearch(focused: View, direction: Int): View? {
        val recycler = focused.parent as? RecyclerView
            ?: return super.onInterceptFocusSearch(focused, direction)
        val position = recycler.getChildAdapterPosition(focused)
        val count = recycler.adapter?.itemCount ?: 0
        val target = GridNavLogic.targetAdapterPosition(
            position = position,
            direction = direction,
            spanCount = spanCount,
            itemCount = count
        )
        if (target == null) {
            // Leave the grid (typically Up from the first row).
            return null
        }
        if (target == position) {
            // Absorb edge presses so focus does not flee to chrome / random siblings.
            return focused
        }
        val bound = recycler.findViewHolderForAdapterPosition(target)?.itemView
        if (bound != null) {
            return bound
        }
        // Off-screen: scroll, then focus after layout.
        recycler.scrollToPosition(target)
        recycler.post {
            recycler.findViewHolderForAdapterPosition(target)?.itemView?.requestFocus()
        }
        return focused
    }

    override fun onFocusSearchFailed(
        focused: View,
        focusDirection: Int,
        recycler: RecyclerView.Recycler,
        state: RecyclerView.State
    ): View? {
        val position = getPosition(focused)
        val count = state.itemCount
        val target = GridNavLogic.targetAdapterPosition(
            position = position,
            direction = focusDirection,
            spanCount = spanCount,
            itemCount = count
        ) ?: return super.onFocusSearchFailed(focused, focusDirection, recycler, state)

        if (target == position) return focused

        scrollToPosition(target)
        val host = focused.parent as? RecyclerView
        host?.post {
            findViewByPosition(target)?.requestFocus()
                ?: host.findViewHolderForAdapterPosition(target)?.itemView?.requestFocus()
        }
        return focused
    }
}
