package com.example.customer_emi_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.customer_emi_app/admin"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.getBooleanExtra("start_kiosk", false)) {
            try {
                startLockTask()
            } catch (e: Exception) {}
        }
        if (intent.getBooleanExtra("stop_kiosk", false)) {
            try {
                stopLockTask()
            } catch (e: Exception) {}
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                "setKioskPolicies" -> {
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            // Whitelist our app for Lock Task Mode (True Kiosk)
                            devicePolicyManager.setLockTaskPackages(componentName, arrayOf(packageName))
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
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopKioskMode" -> {
                    try {
                        stopLockTask()
                        result.success(true)
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
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
