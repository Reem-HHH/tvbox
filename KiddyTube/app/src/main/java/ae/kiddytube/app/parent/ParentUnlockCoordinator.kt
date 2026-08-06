package ae.kiddytube.app.parent

import android.content.Intent
import android.text.InputType
import android.widget.EditText
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import ae.kiddytube.app.KiddyTubeApp
import ae.kiddytube.app.R
import kotlinx.coroutines.launch

/**
 * Shared PIN dialog used by channel home and video library (touch + TV).
 */
class ParentUnlockCoordinator(
    private val activity: AppCompatActivity,
    private var pinManager: ParentPinManager
) {
    fun updatePinManager(manager: ParentPinManager) {
        pinManager = manager
    }

    fun beginParentAccess() {
        val now = System.currentTimeMillis()
        pinManager.refreshLockout(now)
        if (pinManager.isLockedOut(now)) {
            Toast.makeText(activity, R.string.parent_locked_out, Toast.LENGTH_SHORT).show()
            return
        }
        val input = EditText(activity).apply {
            inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD
            hint = activity.getString(R.string.parent_pin_title)
        }
        AlertDialog.Builder(activity)
            .setTitle(R.string.parent_pin_title)
            .setView(input)
            .setPositiveButton(R.string.unlock) { dialog, _ ->
                val pin = input.text.toString()
                activity.lifecycleScope.launch {
                    val repo = (activity.application as KiddyTubeApp).catalogRepository
                    val latest = repo.current()
                    if (pinManager.verifyPin(pin, latest.pinSalt, latest.pinHash)) {
                        pinManager.registerSuccess()
                        repo.update { it.copy(failCount = 0, lockedUntilMs = 0L) }
                        dialog.dismiss()
                        activity.startActivity(Intent(activity, ParentActivity::class.java))
                    } else {
                        val locked = pinManager.registerFailure(System.currentTimeMillis())
                        repo.update {
                            it.copy(
                                failCount = pinManager.failureCount,
                                lockedUntilMs = pinManager.lockedUntilMs
                            )
                        }
                        if (locked) {
                            dialog.dismiss()
                            Toast.makeText(activity, R.string.parent_locked_out, Toast.LENGTH_SHORT)
                                .show()
                        }
                    }
                }
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }
}
