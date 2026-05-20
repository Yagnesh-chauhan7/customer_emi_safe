package com.example.customer_emi_app

import android.app.admin.DevicePolicyManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Log

class DeviceConnectivityManager(private val context: Context) {

    private val TAG = "ConnectivityManager"

    private val devicePolicyManager: DevicePolicyManager =
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val adminComponentName: ComponentName
        get() {
            val legacyAdmin = ComponentName(context, AdminReceiver::class.java)
            val myAdmin = ComponentName(context, MyDeviceAdminReceiver::class.java)
            return if (devicePolicyManager.isAdminActive(legacyAdmin)) legacyAdmin else myAdmin
        }

    private val wifiManager: WifiManager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        val bluetoothManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothManager.adapter
    }

    // ─────────────────────────────────────────────────────────────
    // WIFI
    // Android 10 (API 29)+ blocked WifiManager.setWifiEnabled() for
    // all non-system apps, including Device Owners.
    // setGlobalSetting("wifi_on") is also blocked on modern Android.
    // Best approach: open the system WiFi panel for user interaction.
    // ─────────────────────────────────────────────────────────────

    fun setWifiEnabled(enabled: Boolean): Map<String, Any> {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                // Android 9 and below: programmatic toggle works
                @Suppress("DEPRECATION")
                val result = wifiManager.setWifiEnabled(enabled)
                if (result) {
                    mapOf("success" to true)
                } else {
                    openWifiSettings()
                    mapOf("success" to false,
                        "openSettings" to true,
                        "error" to "Could not toggle WiFi. Settings panel opened.")
                }
            } else {
                // Android 10+: open WiFi settings panel
                openWifiSettings()
                mapOf(
                    "success" to false,
                    "openSettings" to true,
                    "error" to "Android 10+ restricts programmatic WiFi toggle. WiFi settings opened."
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting WiFi: ${e.message}")
            mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun openWifiSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Intent(Settings.Panel.ACTION_WIFI)
        } else {
            Intent(Settings.ACTION_WIFI_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun getWifiStatus(): Map<String, Any> {
        return try {
            mapOf("success" to true, "enabled" to wifiManager.isWifiEnabled)
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "Unknown error"), "enabled" to false)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // MOBILE DATA
    // Android Device Policy explicitly blocks setting "mobile_data"
    // via setGlobalSetting for Device Owner apps.
    // Open the Internet Connectivity panel instead.
    // ─────────────────────────────────────────────────────────────

    fun setMobileDataEnabled(enabled: Boolean): Map<String, Any> {
        return try {
            openMobileDataSettings()
            mapOf(
                "success" to false,
                "openSettings" to true,
                "error" to "Mobile data cannot be toggled programmatically. Settings panel opened."
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error opening mobile data settings: ${e.message}")
            mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    private fun openMobileDataSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY)
        } else {
            Intent(Settings.ACTION_DATA_ROAMING_SETTINGS)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun getMobileDataStatus(): Map<String, Any> {
        return try {
            val connectivityManager =
                context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val activeNetwork = connectivityManager.activeNetwork
            val caps = connectivityManager.getNetworkCapabilities(activeNetwork)
            val hasMobile = caps?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true
            mapOf("success" to true, "enabled" to hasMobile)
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "Unknown error"), "enabled" to false)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // BLUETOOTH
    // Works on Android ≤ 12 via deprecated adapter.enable()/disable().
    // Android 13+: programmatic toggle is fully blocked → open settings.
    // Note: state change is async; Flutter side must wait before refresh.
    // ─────────────────────────────────────────────────────────────

    fun setBluetoothEnabled(enabled: Boolean): Map<String, Any> {
        return try {
            val adapter = bluetoothAdapter
                ?: return mapOf("success" to false, "error" to "Bluetooth not supported on this device.")

            // Already in desired state — no-op
            if (adapter.isEnabled == enabled) {
                return mapOf("success" to true, "alreadyInState" to true)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+: open Bluetooth settings panel
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return mapOf(
                    "success" to false,
                    "openSettings" to true,
                    "error" to "Android 13+ blocks programmatic Bluetooth toggle. Settings opened."
                )
            }

            @Suppress("DEPRECATION", "MissingPermission")
            val result = if (enabled) adapter.enable() else adapter.disable()

            Log.d(TAG, "Bluetooth set to $enabled → result=$result")
            if (result) {
                mapOf("success" to true)
            } else {
                mapOf("success" to false, "error" to "Bluetooth state change failed.")
            }
        } catch (e: SecurityException) {
            mapOf("success" to false, "error" to "Permission denied: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting Bluetooth: ${e.message}")
            mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    fun getBluetoothStatus(): Map<String, Any> {
        return try {
            val adapter = bluetoothAdapter
                ?: return mapOf("success" to true, "enabled" to false, "supported" to false)
            mapOf("success" to true, "enabled" to adapter.isEnabled, "supported" to true)
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "Unknown error"), "enabled" to false)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // LOCATION
    // setSecureSetting(LOCATION_MODE) is deprecated and blocked on
    // Android 12+. Only setLocationEnabled() (API 31+) is supported.
    // For Android < 12, open location settings.
    // ─────────────────────────────────────────────────────────────

    fun setLocationEnabled(enabled: Boolean): Map<String, Any> {
        return try {
            if (devicePolicyManager.isDeviceOwnerApp(context.packageName)) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    devicePolicyManager.setLocationEnabled(adminComponentName, enabled)
                    Log.d(TAG, "Location set to $enabled via setLocationEnabled()")
                    mapOf("success" to true)
                } else {
                    // API < 31: no Device Owner API to toggle location → open settings
                    val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    mapOf(
                        "success" to false,
                        "openSettings" to true,
                        "error" to "Location toggle requires Android 12+. Settings opened."
                    )
                }
            } else {
                mapOf(
                    "success" to false,
                    "error" to "Device Owner permission is required to toggle Location."
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting Location: ${e.message}")
            mapOf("success" to false, "error" to (e.message ?: "Unknown error"))
        }
    }

    fun getLocationStatus(): Map<String, Any> {
        return try {
            val locationManager =
                context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val isEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                locationManager.isLocationEnabled
            } else {
                @Suppress("DEPRECATION")
                Settings.Secure.getInt(
                    context.contentResolver,
                    Settings.Secure.LOCATION_MODE,
                    Settings.Secure.LOCATION_MODE_OFF
                ) != Settings.Secure.LOCATION_MODE_OFF
            }
            mapOf("success" to true, "enabled" to isEnabled)
        } catch (e: Exception) {
            mapOf("success" to false, "error" to (e.message ?: "Unknown error"), "enabled" to false)
        }
    }
}
