package com.example.customer_emi_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Only act on BOOT_COMPLETED and LOCKED_BOOT_COMPLETED
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.LOCKED_BOOT_COMPLETED") {
            return
        }

        // Read from SharedPreferences (written by Flutter's main.dart)
        val prefs: SharedPreferences = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        
        // Flutter SharedPreferences stores booleans with a "flutter." prefix
        val isLocked = prefs.getBoolean("flutter.is_locked", false)

        if (isLocked) {
            // Launch the MainActivity with the start_kiosk flag to re-lock the device
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                putExtra("start_kiosk", true)
            }
            context.startActivity(launchIntent)
        }
    }
}
