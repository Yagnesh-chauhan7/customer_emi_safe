package com.example.customer_emi_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log

class UpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                Log.d("UpdateReceiver", "✅ App updated via MY_PACKAGE_REPLACED. Closing silently...")
                closeSilently(context)
            }
            "com.example.customer_emi_app.UPDATE_STATUS" -> {
                val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -1)
                val statusMessage = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                Log.d("UpdateReceiver", "PackageInstaller status: $status message: $statusMessage")
                when (status) {
                    PackageInstaller.STATUS_SUCCESS -> {
                        Log.d("UpdateReceiver", "✅ PackageInstaller: Install SUCCESS. Closing silently...")
                        closeSilently(context)
                    }
                    else -> {
                        Log.e("UpdateReceiver", "❌ PackageInstaller: Install FAILED: $statusMessage")
                    }
                }
            }
        }
    }

    private fun closeSilently(context: Context) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            )
            putExtra("update_complete", true)
        }
        context.startActivity(launchIntent)
    }
}
