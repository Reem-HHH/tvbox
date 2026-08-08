package ae.kiddytube.app.ui

import android.graphics.Outline
import android.view.View
import android.view.ViewOutlineProvider

/** Round-rect outline so ImageView thumbs clip to the same radius as Coil transforms. */
object ThumbOutline {
    fun apply(view: View, cornerPx: Float) {
        view.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(v: View, outline: Outline) {
                outline.setRoundRect(0, 0, v.width, v.height, cornerPx)
            }
        }
        view.clipToOutline = true
        if (view.width == 0 || view.height == 0) {
            view.addOnLayoutChangeListener(object : View.OnLayoutChangeListener {
                override fun onLayoutChange(
                    v: View,
                    left: Int,
                    top: Int,
                    right: Int,
                    bottom: Int,
                    oldLeft: Int,
                    oldTop: Int,
                    oldRight: Int,
                    oldBottom: Int
                ) {
                    v.removeOnLayoutChangeListener(this)
                    v.invalidateOutline()
                }
            })
        } else {
            view.invalidateOutline()
        }
    }
}
