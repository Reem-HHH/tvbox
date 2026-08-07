package ae.kiddytube.app.security

/** Parent API key and PIN material that must not sit in plaintext DataStore. */
data class SensitiveSecrets(
    val youtubeApiKey: String? = null,
    val pinSalt: String? = null,
    val pinHash: String? = null
) {
    fun isEmpty(): Boolean =
        youtubeApiKey.isNullOrBlank() && pinSalt.isNullOrBlank() && pinHash.isNullOrBlank()
}

/**
 * Pure merge of encrypted vs leftover plaintext secrets.
 * Prefer non-blank encrypted fields; fill gaps from plain; report write/clear actions.
 */
object SensitiveSecretsMigrator {
    data class Result(
        val secrets: SensitiveSecrets,
        val writeEncrypted: Boolean,
        val clearPlain: Boolean
    )

    fun migrate(encrypted: SensitiveSecrets, plain: SensitiveSecrets): Result {
        fun pick(enc: String?, plainValue: String?): Pair<String?, Boolean> {
            val e = enc?.ifBlank { null }
            val p = plainValue?.ifBlank { null }
            return when {
                e != null -> e to false
                p != null -> p to true
                else -> null to false
            }
        }

        val (apiKey, apiFromPlain) = pick(encrypted.youtubeApiKey, plain.youtubeApiKey)
        val (salt, saltFromPlain) = pick(encrypted.pinSalt, plain.pinSalt)
        val (hash, hashFromPlain) = pick(encrypted.pinHash, plain.pinHash)
        val fromPlain = apiFromPlain || saltFromPlain || hashFromPlain
        val plainHadData = !plain.isEmpty()

        return Result(
            secrets = SensitiveSecrets(
                youtubeApiKey = apiKey,
                pinSalt = salt,
                pinHash = hash
            ),
            writeEncrypted = fromPlain,
            clearPlain = plainHadData
        )
    }
}
