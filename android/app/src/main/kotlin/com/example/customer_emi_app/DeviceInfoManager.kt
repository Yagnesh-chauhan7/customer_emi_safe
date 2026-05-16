package com.example.customer_emi_app

import android.Manifest
import android.annotation.SuppressLint
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat

class DeviceInfoManager(private val context: Context) {

    private val TAG = "DeviceInfoManager"

    private val devicePolicyManager: DevicePolicyManager =
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val adminComponentName = ComponentName(context, MyDeviceAdminReceiver::class.java)

    private val telephonyManager: TelephonyManager =
        context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

    private fun hasPhonePermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED

    private fun hasPhoneNumberPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_NUMBERS) ==
                    PackageManager.PERMISSION_GRANTED
        } else {
            hasPhonePermission()
        }

    // ─────────────────────────────────────────
    // IMEI — Device Owner can use DPM.getImei()
    // ─────────────────────────────────────────
    @SuppressLint("HardwareIds", "MissingPermission")
    fun getImeiList(): List<String> {
        val result = mutableListOf<String>()
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                getImeiListApi26(result)
            } else if (hasPhonePermission()) {
                @Suppress("DEPRECATION")
                val imei = telephonyManager.deviceId
                if (!imei.isNullOrBlank()) result.add(imei)
            }
            result
        } catch (e: Exception) {
            Log.e(TAG, "Error getting IMEI: ${e.message}")
            result
        }
    }

    // Separate @RequiresApi function so the Kotlin compiler accepts getImei() calls
    @RequiresApi(Build.VERSION_CODES.O)
    @SuppressLint("HardwareIds", "MissingPermission")
    private fun getImeiListApi26(result: MutableList<String>) {
        if (devicePolicyManager.isDeviceOwnerApp(context.packageName)) {
            // Device Owner path: use reflection to call DPM.getImei(ComponentName, int)
            // This avoids compiler "Unresolved reference" in some Kotlin/SDK stub combos
            try {
                val dpmGetImei = DevicePolicyManager::class.java
                    .getMethod("getImei", ComponentName::class.java, Int::class.javaPrimitiveType)
                val imei0 = dpmGetImei.invoke(devicePolicyManager, adminComponentName, 0) as? String
                if (!imei0.isNullOrBlank()) result.add(imei0)
                try {
                    val imei1 = dpmGetImei.invoke(devicePolicyManager, adminComponentName, 1) as? String
                    if (!imei1.isNullOrBlank()) result.add(imei1)
                } catch (_: Exception) {}
            } catch (e: Exception) {
                Log.e(TAG, "DPM getImei reflection failed: ${e.message}")
            }
        }

        // TelephonyManager path: also via reflection for the same reason
        if (result.isEmpty() && hasPhonePermission()) {
            try {
                val tmGetImei = TelephonyManager::class.java
                    .getMethod("getImei", Int::class.javaPrimitiveType)
                val imei0 = tmGetImei.invoke(telephonyManager, 0) as? String
                if (!imei0.isNullOrBlank()) result.add(imei0)
                try {
                    val imei1 = tmGetImei.invoke(telephonyManager, 1) as? String
                    if (!imei1.isNullOrBlank()) result.add(imei1)
                } catch (_: Exception) {}
            } catch (e: Exception) {
                Log.e(TAG, "TM getImei reflection failed: ${e.message}")
            }
        }
    }

    // ─────────────────────────────────────────
    // Serial Number
    // ─────────────────────────────────────────
    @SuppressLint("HardwareIds", "MissingPermission")
    fun getSerialNumber(): String {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (hasPhonePermission()) {
                    Build.getSerial()
                } else {
                    "Permission required (READ_PHONE_STATE)"
                }
            } else {
                @Suppress("DEPRECATION")
                Build.SERIAL
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting serial: ${e.message}")
            "Unavailable: ${e.message}"
        }
    }

    // ─────────────────────────────────────────
    // SIM Details (supports dual SIM)
    // ─────────────────────────────────────────
    @SuppressLint("HardwareIds", "MissingPermission")
    fun getSimDetails(): List<Map<String, String>> {
        val simList = mutableListOf<Map<String, String>>()

        if (!hasPhonePermission()) {
            return listOf(mapOf("error" to "READ_PHONE_STATE permission required"))
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val subManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE)
                        as SubscriptionManager

                val subscriptions: List<SubscriptionInfo> =
                    subManager.activeSubscriptionInfoList ?: emptyList()

                for (sub in subscriptions) {
                    val slotIndex = sub.simSlotIndex
                    val tm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        telephonyManager.createForSubscriptionId(sub.subscriptionId)
                    } else {
                        telephonyManager
                    }

                    val phoneNumber = if (hasPhoneNumberPermission()) {
                        try {
                            sub.number?.takeIf { it.isNotBlank() }
                                ?: tm.line1Number?.takeIf { it.isNotBlank() }
                                ?: "Not available"
                        } catch (_: Exception) { "Not available" }
                    } else {
                        "Permission required (READ_PHONE_NUMBERS)"
                    }

                    @Suppress("DEPRECATION")
                    val simSerial = try {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            tm.simSerialNumber?.takeIf { it.isNotBlank() } ?: "N/A"
                        } else { "Restricted (API 29+)" }
                    } catch (_: Exception) { "N/A" }

                    simList.add(mapOf(
                        "slot"           to "SIM ${slotIndex + 1}",
                        "carrierName"    to (sub.carrierName?.toString() ?: "Unknown"),
                        "displayName"    to (sub.displayName?.toString() ?: "Unknown"),
                        "phoneNumber"    to phoneNumber,
                        "countryIso"     to (sub.countryIso?.uppercase() ?: "N/A"),
                        "mcc"            to (sub.mcc.toString()),
                        "mnc"            to (sub.mnc.toString()),
                        "simState"       to simStateLabel(tm.simState),
                        "simSerial"      to simSerial,
                        "networkType"    to networkTypeLabel(tm.networkType),
                        "roaming"        to if (tm.isNetworkRoaming) "Yes" else "No",
                    ))
                }
            } else {
                // Fallback for old devices
                val phoneNumber = if (hasPhoneNumberPermission()) {
                    telephonyManager.line1Number?.takeIf { it.isNotBlank() } ?: "N/A"
                } else { "Permission required" }

                simList.add(mapOf(
                    "slot"        to "SIM 1",
                    "carrierName" to (telephonyManager.simOperatorName ?: "Unknown"),
                    "displayName" to (telephonyManager.simOperatorName ?: "Unknown"),
                    "phoneNumber" to phoneNumber,
                    "countryIso"  to (telephonyManager.simCountryIso?.uppercase() ?: "N/A"),
                    "mcc"         to "",
                    "mnc"         to "",
                    "simState"    to simStateLabel(telephonyManager.simState),
                    "simSerial"   to "N/A",
                    "networkType" to networkTypeLabel(telephonyManager.networkType),
                    "roaming"     to if (telephonyManager.isNetworkRoaming) "Yes" else "No",
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting SIM details: ${e.message}")
            simList.add(mapOf("error" to "Error: ${e.message}"))
        }

        return simList
    }

    // ─────────────────────────────────────────
    // Device build info (no permission needed)
    // ─────────────────────────────────────────
    fun getDeviceInfo(): Map<String, String> {
        return mapOf(
            "brand"        to Build.BRAND,
            "model"        to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "device"       to Build.DEVICE,
            "product"      to Build.PRODUCT,
            "androidVersion" to Build.VERSION.RELEASE,
            "sdkInt"       to Build.VERSION.SDK_INT.toString(),
            "buildId"      to Build.ID,
            "fingerprint"  to Build.FINGERPRINT,
        )
    }

    // ─────────────────────────────────────────
    // Full info bundle
    // ─────────────────────────────────────────
    fun getAllInfo(): Map<String, Any> {
        return mapOf(
            "imeiList"     to getImeiList(),
            "serialNumber" to getSerialNumber(),
            "simDetails"   to getSimDetails(),
            "deviceInfo"   to getDeviceInfo(),
        )
    }

    private fun simStateLabel(state: Int): String = when (state) {
        TelephonyManager.SIM_STATE_ABSENT       -> "Absent"
        TelephonyManager.SIM_STATE_READY        -> "Ready"
        TelephonyManager.SIM_STATE_PIN_REQUIRED -> "PIN Required"
        TelephonyManager.SIM_STATE_PUK_REQUIRED -> "PUK Required"
        TelephonyManager.SIM_STATE_NETWORK_LOCKED -> "Network Locked"
        TelephonyManager.SIM_STATE_UNKNOWN      -> "Unknown"
        else                                    -> "State $state"
    }

    @Suppress("DEPRECATION")
    private fun networkTypeLabel(type: Int): String = when (type) {
        TelephonyManager.NETWORK_TYPE_LTE   -> "4G LTE"
        TelephonyManager.NETWORK_TYPE_NR    -> "5G NR"
        TelephonyManager.NETWORK_TYPE_HSDPA,
        TelephonyManager.NETWORK_TYPE_HSPA,
        TelephonyManager.NETWORK_TYPE_HSPAP -> "3G HSPA"
        TelephonyManager.NETWORK_TYPE_UMTS  -> "3G UMTS"
        TelephonyManager.NETWORK_TYPE_EDGE,
        TelephonyManager.NETWORK_TYPE_GPRS  -> "2G"
        TelephonyManager.NETWORK_TYPE_CDMA  -> "CDMA"
        TelephonyManager.NETWORK_TYPE_UNKNOWN -> "Unknown"
        else                                 -> "Type $type"
    }
}
