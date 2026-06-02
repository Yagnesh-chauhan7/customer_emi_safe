package com.example.customer_emi_app

import android.app.admin.DevicePolicyManager
import android.app.WallpaperManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.UserManager
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import org.json.JSONArray
import org.json.JSONObject

class ActionReceiver : BroadcastReceiver() {
    private val TAG = "ActionReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Received action: $action")

        when (action) {
            "com.example.customer_emi_app.SET_WALLPAPER" -> {
                val filePath = intent.getStringExtra("filePath")
                if (filePath != null) setWallpaper(context, filePath)
            }
            "com.example.customer_emi_app.RESET_WALLPAPER" -> resetWallpaper(context)
            "com.example.customer_emi_app.HIDE_APP" -> hideApp(context)
            "com.example.customer_emi_app.UNHIDE_APP" -> unhideApp(context)
            "com.example.customer_emi_app.SETTLE_EMI" -> settleEmi(context)
            "com.example.customer_emi_app.ENABLE_LOCATION" -> setLocation(context, true)
            "com.example.customer_emi_app.DISABLE_LOCATION" -> setLocation(context, false)
            "com.example.customer_emi_app.FETCH_SIM" -> fetchSim(context)
        }
    }

    private fun hideApp(context: Context) {
        try {
            val pm = context.packageManager
            val componentNameAlias = ComponentName(context, "com.example.customer_emi_app.LauncherAlias")
            pm.setComponentEnabledSetting(
                componentNameAlias,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            lockAllPermissions(context)
            Log.d(TAG, "App hidden")
        } catch (e: Exception) { Log.e(TAG, "hideApp error", e) }
    }

    private fun unhideApp(context: Context) {
        try {
            val pm = context.packageManager
            val componentNameAlias = ComponentName(context, "com.example.customer_emi_app.LauncherAlias")
            pm.setComponentEnabledSetting(
                componentNameAlias,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            unlockAllPermissions(context)
            Log.d(TAG, "App unhidden")
        } catch (e: Exception) { Log.e(TAG, "unhideApp error", e) }
    }

    private fun lockAllPermissions(context: Context) {
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
            val adminComponentName = ComponentName(context, MyDeviceAdminReceiver::class.java)
            if (dpm.isDeviceOwnerApp(context.packageName)) {
                val packageInfo = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
                packageInfo.requestedPermissions?.forEach { perm ->
                    try {
                        dpm.setPermissionGrantState(adminComponentName, context.packageName, perm, android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED)
                    } catch (e: Exception) {}
                }
            }
        } catch (e: Exception) { Log.e(TAG, "Failed to lock permissions", e) }
    }

    private fun unlockAllPermissions(context: Context) {
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
            val adminComponentName = ComponentName(context, MyDeviceAdminReceiver::class.java)
            if (dpm.isDeviceOwnerApp(context.packageName)) {
                val packageInfo = context.packageManager.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
                packageInfo.requestedPermissions?.forEach { perm ->
                    try {
                        dpm.setPermissionGrantState(adminComponentName, context.packageName, perm, android.app.admin.DevicePolicyManager.PERMISSION_GRANT_STATE_DEFAULT)
                    } catch (e: Exception) {}
                }
            }
        } catch (e: Exception) { Log.e(TAG, "Failed to unlock permissions", e) }
    }

    private fun settleEmi(context: Context) {
        try {
            val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as android.app.admin.DevicePolicyManager
            val componentName = ComponentName(context, MyDeviceAdminReceiver::class.java)

            if (devicePolicyManager.isDeviceOwnerApp(context.packageName)) {
                val restrictions = listOf(
                    android.os.UserManager.DISALLOW_FACTORY_RESET,
                    android.os.UserManager.DISALLOW_SAFE_BOOT,
                    android.os.UserManager.DISALLOW_REMOVE_MANAGED_PROFILE,
                    android.os.UserManager.DISALLOW_UNINSTALL_APPS,
                    "no_oem_unlock"
                )
                for (r in restrictions) {
                    try { devicePolicyManager.clearUserRestriction(componentName, r) } catch (e: Exception) {}
                }
                try { devicePolicyManager.setUninstallBlocked(componentName, context.packageName, false) } catch (e: Exception) {}
                
                devicePolicyManager.clearDeviceOwnerApp(context.packageName)
                Log.d(TAG, "Device Owner removed silently in background")
            } else if (devicePolicyManager.isAdminActive(componentName)) {
                devicePolicyManager.removeActiveAdmin(componentName)
                Log.d(TAG, "Device Admin removed silently in background")
            }

            // Attempt to trigger uninstall prompt. 
            // Note: Android 10+ may block this because we are now in the background and no longer Device Owner.
            // But the device is successfully unlocked regardless!
            val uninstallIntent = Intent(Intent.ACTION_DELETE)
            uninstallIntent.data = Uri.parse("package:${context.packageName}")
            uninstallIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(uninstallIntent)
        } catch (e: Exception) {
            Log.e(TAG, "settleEmi error", e)
        }
    }

    private fun setLocation(context: Context, enabled: Boolean) {
        try {
            val connectivityMgr = DeviceConnectivityManager(context)
            connectivityMgr.setLocationEnabled(enabled)
            Log.d(TAG, "Location set to $enabled")
        } catch (e: Exception) { Log.e(TAG, "setLocation error", e) }
    }

    private fun fetchSim(context: Context) {
        try {
            val deviceInfoMgr = DeviceInfoManager(context)
            val simDetailsList = deviceInfoMgr.getSimDetails()
            
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            
            val jsonArray = JSONArray()
            for (sim in simDetailsList) {
                val map = sim as Map<*, *>
                val jsonObject = JSONObject()
                for ((key, value) in map) {
                    jsonObject.put(key.toString(), value)
                }
                jsonArray.put(jsonObject)
            }
            editor.putString("flutter.native_sim_data", jsonArray.toString())
            editor.apply()
            Log.d(TAG, "SIM data written to SharedPreferences: ${jsonArray.toString()}")
        } catch (e: Exception) {
            Log.e(TAG, "fetchSim error", e)
        }
    }

    private fun setWallpaper(context: Context, filePath: String) {
        try {
            val wallpaperManager = WallpaperManager.getInstance(context)
            val backupFile = File(context.filesDir, "original_wallpaper.jpg")
            if (!backupFile.exists()) {
                val drawable = wallpaperManager.drawable
                if (drawable is BitmapDrawable) {
                    val bitmap = drawable.bitmap
                    val out = FileOutputStream(backupFile)
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                    out.flush()
                    out.close()
                    Log.d(TAG, "Backed up current wallpaper")
                }
            }

            val bitmap = BitmapFactory.decodeFile(filePath)
            if (bitmap != null) {
                wallpaperManager.setBitmap(bitmap)
                Log.d(TAG, "Successfully set new wallpaper")
            } else {
                Log.e(TAG, "Could not decode image at $filePath")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting wallpaper", e)
        }
    }

    private fun resetWallpaper(context: Context) {
        try {
            val wallpaperManager = WallpaperManager.getInstance(context)
            val backupFile = File(context.filesDir, "original_wallpaper.jpg")
            
            if (backupFile.exists()) {
                val bitmap = BitmapFactory.decodeFile(backupFile.absolutePath)
                if (bitmap != null) {
                    wallpaperManager.setBitmap(bitmap)
                    Log.d(TAG, "Restored original wallpaper")
                    backupFile.delete()
                }
            } else {
                wallpaperManager.clear()
                Log.d(TAG, "Cleared wallpaper to system default")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting wallpaper", e)
        }
    }
}
