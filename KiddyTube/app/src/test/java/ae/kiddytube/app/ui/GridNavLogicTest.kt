package ae.kiddytube.app.ui

import android.view.View
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GridNavLogicTest {

    @Test
    fun downAdvancesBySpan() {
        assertEquals(5, GridNavLogic.targetAdapterPosition(2, View.FOCUS_DOWN, 3, 20))
        assertEquals(17, GridNavLogic.targetAdapterPosition(17, View.FOCUS_DOWN, 3, 20))
    }

    @Test
    fun upLeavesFromFirstRow() {
        assertNull(GridNavLogic.targetAdapterPosition(1, View.FOCUS_UP, 3, 20))
        assertEquals(1, GridNavLogic.targetAdapterPosition(4, View.FOCUS_UP, 3, 20))
    }

    @Test
    fun leftRightStayOrStep() {
        assertEquals(0, GridNavLogic.targetAdapterPosition(0, View.FOCUS_LEFT, 3, 20))
        assertEquals(1, GridNavLogic.targetAdapterPosition(0, View.FOCUS_RIGHT, 3, 20))
        assertEquals(19, GridNavLogic.targetAdapterPosition(19, View.FOCUS_RIGHT, 3, 20))
    }
}
