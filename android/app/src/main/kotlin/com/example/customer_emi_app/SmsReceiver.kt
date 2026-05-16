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

        // SMS command format:
        //   LOCK  → "EMI_LOCK#<secretCode>"
        //   UNLOCK → "EMI_UNLOCK#<secretCode>"
        const val LOCK_PREFIX   = "EMI_LOCK#"
        const val UNLOCK_PREFIX = "EMI_UNLOCK#"

        const val PREFS_NAME    = "emi_sms_prefs"
        const val KEY_SECRET    = "sms_secret_code"
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

            Log.d(TAG, "SMS received from $sender: $body")

            val prefs      = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val secretCode = prefs.getString(KEY_SECRET, null) ?: continue

            when {
                body == "$LOCK_PREFIX$secretCode" -> {
                    Log.d(TAG, "🔒 SMS LOCK command received from $sender")
                    triggerLock(context)
                }
                body == "$UNLOCK_PREFIX$secretCode" -> {
                    Log.d(TAG, "🔓 SMS UNLOCK command received from $sender")
                    triggerUnlock(context)
                }
                else -> {
                    Log.d(TAG, "SMS does not match EMI command format — ignored")
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
