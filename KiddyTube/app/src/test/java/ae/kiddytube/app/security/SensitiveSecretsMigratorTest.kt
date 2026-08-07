package ae.kiddytube.app.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SensitiveSecretsMigratorTest {
    @Test
    fun prefersEncryptedWhenPresent() {
        val result = SensitiveSecretsMigrator.migrate(
            encrypted = SensitiveSecrets("enc-key", "enc-salt", "enc-hash"),
            plain = SensitiveSecrets("plain-key", "plain-salt", "plain-hash")
        )
        assertEquals("enc-key", result.secrets.youtubeApiKey)
        assertEquals("enc-salt", result.secrets.pinSalt)
        assertEquals("enc-hash", result.secrets.pinHash)
        assertFalse(result.writeEncrypted)
        assertTrue(result.clearPlain)
    }

    @Test
    fun migratesPlainWhenEncryptedEmpty() {
        val result = SensitiveSecretsMigrator.migrate(
            encrypted = SensitiveSecrets(),
            plain = SensitiveSecrets("plain-key", "salt", "hash")
        )
        assertEquals("plain-key", result.secrets.youtubeApiKey)
        assertEquals("salt", result.secrets.pinSalt)
        assertEquals("hash", result.secrets.pinHash)
        assertTrue(result.writeEncrypted)
        assertTrue(result.clearPlain)
    }

    @Test
    fun fillsGapsFromPlainPerField() {
        val result = SensitiveSecretsMigrator.migrate(
            encrypted = SensitiveSecrets(youtubeApiKey = "enc-key"),
            plain = SensitiveSecrets(pinSalt = "salt", pinHash = "hash")
        )
        assertEquals("enc-key", result.secrets.youtubeApiKey)
        assertEquals("salt", result.secrets.pinSalt)
        assertEquals("hash", result.secrets.pinHash)
        assertTrue(result.writeEncrypted)
        assertTrue(result.clearPlain)
    }

    @Test
    fun blankStringsTreatedAsAbsent() {
        val result = SensitiveSecretsMigrator.migrate(
            encrypted = SensitiveSecrets("  ", "", null),
            plain = SensitiveSecrets("key", "salt", "hash")
        )
        assertEquals("key", result.secrets.youtubeApiKey)
        assertTrue(result.writeEncrypted)
        assertTrue(result.clearPlain)
    }

    @Test
    fun bothEmptyNoOps() {
        val result = SensitiveSecretsMigrator.migrate(
            encrypted = SensitiveSecrets(),
            plain = SensitiveSecrets()
        )
        assertNull(result.secrets.youtubeApiKey)
        assertFalse(result.writeEncrypted)
        assertFalse(result.clearPlain)
    }
}
