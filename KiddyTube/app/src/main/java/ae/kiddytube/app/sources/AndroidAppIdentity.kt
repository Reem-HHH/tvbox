package ae.kiddytube.app.sources

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest

/**
 * Values Google expects for Android-restricted API keys when calling APIs over plain HTTPS.
 */
object AndroidAppIdentity {
    fun sha1HexLower(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-1").digest(bytes)
        return buildString(digest.size * 2) {
            for (b in digest) {
                append("%02x".format(b.toInt() and 0xff))
            }
        }
    }

    fun signingCertSha1Hex(context: Context): String? {
        return try {
            val pm = context.packageManager
            val packageName = context.packageName
            val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                val signingInfo = info.signingInfo ?: return null
                val signers = if (signingInfo.hasMultipleSigners()) {
                    signingInfo.apkContentsSigners
                } else {
                    signingInfo.signingCertificateHistory
                }
                signers?.firstOrNull()
            } else {
                @Suppress("DEPRECATION")
                val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                info.signatures?.firstOrNull()
            } ?: return null
            sha1HexLower(signature.toByteArray())
        } catch (_: Exception) {
            null
        }
    }
}
