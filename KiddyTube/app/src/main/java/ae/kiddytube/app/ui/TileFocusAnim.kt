package ae.kiddytube.app.ui

import android.view.View
import androidx.core.view.ViewCompat

/**
 * Shared TV focus motion so tiles read clearly at 10-foot distance.
 * Avoid bringToFront + large scale: those break geometric focus search and cause
 * D-pad Down to jump sideways/up on Mix grids.
 */
object TileFocusAnim {
    private const val FOCUSED_SCALE = 1.05f
    private const val FOCUSED_LIFT_Y = -4f
    private const val FOCUSED_Z = 12f
    private const val DURATION_MS = 120L

    fun apply(view: View, hasFocus: Boolean) {
        view.animate().cancel()
        val scale = if (hasFocus) FOCUSED_SCALE else 1f
        val ty = if (hasFocus) FOCUSED_LIFT_Y else 0f
        val z = if (hasFocus) FOCUSED_Z else 0f
        ViewCompat.setTranslationZ(view, z)
        view.animate()
            .scaleX(scale)
            .scaleY(scale)
            .translationY(ty)
            .setDuration(DURATION_MS)
            .start()
    }
}
