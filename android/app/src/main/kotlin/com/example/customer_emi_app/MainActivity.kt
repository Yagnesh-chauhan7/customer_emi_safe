package com.example.customer_emi_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSuggestion
import android.os.Build
import android.os.Handler
import android.os.PowerManager
import android.os.UserManager
import android.app.PendingIntent
import android.content.pm.PackageInstaller
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

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
    // Tracks if uninstall should be performed
    private var shouldPerformUninstall = false
    // Prevents onWindowFocusChanged from re-locking during SMS/FCM unlock sequence
    private var isUnlocking = false
    // Prevents onWindowFocusChanged from re-locking when launching WiFi settings
    private var isOpeningSettings = false
    // Flutter engine reference — used to call back into Dart (native → Flutter events)
    private var activeFlutterEngine: FlutterEngine? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enforce core security policies unconditionally on startup if Device Owner
        enforceCoreSecurityPolicies()
        // Auto-grant critical permissions as Device Owner (CALL_PHONE etc.)
        autoGrantPermissions(this)
        
        handleIntent(intent)
    }

    private fun wakeUpScreen() {
        // Wake up screen so the activity can be resumed even when the screen is off
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            // For Android 10+ (API 29), you might need to use a keyguard manager to request dismiss
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        
        // Also acquire a wakelock briefly to ensure the screen turns on
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "CustomerEmiApp::WakeUpTag"
        )
        wakeLock.acquire(3000) // 3 seconds
    }

    private fun autoGrantPermissions(context: Context) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, MyDeviceAdminReceiver::class.java)

        if (dpm.isDeviceOwnerApp(context.packageName)) {
            val permissionsToAutoGrant = arrayOf(
                android.Manifest.permission.ACCESS_FINE_LOCATION,
                android.Manifest.permission.ACCESS_COARSE_LOCATION,
                android.Manifest.permission.READ_PHONE_STATE,
                android.Manifest.permission.READ_PHONE_NUMBERS,
                android.Manifest.permission.CALL_PHONE,
                android.Manifest.permission.CAMERA,
                android.Manifest.permission.RECORD_AUDIO,
                android.Manifest.permission.RECEIVE_SMS,
                android.Manifest.permission.READ_SMS,
                android.Manifest.permission.SEND_SMS,
                android.Manifest.permission.READ_EXTERNAL_STORAGE,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE,
                "android.permission.BLUETOOTH_CONNECT",
                "android.permission.BLUETOOTH_SCAN",
                "android.permission.POST_NOTIFICATIONS"
            )

            for (permission in permissionsToAutoGrant) {
                try {
                    dpm.setPermissionGrantState(
                        adminComponent,
                        context.packageName,
                        permission,
                        DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error auto-granting permission: \$permission", e)
                }
            }
        }
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
        // CRITICAL: When the app is already in kiosk mode (RESUMED on screen),
        // onResume() will NOT fire again after onNewIntent.
        // So we must process unlock/lock immediately here.
        if (shouldStopKiosk) {
            // Try to route through Flutter (mirrors online FCM unlock exactly)
            val notifiedFlutter = notifyFlutterUnlock()
            if (!notifiedFlutter) {
                // Fallback: handle in native if Flutter engine not ready
                processUnlockNow()
            }
        }
        if (shouldStartKiosk) {
            processLockNow()
        }
    }

    // Sends 'smsUnlock' event to Flutter so it runs handleLockAction('UNLOCK')
    // Returns true if Flutter was successfully notified, false if fallback is needed
    private fun notifyFlutterUnlock(): Boolean {
        val engine = activeFlutterEngine ?: return false
        return try {
            android.util.Log.d("MainActivity", "Notifying Flutter to run handleLockAction(UNLOCK)")
            MethodChannel(engine.dartExecutor.binaryMessenger, "emi_native_events")
                .invokeMethod("smsUnlock", null)
            shouldStopKiosk = false
            true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to notify Flutter for unlock: ${e.message}")
            false
        }
    }

    private fun handleIntent(intent: Intent) {
        if (intent.getBooleanExtra("wakeup", false)) {
            wakeUpScreen()
        }
        if (intent.getBooleanExtra("power_off", false)) {
            // Instantly push the app to the background so it's not visible
            moveTaskToBack(true)
            
            // Delay the screen lock slightly so the Activity launch doesn't override it
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                    if (dpm.isDeviceOwnerApp(packageName)) {
                        dpm.lockNow()
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error locking screen: ${e.message}")
                }
            }, 500)
        }
        if (intent.getBooleanExtra("start_kiosk", false)) {
            shouldStartKiosk = true
        }
        if (intent.getBooleanExtra("stop_kiosk", false) || intent.getBooleanExtra("sms_unlock", false)) {
            shouldStopKiosk = true
            android.util.Log.d("MainActivity", "Unlock intent received — shouldStopKiosk=true")
        }
        if (intent.getBooleanExtra("perform_uninstall", false)) {
            shouldPerformUninstall = true
            intent.removeExtra("perform_uninstall") // prevent re-triggering
        }
        if (intent.getBooleanExtra("update_complete", false)) {
            // App was just updated silently — stop kiosk, close and remove from recents
            android.util.Log.d("MainActivity", "✅ Update complete. Closing silently and removing from recents.")
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try { stopLockTask() } catch (_: Exception) {}
                moveTaskToBack(true)
                finishAndRemoveTask()
            }, 500)
        }
    }

    private fun performUninstall() {
        try {
            val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            
            
            val componentName = ComponentName(this, MyDeviceAdminReceiver::class.java)

            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                val restrictions = listOf(
                    UserManager.DISALLOW_FACTORY_RESET,
                    UserManager.DISALLOW_SAFE_BOOT,
                    UserManager.DISALLOW_REMOVE_MANAGED_PROFILE,
                    UserManager.DISALLOW_UNINSTALL_APPS,
                    "no_oem_unlock"
                )
                for (r in restrictions) {
                    try { devicePolicyManager.clearUserRestriction(componentName, r) } catch (e: Exception) {}
                }
                try { devicePolicyManager.setUninstallBlocked(componentName, packageName, false) } catch (e: Exception) {}
                
                devicePolicyManager.clearDeviceOwnerApp(packageName)
                android.util.Log.d("MainActivity", "Device Owner removed")
            } else if (devicePolicyManager.isAdminActive(componentName)) {
                devicePolicyManager.removeActiveAdmin(componentName)
                android.util.Log.d("MainActivity", "Device Admin removed")
            }

            val uninstallIntent = Intent(Intent.ACTION_DELETE)
            uninstallIntent.data = Uri.parse("package:$packageName")
            uninstallIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(uninstallIntent)
            android.util.Log.d("MainActivity", "Uninstall triggered")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "performUninstall error", e)
        }
    }

    private fun applyKioskPoliciesIfNeeded() {
        try {
            val devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val componentName = ComponentName(this, MyDeviceAdminReceiver::class.java)

            if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                // ── Auto-grant CALL_PHONE so ACTION_CALL works without user prompt ──
                // Device Owner can grant dangerous permissions silently.
                // Without this, ACTION_CALL throws SecurityException in release builds.
                try {
                    devicePolicyManager.setPermissionGrantState(
                        componentName,
                        packageName,
                        android.Manifest.permission.CALL_PHONE,
                        DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                    android.util.Log.d("MainActivity", "CALL_PHONE permission auto-granted via Device Owner")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to auto-grant CALL_PHONE: ${e.message}")
                }

                // ── Whitelist ONLY our app + system settings ──
                // Dialer/Contacts apps are NOT whitelisted — calls go via ACTION_CALL directly
                // so the user never gets access to the system dialer UI or contacts list.
                devicePolicyManager.setLockTaskPackages(
                    componentName, 
                    arrayOf(
                        packageName,
                        // Settings (needed for WiFi configuration)
                        "com.android.settings", 
                        "com.google.android.settings",
                        "com.samsung.android.settings",
                        "com.oppo.settings",
                        "com.vivo.settings",
                        "com.huawei.android.settings",
                        "com.miui.settings",
                        "com.coloros.settings",
                        // Dialer apps (needed for emergency calls from lock screen)
                        "com.android.dialer",
                        "com.google.android.dialer",
                        "com.samsung.android.dialer",
                        "com.coloros.dialer",
                        "com.oppo.dialer",
                        "com.miui.dialer",
                        "com.vivo.dialer",
                        "com.android.phone"
                    )
                )
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                    devicePolicyManager.setLockTaskFeatures(
                        componentName,
                        DevicePolicyManager.LOCK_TASK_FEATURE_NONE
                    )
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "applyKioskPoliciesIfNeeded error: ${e.message}")
        }
    }

    // Called when SMS/FCM LOCK command arrives while app is fresh starting (via onCreate path)
    private fun processLockNow() {
        if (!shouldStartKiosk) return
        android.util.Log.d("MainActivity", "processLockNow() called")
        try {
            applyKioskPoliciesIfNeeded()
            startLockTask()
            isKioskActive = true
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error starting lock task: ${e.message}")
        }
        shouldStartKiosk = false
    }

    // Called when SMS/FCM UNLOCK command arrives.
    // Works whether app is fresh-started OR already in foreground kiosk mode.
    private fun processUnlockNow() {
        if (!shouldStopKiosk) return
        android.util.Log.d("MainActivity", "processUnlockNow() called — stopping kiosk and closing app")
        isUnlocking = true  // Block onWindowFocusChanged from re-locking during unlock
        try {
            stopLockTask()
            isKioskActive = false
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error stopping lock task: ${e.message}")
        }
        shouldStopKiosk = false

        // 800ms delay gives Android time to fully exit lock task mode before finishing
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            android.util.Log.d("MainActivity", "Closing app and removing from recents after unlock")
            isUnlocking = false
            moveTaskToBack(true)
            finishAndRemoveTask()
        }, 800)
    }

    override fun onResume() {
        super.onResume()
        // These flags are set in handleIntent (called from onCreate)
        // and processed here once the activity is fully resumed
        if (shouldStartKiosk) {
            processLockNow()
        }
        if (shouldStopKiosk) {
            processUnlockNow()
        }
        if (shouldPerformUninstall) {
            shouldPerformUninstall = false
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                performUninstall()
            }, 500)
        }
    }

    // FIX 2: Re-enter foreground when Recent Apps or status bar is opened.
    // Uses isBringingToFront flag to prevent infinite callback loop.
    // isUnlocking flag prevents re-lock during SMS/FCM unlock sequence.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            isBringingToFront = false // reset when we regain focus
            isOpeningSettings = false // reset when we regain focus
            if (isKioskActive) {
                try {
                    startLockTask()
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error restarting lock task on focus gain: ${e.message}")
                }
            }
        } else if (isKioskActive && !isBringingToFront && !isUnlocking && !isOpeningSettings) {
            // Only re-enter kiosk if we are NOT in the middle of an unlock and not opening settings
            isBringingToFront = true
            val bringBack = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            startActivity(bringBack)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Store engine reference for native→Flutter calls (e.g. SMS unlock events)
        activeFlutterEngine = flutterEngine

        // ── Native → Flutter event channel ───────────────────────
        // Allows Kotlin to call into Dart to trigger handleLockAction
        // This makes offline SMS unlock follow the SAME flow as online FCM unlock
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "emi_native_events").setMethodCallHandler { _, _ -> }
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

        val connectivityMgr = DeviceConnectivityManager(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "connectivity_channel").setMethodCallHandler { call, result ->
            when (call.method) {
                // WiFi
                "setWifiEnabled"      -> result.success(connectivityMgr.setWifiEnabled(call.argument<Boolean>("enabled") ?: false))
                "getWifiStatus"       -> result.success(connectivityMgr.getWifiStatus())
                // Mobile Data
                "setMobileDataEnabled" -> result.success(connectivityMgr.setMobileDataEnabled(call.argument<Boolean>("enabled") ?: false))
                "getMobileDataStatus"  -> result.success(connectivityMgr.getMobileDataStatus())
                // Bluetooth
                "setBluetoothEnabled" -> result.success(connectivityMgr.setBluetoothEnabled(call.argument<Boolean>("enabled") ?: false))
                "getBluetoothStatus"  -> result.success(connectivityMgr.getBluetoothStatus())
                // Location
                "setLocationEnabled"  -> result.success(connectivityMgr.setLocationEnabled(call.argument<Boolean>("enabled") ?: false))
                "getLocationStatus"   -> result.success(connectivityMgr.getLocationStatus())


                // Open Android system WiFi settings page directly.
                // Works in kiosk mode because com.android.settings is whitelisted
                // in setLockTaskPackages(). Bypasses custom WiFi screen entirely.
                "openWifiSettings" -> {
                    isOpeningSettings = true
                    val settingsPackages = arrayOf(
                        "com.android.settings",
                        "com.google.android.settings",
                        "com.samsung.android.settings",
                        "com.oppo.settings",
                        "com.vivo.settings",
                        "com.huawei.android.settings",
                        "com.miui.settings",
                        "com.coloros.settings"
                    )
                    var opened = false
                    
                    // 1. Try explicit packages first (prevents implicit intent blocking in LockTask)
                    for (pkg in settingsPackages) {
                        try {
                            val intent = android.content.Intent(android.provider.Settings.ACTION_WIFI_SETTINGS).apply {
                                setPackage(pkg)
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            opened = true
                            android.util.Log.d("MainActivity", "Successfully opened settings for package: $pkg")
                            break
                        } catch (e: Exception) {
                            // Try next package
                        }
                    }
                    
                    // 2. Try implicit if explicit didn't work
                    if (!opened) {
                        try {
                            val intent = android.content.Intent(android.provider.Settings.ACTION_WIFI_SETTINGS).apply {
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            opened = true
                            android.util.Log.d("MainActivity", "Successfully opened settings via implicit intent")
                        } catch (e: Exception) {
                            android.util.Log.w("MainActivity", "Implicit settings open failed: ${e.message}")
                        }
                    }
                    
                    // 3. Ultimate Kiosk Fallback: temporarily stopLockTask, start settings, and re-lock when user returns
                    if (!opened) {
                        try {
                            android.util.Log.i("MainActivity", "All standard paths failed. Using stopLockTask fallback...")
                            stopLockTask()
                            val intent = android.content.Intent(android.provider.Settings.ACTION_WIFI_SETTINGS).apply {
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            opened = true
                            android.util.Log.i("MainActivity", "Opened settings after stopLockTask fallback")
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "stopLockTask fallback failed: ${e.message}")
                        }
                    }
                    
                    if (opened) {
                        result.success(true)
                    } else {
                        isOpeningSettings = false
                    }
                }

                // Direct calling — always ACTION_CALL to avoid opening system dialer.
                // ACTION_DIAL is intentionally NOT used because it opens the full dialer UI.
                // CALL_PHONE is auto-granted via Device Owner setPermissionGrantState.
                "makePhoneCall" -> {
                    val number = call.argument<String>("number") ?: ""
                    if (number.isNotEmpty()) {
                        val cleanNumber = number.replace(Regex("[^0-9+]"), "")
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val comp = ComponentName(this, MyDeviceAdminReceiver::class.java)

                        // Re-grant CALL_PHONE right before calling (in case it was reset)
                        if (dpm.isDeviceOwnerApp(packageName)) {
                            try {
                                dpm.setPermissionGrantState(
                                    comp, packageName,
                                    android.Manifest.permission.CALL_PHONE,
                                    DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                                )
                            } catch (_: Exception) {}
                        }

                        // Check if permission is actually granted before attempting call
                        val hasCallPermission = checkSelfPermission(android.Manifest.permission.CALL_PHONE) ==
                            android.content.pm.PackageManager.PERMISSION_GRANTED

                        android.util.Log.d("MainActivity", "makePhoneCall: number=$cleanNumber, CALL_PHONE granted=$hasCallPermission, kioskActive=$isKioskActive")

                        if (!hasCallPermission) {
                            result.error("PERMISSION_DENIED", "CALL_PHONE not granted", null)
                            return@setMethodCallHandler
                        }

                        // If kiosk is active, temporarily stop lock task so the dialer can launch.
                        // The dialer is whitelisted in setLockTaskPackages, but stopLockTask ensures
                        // Android can switch to the dialer activity without restriction.
                        val wasKioskActive = isKioskActive
                        if (wasKioskActive) {
                            try {
                                stopLockTask()
                                android.util.Log.d("MainActivity", "stopLockTask() called before emergency call")
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "stopLockTask before call failed: ${e.message}")
                            }
                        }

                        isOpeningSettings = true

                        // Try ACTION_CALL first (direct call, no dialer UI confirmation).
                        // Fall back to ACTION_DIAL if ACTION_CALL is blocked by system.
                        var callStarted = false
                        try {
                            val callIntent = android.content.Intent(android.content.Intent.ACTION_CALL).apply {
                                data = android.net.Uri.parse("tel:$cleanNumber")
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(callIntent)
                            callStarted = true
                            android.util.Log.d("MainActivity", "ACTION_CALL launched for $cleanNumber")
                        } catch (e: SecurityException) {
                            android.util.Log.e("MainActivity", "ACTION_CALL SecurityException, trying ACTION_DIAL: ${e.message}")
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "ACTION_CALL failed, trying ACTION_DIAL: ${e.message}")
                        }

                        // Fallback: ACTION_DIAL opens the dialer with number pre-filled
                        if (!callStarted) {
                            try {
                                val dialIntent = android.content.Intent(android.content.Intent.ACTION_DIAL).apply {
                                    data = android.net.Uri.parse("tel:$cleanNumber")
                                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                startActivity(dialIntent)
                                callStarted = true
                                android.util.Log.d("MainActivity", "ACTION_DIAL fallback launched for $cleanNumber")
                            } catch (e: Exception) {
                                android.util.Log.e("MainActivity", "ACTION_DIAL also failed: ${e.message}")
                            }
                        }

                        if (callStarted) {
                            result.success(true)
                        } else {
                            // Both attempts failed — restore kiosk and reset flags
                            isOpeningSettings = false
                            if (wasKioskActive) {
                                try { startLockTask() } catch (_: Exception) {}
                            }
                            result.error("CALL_FAILED", "Could not launch dialer. Check permissions.", null)
                        }
                    } else {
                        result.error("INVALID_NUMBER", "Phone number is empty", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ── SMS Lock Channel ─────────────────────────────────────
        val smsPrefs = getSharedPreferences(SmsReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sms_lock_channel").setMethodCallHandler { call, result ->
            when (call.method) {
                "getSmsKey" -> {
                    val key = smsPrefs.getString(SmsReceiver.KEY_AES_SECRET, null)
                    result.success(key)
                }
                "saveSmsKey" -> {
                    val key = call.argument<String>("key") ?: ""
                    if (key.length != 32) {
                        result.error("INVALID", "AES key must be exactly 32 characters.", null)
                    } else {
                        smsPrefs.edit().putString(SmsReceiver.KEY_AES_SECRET, key).apply()
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── Device Info Channel ───────────────────────────────────
        val deviceInfoMgr = DeviceInfoManager(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "device_info_channel").setMethodCallHandler { call, result ->
            when (call.method) {
                "getAllInfo"     -> result.success(deviceInfoMgr.getAllInfo())
                "getImeiList"   -> result.success(deviceInfoMgr.getImeiList())
                "getSimDetails" -> result.success(deviceInfoMgr.getSimDetails())
                "getSerial"     -> result.success(deviceInfoMgr.getSerialNumber())
                "getDeviceInfo" -> result.success(deviceInfoMgr.getDeviceInfo())
                else            -> result.notImplemented()
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
                             // Whitelist our app + system settings + dialer apps for emergency calls.
                             devicePolicyManager.setLockTaskPackages(
                                 componentName, 
                                 arrayOf(
                                     packageName,
                                     // Settings (needed for WiFi configuration)
                                     "com.android.settings", 
                                     "com.google.android.settings",
                                     "com.samsung.android.settings",
                                     "com.oppo.settings",
                                     "com.vivo.settings",
                                     "com.huawei.android.settings",
                                     "com.miui.settings",
                                     "com.coloros.settings",
                                     // Dialer apps (needed for emergency calls from lock screen)
                                     "com.android.dialer",
                                     "com.google.android.dialer",
                                     "com.samsung.android.dialer",
                                     "com.coloros.dialer",
                                     "com.oppo.dialer",
                                     "com.miui.dialer",
                                     "com.vivo.dialer",
                                     "com.android.phone"
                                 )
                             )
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
                        applyKioskPoliciesIfNeeded()
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
                    } catch (e: Exception) {
                        // Ignore exceptions if kiosk mode was not active or not allowed
                    }
                    isKioskActive = false
                    result.success(true)
                    // Close app & remove from recent apps after unlock
                    finishAndRemoveTask()
                }

                "finishAndRemoveTask" -> {
                    finishAndRemoveTask()
                    result.success(true)
                }

                // ------- FACTORY RESET / OEM UNLOCK BLOCK (Requires Device Owner) -------
                "setFactoryResetAllowed" -> {
                    val allowed = call.argument<Boolean>("allowed") ?: false
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            if (!allowed) {
                                // BLOCK factory reset and safe boot (Device Owner allowed)
                                devicePolicyManager.addUserRestriction(componentName, UserManager.DISALLOW_FACTORY_RESET)
                                devicePolicyManager.addUserRestriction(componentName, UserManager.DISALLOW_SAFE_BOOT)
                                // no_oem_unlock: only carrier/system apps can set this — skip silently
                                try {
                                    devicePolicyManager.addUserRestriction(componentName, "no_oem_unlock")
                                } catch (_: Exception) {}
                            } else {
                                // Do nothing. We intentionally ignore requests to ALLOW factory reset,
                                // because factory reset must remain permanently blocked while the app is Device Owner.
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
                                devicePolicyManager.addUserRestriction(componentName, UserManager.DISALLOW_UNINSTALL_APPS)
                            } else {
                                devicePolicyManager.clearUserRestriction(componentName, UserManager.DISALLOW_REMOVE_MANAGED_PROFILE)
                                devicePolicyManager.clearUserRestriction(componentName, UserManager.DISALLOW_UNINSTALL_APPS)
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
                    val componentNameAlias = ComponentName(applicationContext, "com.example.customer_emi_app.LauncherAlias")
                    pm.setComponentEnabledSetting(
                        componentNameAlias,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
                            packageInfo.requestedPermissions?.forEach { perm ->
                                try {
                                    devicePolicyManager.setPermissionGrantState(componentName, packageName, perm, DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED)
                                } catch (e: Exception) {}
                            }
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to lock permissions", e)
                    }
                    result.success(true)
                }
                "unhideApp" -> {
                    val pm: PackageManager = applicationContext.packageManager
                    val componentNameAlias = ComponentName(applicationContext, "com.example.customer_emi_app.LauncherAlias")
                    pm.setComponentEnabledSetting(
                        componentNameAlias,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            val packageInfo = pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
                            packageInfo.requestedPermissions?.forEach { perm ->
                                try {
                                    devicePolicyManager.setPermissionGrantState(componentName, packageName, perm, DevicePolicyManager.PERMISSION_GRANT_STATE_DEFAULT)
                                } catch (e: Exception) {}
                            }
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Failed to unlock permissions", e)
                    }
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

                // ------- REMOVE DEVICE OWNER (Deprovision) -------
                "removeDeviceOwner" -> {
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            // 1. Stop kiosk mode if active
                            try { stopLockTask() } catch (_: Exception) {}
                            isKioskActive = false

                            // 2. Clear lock task packages
                            try {
                                devicePolicyManager.setLockTaskPackages(componentName, emptyArray())
                            } catch (_: Exception) {}

                            // 3. Clear all user restrictions set by us
                            val restrictions = listOf(
                                UserManager.DISALLOW_FACTORY_RESET,
                                UserManager.DISALLOW_SAFE_BOOT,
                                UserManager.DISALLOW_REMOVE_MANAGED_PROFILE,
                                UserManager.DISALLOW_UNINSTALL_APPS,
                                "no_oem_unlock"
                            )
                            for (r in restrictions) {
                                try { devicePolicyManager.clearUserRestriction(componentName, r) } catch (_: Exception) {}
                            }

                            // 4. Unblock uninstall
                            try {
                                devicePolicyManager.setUninstallBlocked(componentName, packageName, false)
                            } catch (_: Exception) {}

                            // 5. Clear Device Owner — this also removes Device Admin
                            devicePolicyManager.clearDeviceOwnerApp(packageName)

                            result.success(true)
                        } else if (devicePolicyManager.isAdminActive(componentName)) {
                            // Fallback: only a Device Admin (not owner), just remove admin
                            devicePolicyManager.removeActiveAdmin(componentName)
                            result.success(true)
                        } else {
                            result.success(false) // Already not admin/owner
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                "uninstallApp" -> {
                    try {
                        val intent = Intent(Intent.ACTION_DELETE)
                        intent.data = Uri.parse("package:$packageName")
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }

                // ── Remove Device Screen Lock (PIN / Password / Fingerprint / Face) ──
                // Uses resetPasswordWithToken (API 26+) for Android 8+ — works even after
                // user has set a password, as long as the token was registered on app setup.
                // Falls back to deprecated resetPassword for older devices.
                "resetDevicePassword" -> {
                    try {
                        if (!devicePolicyManager.isDeviceOwnerApp(packageName)) {
                            android.util.Log.w("MainActivity", "resetDevicePassword: Not device owner")
                            result.error("NOT_DEVICE_OWNER", "App is not Device Owner. Cannot reset password.", null)
                            return@setMethodCallHandler
                        }

                        // ── Android 8+ (API 26+): token-based approach ──────────────────
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            val prefs = getSharedPreferences(
                                MyDeviceAdminReceiver.PREFS_NAME, Context.MODE_PRIVATE
                            )
                            val tokenHex = prefs.getString(MyDeviceAdminReceiver.KEY_RESET_TOKEN, null)

                            if (tokenHex != null) {
                                val token = MyDeviceAdminReceiver.hexToBytes(tokenHex)

                                // Check token is active
                                val isActive = try {
                                    devicePolicyManager.isResetPasswordTokenActive(componentName)
                                } catch (e: Exception) { false }

                                android.util.Log.d("MainActivity", "resetDevicePassword: tokenHex present, isActive=$isActive")

                                if (isActive) {
                                    // First, remove all password quality constraints so empty string is accepted
                                    try {
                                        devicePolicyManager.setPasswordQuality(
                                            componentName,
                                            DevicePolicyManager.PASSWORD_QUALITY_UNSPECIFIED
                                        )
                                        devicePolicyManager.setPasswordMinimumLength(componentName, 0)
                                    } catch (e: Exception) {
                                        android.util.Log.w("MainActivity", "Could not set PASSWORD_QUALITY_UNSPECIFIED: ${e.message}")
                                    }

                                    val success = devicePolicyManager.resetPasswordWithToken(
                                        componentName, "", token, 0
                                    )
                                    android.util.Log.d("MainActivity", "resetPasswordWithToken result: $success")
                                    result.success(success)
                                    return@setMethodCallHandler
                                } else {
                                    // Token not active yet — try to re-register it
                                    android.util.Log.w("MainActivity", "Token not active. Attempting re-registration...")
                                    try {
                                        val reReg = devicePolicyManager.setResetPasswordToken(componentName, token)
                                        android.util.Log.d("MainActivity", "Re-registration result: $reReg")
                                        if (reReg && devicePolicyManager.isResetPasswordTokenActive(componentName)) {
                                            try {
                                                devicePolicyManager.setPasswordQuality(
                                                    componentName,
                                                    DevicePolicyManager.PASSWORD_QUALITY_UNSPECIFIED
                                                )
                                                devicePolicyManager.setPasswordMinimumLength(componentName, 0)
                                            } catch (e: Exception) {}
                                            val success = devicePolicyManager.resetPasswordWithToken(
                                                componentName, "", token, 0
                                            )
                                            android.util.Log.d("MainActivity", "resetPasswordWithToken after re-reg: $success")
                                            result.success(success)
                                            return@setMethodCallHandler
                                        }
                                    } catch (e: Exception) {
                                        android.util.Log.w("MainActivity", "Re-registration failed: ${e.message}")
                                    }

                                    // Token still not active — generate a new one and try
                                    android.util.Log.w("MainActivity", "Generating fresh token as last resort...")
                                    try {
                                        val newToken = ByteArray(32)
                                        java.security.SecureRandom().nextBytes(newToken)
                                        val newReg = devicePolicyManager.setResetPasswordToken(componentName, newToken)
                                        if (newReg) {
                                            prefs.edit().putString(
                                                MyDeviceAdminReceiver.KEY_RESET_TOKEN,
                                                MyDeviceAdminReceiver.bytesToHex(newToken)
                                            ).apply()
                                            android.util.Log.d("MainActivity", "Fresh token registered: $newReg")
                                        }
                                    } catch (e: Exception) {
                                        android.util.Log.w("MainActivity", "Fresh token generation failed: ${e.message}")
                                    }

                                    result.error(
                                        "TOKEN_NOT_ACTIVE",
                                        "Reset token is not active. A new token has been registered — please try again after the user unlocks the device once.",
                                        null
                                    )
                                    return@setMethodCallHandler
                                }
                            } else {
                                // No stored token — generate one now (works if no password is set yet)
                                android.util.Log.w("MainActivity", "No stored token found. Registering token now...")
                                MyDeviceAdminReceiver.generateAndSetResetToken(this)
                                result.error(
                                    "TOKEN_NOT_SET",
                                    "Reset token was just registered. Please unlock the device once, then try again.",
                                    null
                                )
                                return@setMethodCallHandler
                            }
                        }

                        // ── Android < 8 (API < 26): legacy deprecated approach ───────────
                        android.util.Log.d("MainActivity", "Using legacy resetPassword for Android < 8")
                        @Suppress("DEPRECATION")
                        val success = devicePolicyManager.resetPassword("", 0)
                        android.util.Log.d("MainActivity", "Legacy resetPassword result: $success")
                        result.success(success)

                    } catch (e: SecurityException) {
                        android.util.Log.e("MainActivity", "resetDevicePassword SecurityException: ${e.message}")
                        result.error("SECURITY_ERROR", e.message, null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "resetDevicePassword error: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                }

                "silentUpdate" -> {
                    val urlString = call.argument<String>("url")
                    val versionStr = call.argument<String>("version") ?: "Unknown"
                    if (urlString.isNullOrEmpty()) {
                        result.error("INVALID_URL", "App URL is empty", null)
                        return@setMethodCallHandler
                    }
                    if (!devicePolicyManager.isDeviceOwnerApp(packageName)) {
                        result.error("NOT_DEVICE_OWNER", "App must be device owner to perform silent update", null)
                        return@setMethodCallHandler
                    }
                    
                    result.success(true) // Return early so Dart isn't blocked
                    
                    thread {
                        val uiHandler = android.os.Handler(android.os.Looper.getMainLooper())
                        val logToDart = { status: String, progress: Int ->
                            uiHandler.post {
                                try {
                                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                                        .invokeMethod("logUpdateProgress", mapOf(
                                            "status" to status,
                                            "progress" to progress,
                                            "version" to versionStr
                                        ))
                                } catch (e: Exception) {}
                            }
                        }
                        
                        try {
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val channel = NotificationChannel("update_channel", "App Updates", NotificationManager.IMPORTANCE_LOW)
                                notificationManager.createNotificationChannel(channel)
                            }
                            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                android.app.Notification.Builder(applicationContext, "update_channel")
                            } else {
                                android.app.Notification.Builder(applicationContext)
                            }
                            builder.setSmallIcon(android.R.drawable.stat_sys_download)
                                .setContentTitle("Downloading App Update")
                                .setContentText("Connecting...")
                                .setProgress(100, 0, true)
                                .setOngoing(true)
                            notificationManager.notify(999, builder.build())
                            
                            var url = URL(urlString)
                            var connection: HttpURLConnection
                            var redirectCount = 0
                            
                            while (true) {
                                connection = url.openConnection() as HttpURLConnection
                                connection.requestMethod = "GET"
                                connection.setRequestProperty("Accept-Encoding", "identity")
                                connection.setRequestProperty("Connection", "close")
                                connection.instanceFollowRedirects = false
                                connection.connect()
                                
                                val status = connection.responseCode
                                if (status == HttpURLConnection.HTTP_MOVED_TEMP ||
                                    status == HttpURLConnection.HTTP_MOVED_PERM ||
                                    status == HttpURLConnection.HTTP_SEE_OTHER ||
                                    status == 307 || status == 308) {
                                    
                                    val newUrl = connection.getHeaderField("Location")
                                    connection.disconnect()
                                    if (newUrl == null) {
                                        android.util.Log.e("MainActivity", "Redirect location is null")
                                        return@thread
                                    }
                                    url = URL(newUrl)
                                    redirectCount++
                                    if (redirectCount > 5) {
                                        android.util.Log.e("MainActivity", "Too many redirects")
                                        return@thread
                                    }
                                } else {
                                    break
                                }
                            }
                            
                            if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                                android.util.Log.e("MainActivity", "Server returned HTTP ${connection.responseCode} ${connection.responseMessage}")
                                return@thread
                            }
                            
                            val totalSize = connection.contentLength
                            val apkFile = File(applicationContext.cacheDir, "update.apk")
                            val input = connection.inputStream
                            val output = FileOutputStream(apkFile)
                            
                            val data = ByteArray(4096)
                            var count: Int
                            var downloadedSize = 0L
                            var lastProgress = -1
                            var lastMbLogged = -1L
                            
                            while (input.read(data).also { count = it } != -1) {
                                output.write(data, 0, count)
                                downloadedSize += count
                                if (totalSize > 0) {
                                    val progress = ((downloadedSize * 100) / totalSize).toInt()
                                    if (progress > lastProgress) {
                                        builder.setProgress(100, progress, false)
                                        builder.setContentText("$progress% downloaded")
                                        notificationManager.notify(999, builder.build())
                                        lastProgress = progress
                                    }
                                } else {
                                    // Unknown size, just log megabytes
                                    val mbDownloaded = downloadedSize / (1024 * 1024)
                                    if (mbDownloaded > lastMbLogged) {
                                        builder.setProgress(100, 0, true)
                                        builder.setContentText("$mbDownloaded MB downloaded")
                                        notificationManager.notify(999, builder.build())
                                        lastMbLogged = mbDownloaded
                                    }
                                }
                            }
                            output.flush()
                            output.close()
                            input.close()
                            
                            builder.setContentTitle("Installing Update...")
                            builder.setProgress(0, 0, true)
                            builder.setContentText("Please wait")
                            notificationManager.notify(999, builder.build())
                            
                            val packageInstaller = packageManager.packageInstaller
                            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
                            params.setAppPackageName(packageName)
                            val sessionId = packageInstaller.createSession(params)
                            val session = packageInstaller.openSession(sessionId)
                            
                            val out = session.openWrite("package", 0, apkFile.length())
                            val apkStream = FileInputStream(apkFile)
                            val buffer = ByteArray(65536)
                            var c: Int
                            while (apkStream.read(buffer).also { c = it } != -1) {
                                out.write(buffer, 0, c)
                            }
                            session.fsync(out)
                            apkStream.close()
                            out.close()
                            
                            val intent = Intent("com.example.customer_emi_app.UPDATE_STATUS")
                            val pendingIntent = PendingIntent.getBroadcast(
                                applicationContext,
                                0,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            logToDart("Setup Initialized Successfully", 100)
                            session.commit(pendingIntent.intentSender)
                            
                            builder.setContentTitle("Update Downloaded")
                            builder.setContentText("Waiting for Android to install...")
                            builder.setProgress(0, 0, false)
                            builder.setOngoing(false)
                            notificationManager.notify(999, builder.build())
                            
                        } catch (e: Exception) {
                            logToDart("Failed: ${e.message}", 0)
                            android.util.Log.e("MainActivity", "Silent Update Failed", e)
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                android.app.Notification.Builder(applicationContext, "update_channel")
                            } else {
                                android.app.Notification.Builder(applicationContext)
                            }
                            builder.setSmallIcon(android.R.drawable.stat_notify_error)
                                .setContentTitle("Update Failed")
                                .setContentText(e.message)
                                .setOngoing(false)
                            notificationManager.notify(999, builder.build())
                        }
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun enforceCoreSecurityPolicies() {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(this, MyDeviceAdminReceiver::class.java)

            if (dpm.isDeviceOwnerApp(packageName)) {
                // Unconditionally block factory reset, safe boot, and OEM unlock
                dpm.addUserRestriction(adminComponent, android.os.UserManager.DISALLOW_FACTORY_RESET)
                dpm.addUserRestriction(adminComponent, android.os.UserManager.DISALLOW_SAFE_BOOT)
                try {
                    dpm.addUserRestriction(adminComponent, "no_oem_unlock")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "OEM Unlock restriction not supported", e)
                }
                android.util.Log.d("MainActivity", "Core security policies (Factory Reset & OEM Unlock block) enforced on startup")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error enforcing core security policies", e)
        }
    }
}
