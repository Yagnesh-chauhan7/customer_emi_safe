package com.example.customer_emi_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage
import android.util.Log
import android.content.SharedPreferences

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"

        // New encrypted SMS command format:
        // EMI_CMD|<Base64_Encrypted_Payload>
        const val CMD_PREFIX = "EMI_CMD|"

        const val PREFS_NAME       = "emi_sms_prefs"
        const val KEY_AES_SECRET   = "sms_aes_key"
        const val KEY_LAST_TIME    = "sms_last_timestamp"
        
        // Allowed clock skew / replay window (in seconds)
        // 5 minutes = 300 seconds
        const val MAX_AGE_SECONDS = 300L
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        val bundle = intent.extras ?: return
        val pdus   = bundle.get("pdus") as? Array<*> ?: return
        val format = bundle.getString("format") ?: "3gpp"

        for (pdu in pdus) {
            val sms = SmsMessage.createFromPdu(pdu as ByteArray, format)
            val body   = sms.messageBody?.trim() ?: continue
            val sender = sms.originatingAddress ?: "unknown"

            // Check if it's our encrypted command prefix
            if (!body.startsWith(CMD_PREFIX)) {
                continue // Not an EMI command, let it pass to default SMS app
            }

            Log.d(TAG, "Encrypted SMS received from $sender")

            // Abort broadcast so it doesn't show up in the default SMS app (stealth mode)
            abortBroadcast()

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val secretKey = prefs.getString(KEY_AES_SECRET, null)
            val storedDeviceId = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                                        .getString("flutter.customer_id", null)

            if (secretKey.isNullOrEmpty() || storedDeviceId.isNullOrEmpty()) {
                Log.e(TAG, "Missing AES key or Customer ID. Cannot process offline SMS.")
                continue
            }

            // Extract Base64 part
            val base64Ciphertext = body.substring(CMD_PREFIX.length)

            // Decrypt
            val decryptedPlaintext = SmsCommandCrypto.decrypt(base64Ciphertext, secretKey)
            if (decryptedPlaintext == null) {
                Log.e(TAG, "SMS Decryption failed or invalid key.")
                continue
            }

            // Payload format: COMMAND|TIMESTAMP|CUSTOMER_ID
            // e.g., LOCK|1716617400|uuid-1234
            val parts = decryptedPlaintext.split("|")
            if (parts.size != 3) {
                Log.e(TAG, "Invalid decrypted payload format: $decryptedPlaintext")
                continue
            }

            val command = parts[0]
            val timestampStr = parts[1]
            val targetDeviceId = parts[2]

            // 1. Validate Target Device ID
            if (targetDeviceId != storedDeviceId) {
                Log.e(TAG, "Device ID mismatch. Expected $storedDeviceId, got $targetDeviceId")
                continue
            }

            // 2. Validate Timestamp (Replay Protection)
            val msgTimestamp = timestampStr.toLongOrNull() ?: 0L
            val currentTimestamp = System.currentTimeMillis() / 1000L
            val lastTimestamp = prefs.getLong(KEY_LAST_TIME, 0L)

            if (msgTimestamp <= lastTimestamp) {
                Log.e(TAG, "Replay attack detected: Timestamp $msgTimestamp is <= last used $lastTimestamp")
                continue
            }
            if (currentTimestamp - msgTimestamp > MAX_AGE_SECONDS) {
                Log.e(TAG, "SMS expired: Timestamp $msgTimestamp is older than 5 minutes")
                continue
            }

            // All validations passed! Update last used timestamp.
            prefs.edit().putLong(KEY_LAST_TIME, msgTimestamp).apply()

            // 3. Execute Command
            when (command) {
                "LOCK" -> {
                    Log.d(TAG, "🔒 Encrypted SMS LOCK command accepted")
                    triggerLock(context)
                }
                "UNLOCK" -> {
                    Log.d(TAG, "🔓 Encrypted SMS UNLOCK command accepted")
                    triggerUnlock(context)
                }
                else -> {
                    Log.e(TAG, "Unknown command in SMS: $command")
                }
            }
        }
    }

    private fun triggerLock(context: Context) {
        // Save locked state so BootReceiver re-locks after reboot
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.is_locked", true)
            .apply()

        // Launch MainActivity with start_kiosk flag
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("start_kiosk", true)
            putExtra("sms_lock", true)
        }
        context.startActivity(launchIntent)
    }

    private fun triggerUnlock(context: Context) {
        // Save unlocked state
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.is_locked", false)
            .apply()

        // Launch MainActivity with stop_kiosk flag
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("stop_kiosk", true)
            putExtra("sms_unlock", true)
        }
        context.startActivity(launchIntent)
    }
}
