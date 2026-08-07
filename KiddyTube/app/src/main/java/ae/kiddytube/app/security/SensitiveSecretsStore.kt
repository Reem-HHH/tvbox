package ae.kiddytube.app.security

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

/** Reads/writes API key and PIN salt/hash via AndroidX EncryptedSharedPreferences. */
interface SensitiveSecretsStore {
    fun read(): SensitiveSecrets
    fun write(secrets: SensitiveSecrets)
    fun clear()
}

class EncryptedSensitiveSecretsStore(
    context: Context
) : SensitiveSecretsStore {
    private val appContext = context.applicationContext

    private val prefs: SharedPreferences by lazy {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        EncryptedSharedPreferences.create(
            PREFS_NAME,
            masterKeyAlias,
            appContext,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    override fun read(): SensitiveSecrets = SensitiveSecrets(
        youtubeApiKey = prefs.getString(KEY_API, null)?.ifBlank { null },
        pinSalt = prefs.getString(KEY_SALT, null)?.ifBlank { null },
        pinHash = prefs.getString(KEY_HASH, null)?.ifBlank { null }
    )

    override fun write(secrets: SensitiveSecrets) {
        prefs.edit()
            .putString(KEY_API, secrets.youtubeApiKey.orEmpty())
            .putString(KEY_SALT, secrets.pinSalt.orEmpty())
            .putString(KEY_HASH, secrets.pinHash.orEmpty())
            .apply()
    }

    override fun clear() {
        prefs.edit().clear().apply()
    }

    /**
     * One-shot read of a legacy plaintext SharedPreferences file with the same key names
     * (no-op if the file was never created).
     */
    fun readLegacyPlainSharedPrefs(): SensitiveSecrets {
        val plain = appContext.getSharedPreferences(LEGACY_PLAIN_PREFS, Context.MODE_PRIVATE)
        return SensitiveSecrets(
            youtubeApiKey = plain.getString(KEY_API, null)?.ifBlank { null },
            pinSalt = plain.getString(KEY_SALT, null)?.ifBlank { null },
            pinHash = plain.getString(KEY_HASH, null)?.ifBlank { null }
        )
    }

    fun clearLegacyPlainSharedPrefs() {
        appContext.getSharedPreferences(LEGACY_PLAIN_PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }

    companion object {
        const val PREFS_NAME = "kids_sensitive"
        const val LEGACY_PLAIN_PREFS = "kids_sensitive_plain"
        const val KEY_API = "youtube_api_key"
        const val KEY_SALT = "pin_salt"
        const val KEY_HASH = "pin_hash"
    }
}
