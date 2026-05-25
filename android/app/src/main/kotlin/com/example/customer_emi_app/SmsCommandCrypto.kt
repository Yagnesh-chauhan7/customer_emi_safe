package com.example.customer_emi_app

import android.util.Base64
import java.nio.charset.StandardCharsets
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

object SmsCommandCrypto {

    private const val ALGORITHM = "AES/CBC/PKCS5Padding"
    private const val AES = "AES"
    private const val IV_SIZE = 16

    /**
     * Decrypts a Base64 encoded payload that was encrypted using AES-256-CBC.
     * The expected format of the Base64 decoded bytes is: [16 bytes IV] + [Ciphertext]
     *
     * @param base64Ciphertext The Base64 encoded string from the SMS.
     * @param keyStr The 32-character AES secret key.
     * @return The decrypted plaintext command string, or null if decryption fails.
     */
    fun decrypt(base64Ciphertext: String, keyStr: String): String? {
        try {
            if (keyStr.length != 32) return null

            // 1. Decode base64
            val encryptedBytes = Base64.decode(base64Ciphertext, Base64.DEFAULT)
            if (encryptedBytes.size <= IV_SIZE) return null

            // 2. Extract IV (first 16 bytes)
            val iv = ByteArray(IV_SIZE)
            System.arraycopy(encryptedBytes, 0, iv, 0, IV_SIZE)
            val ivSpec = IvParameterSpec(iv)

            // 3. Extract Ciphertext (remaining bytes)
            val ciphertextLength = encryptedBytes.size - IV_SIZE
            val ciphertext = ByteArray(ciphertextLength)
            System.arraycopy(encryptedBytes, IV_SIZE, ciphertext, 0, ciphertextLength)

            // 4. Set up AES key
            val secretKeySpec = SecretKeySpec(keyStr.toByteArray(StandardCharsets.UTF_8), AES)

            // 5. Decrypt
            val cipher = Cipher.getInstance(ALGORITHM)
            cipher.init(Cipher.DECRYPT_MODE, secretKeySpec, ivSpec)
            val plaintextBytes = cipher.doFinal(ciphertext)

            return String(plaintextBytes, StandardCharsets.UTF_8)
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    /**
     * Encrypts a plaintext command using AES-256-CBC and prepends a random IV.
     * Returns the result as a Base64 string.
     * 
     * Note: This is mainly used if the customer app ever needs to reply with an encrypted SMS,
     * or for testing locally. The Admin app will do the actual encrypting.
     *
     * @param plaintext The string to encrypt.
     * @param keyStr The 32-character AES secret key.
     * @return Base64 encoded string containing [16 bytes IV] + [Ciphertext]
     */
    fun encrypt(plaintext: String, keyStr: String): String? {
        try {
            if (keyStr.length != 32) return null

            // 1. Generate random 16-byte IV
            val iv = ByteArray(IV_SIZE)
            SecureRandom().nextBytes(iv)
            val ivSpec = IvParameterSpec(iv)

            // 2. Set up AES key
            val secretKeySpec = SecretKeySpec(keyStr.toByteArray(StandardCharsets.UTF_8), AES)

            // 3. Encrypt
            val cipher = Cipher.getInstance(ALGORITHM)
            cipher.init(Cipher.ENCRYPT_MODE, secretKeySpec, ivSpec)
            val ciphertext = cipher.doFinal(plaintext.toByteArray(StandardCharsets.UTF_8))

            // 4. Combine IV + Ciphertext
            val combined = ByteArray(IV_SIZE + ciphertext.size)
            System.arraycopy(iv, 0, combined, 0, IV_SIZE)
            System.arraycopy(ciphertext, 0, combined, IV_SIZE, ciphertext.size)

            // 5. Base64 encode
            return Base64.encodeToString(combined, Base64.NO_WRAP)
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
}
