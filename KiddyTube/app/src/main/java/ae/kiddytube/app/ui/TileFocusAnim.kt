package ae.kiddytube.app.ui

import android.view.View
import androidx.core.view.ViewCompat

/** Shared TV focus motion so tiles read clearly at 10-foot distance. */
object TileFocusAnim {
    private const val FOCUSED_SCALE = 1.08f
    private const val FOCUSED_LIFT_Y = -8f
    private const val FOCUSED_Z = 24f
    private const val DURATION_MS = 140L

    fun apply(view: View, hasFocus: Boolean) {
        if (hasFocus) {
            view.bringToFront()
            (view.parent as? View)?.invalidate()
        }
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
