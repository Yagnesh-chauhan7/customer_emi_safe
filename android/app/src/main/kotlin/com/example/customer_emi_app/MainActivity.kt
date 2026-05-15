package com.example.customer_emi_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.UserManager

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.customer_emi_app/admin"

    private var shouldStartKiosk = false
    private var shouldStopKiosk = false
    // Tracks whether Kiosk (LockTask) mode is currently active
    private var isKioskActive = false
    // Prevents infinite loop in onWindowFocusChanged
    private var isBringingToFront = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Wake up screen so the activity can be resumed even when the screen is off
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        handleIntent(intent)

    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (!isKioskActive) {
            super.onBackPressed()
        }
        // In kiosk mode: do nothing — back button is completely blocked
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.getBooleanExtra("start_kiosk", false)) {
            shouldStartKiosk = true
        }
        if (intent.getBooleanExtra("stop_kiosk", false)) {
            shouldStopKiosk = true
        }
    }

    override fun onResume() {
        super.onResume()
        if (shouldStartKiosk) {
            try {
                startLockTask()
                isKioskActive = true
            } catch (e: Exception) {}
            shouldStartKiosk = false
        }
        if (shouldStopKiosk) {
            try {
                stopLockTask()
                isKioskActive = false
            } catch (e: Exception) {}
            shouldStopKiosk = false
            finishAndRemoveTask()
        }
    }

    // FIX 2: Re-enter foreground when Recent Apps or status bar is opened.
    // Uses isBringingToFront flag to prevent infinite callback loop.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            isBringingToFront = false // reset when we regain focus
        } else if (isKioskActive && !isBringingToFront) {
            isBringingToFront = true
            val bringBack = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            startActivity(bringBack)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val frpManager = FRPManager(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "frp_channel").setMethodCallHandler { call, result ->
            when (call.method) {
                "enableFRP" -> {
                    val accounts = call.argument<List<String>>("accounts") ?: emptyList()
                    result.success(frpManager.enableFRP(accounts))
                }
                "disableFRP" -> {
                    result.success(frpManager.disableFRP())
                }
                "getFRPStatus" -> {
                    result.success(frpManager.isFRPEnabled())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val componentName = ComponentName(this, MyDeviceAdminReceiver::class.java)

            when (call.method) {
                "isAdminActive" -> {
                    result.success(devicePolicyManager.isAdminActive(componentName))
                }
                "isDeviceOwner" -> {
                    result.success(devicePolicyManager.isDeviceOwnerApp(packageName))
                }
                "requestAdmin" -> {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                    intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "We need this permission to secure the device for EMI tracking.")
                    startActivityForResult(intent, 1)
                    result.success(true)
                }

                // ------- KIOSK POLICIES (Requires Device Owner) -------
                "setKioskPolicies" -> {
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            // Whitelist our app for Lock Task (True Kiosk)
                            devicePolicyManager.setLockTaskPackages(componentName, arrayOf(packageName))
                            // STRICT: Disable Home, Recents, Back, Status Bar, Global Actions
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                                devicePolicyManager.setLockTaskFeatures(
                                    componentName,
                                    DevicePolicyManager.LOCK_TASK_FEATURE_NONE
                                )
                            }
                            result.success(true)
                        } else {
                            result.error("NOT_DEVICE_OWNER", "App is not Device Owner.", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                "startKioskMode" -> {
                    try {
                        startLockTask()
                        isKioskActive = true
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopKioskMode" -> {
                    try {
                        stopLockTask()
                        isKioskActive = false
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                // ------- FACTORY RESET / OEM UNLOCK BLOCK (Requires Device Owner) -------
                "setFactoryResetAllowed" -> {
                    val allowed = call.argument<Boolean>("allowed") ?: false
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            if (!allowed) {
                                // BLOCK factory reset, OEM unlock, safe boot
                                devicePolicyManager.addUserRestriction(componentName, UserManager.DISALLOW_FACTORY_RESET)
                                devicePolicyManager.addUserRestriction(componentName, "no_oem_unlock") // DISALLOW_OEM_UNLOCK (API 27+)
                                devicePolicyManager.addUserRestriction(componentName, UserManager.DISALLOW_SAFE_BOOT)
                            } else {
                                // ALLOW (admin granted permission)
                                devicePolicyManager.clearUserRestriction(componentName, UserManager.DISALLOW_FACTORY_RESET)
                                devicePolicyManager.clearUserRestriction(componentName, "no_oem_unlock") // DISALLOW_OEM_UNLOCK (API 27+)
                                devicePolicyManager.clearUserRestriction(componentName, UserManager.DISALLOW_SAFE_BOOT)
                            }
                            result.success(true)
                        } else {
                            result.error("NOT_DEVICE_OWNER", "App is not Device Owner.", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                // ------- UNINSTALL / ADMIN REMOVAL BLOCK (Requires Device Owner) -------
                "setUninstallBlocked" -> {
                    val blocked = call.argument<Boolean>("blocked") ?: true
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            // Block/allow uninstalling this app
                            devicePolicyManager.setUninstallBlocked(componentName, packageName, blocked)
                            
                            if (blocked) {
                                // Also block users from removing device admin via Settings
                                devicePolicyManager.addUserRestriction(componentName, UserManager.DISALLOW_REMOVE_MANAGED_PROFILE)
                            } else {
                                devicePolicyManager.clearUserRestriction(componentName, UserManager.DISALLOW_REMOVE_MANAGED_PROFILE)
                            }
                            result.success(true)
                        } else {
                            result.error("NOT_DEVICE_OWNER", "App is not Device Owner.", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                "hideAppIcon" -> {
                    val pm: PackageManager = applicationContext.packageManager
                    val componentNameAlias = ComponentName(applicationContext, "com.example.customer_emi_app.MainActivity")
                    pm.setComponentEnabledSetting(
                        componentNameAlias,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    result.success(true)
                }

                // ------- FCM: Create high-priority notification channel -------
                // Required on Android 8+ for FCM to deliver background messages
                "createNotificationChannel" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val channel = NotificationChannel(
                            "emi_security_channel",
                            "EMI Security Alerts",
                            NotificationManager.IMPORTANCE_HIGH
                        ).apply {
                            description = "Used for EMI device security lock/unlock signals"
                            setShowBadge(false)
                            enableLights(false)
                            enableVibration(false)
                        }
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        nm.createNotificationChannel(channel)
                    }
                    result.success(true)
                }

                // ------- Battery Optimization Exemption -------
                // Without this, Samsung/Xiaomi/OPPO kill the FCM background process
                "requestBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            try {
                                startActivity(intent)
                            } catch (e: Exception) {
                                // Some devices don't support this intent, ignore silently
                            }
                        }
                    }
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
