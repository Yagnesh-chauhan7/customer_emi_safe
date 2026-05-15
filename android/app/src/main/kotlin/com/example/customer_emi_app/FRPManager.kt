package com.example.customer_emi_app

import android.app.admin.DevicePolicyManager
import android.app.admin.FactoryResetProtectionPolicy
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.util.Log

class FRPManager(private val context: Context) {

    private val devicePolicyManager: DevicePolicyManager = 
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val adminComponentName = ComponentName(context, MyDeviceAdminReceiver::class.java)

    fun enableFRP(accounts: List<String>): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return mapOf("success" to false, "error" to "Unsupported Android version. API 30+ required.")
        }
        
        try {
            if (!devicePolicyManager.isDeviceOwnerApp(context.packageName)) {
                return mapOf("success" to false, "error" to "App is not Device Owner.")
            }

            val policy = FactoryResetProtectionPolicy.Builder()
                .setFactoryResetProtectionAccounts(accounts)
                .setFactoryResetProtectionEnabled(true)
                .build()

            devicePolicyManager.setFactoryResetProtectionPolicy(adminComponentName, policy)
            Log.d("FRPManager", "FRP Enabled successfully with accounts: $accounts")
            return mapOf("success" to true)
        } catch (e: SecurityException) {
            Log.e("FRPManager", "SecurityException enabling FRP: ${e.message}")
            return mapOf("success" to false, "error" to "SecurityException: ${e.message}")
        } catch (e: Exception) {
            Log.e("FRPManager", "Error enabling FRP: ${e.message}")
            return mapOf("success" to false, "error" to e.message.toString())
        }
    }

    fun disableFRP(): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return mapOf("success" to false, "error" to "Unsupported Android version. API 30+ required.")
        }

        try {
            if (!devicePolicyManager.isDeviceOwnerApp(context.packageName)) {
                return mapOf("success" to false, "error" to "App is not Device Owner.")
            }

            // A null policy removes the FRP policy, falling back to device defaults
            devicePolicyManager.setFactoryResetProtectionPolicy(adminComponentName, null)
            Log.d("FRPManager", "FRP Disabled successfully")
            return mapOf("success" to true)
        } catch (e: SecurityException) {
            Log.e("FRPManager", "SecurityException disabling FRP: ${e.message}")
            return mapOf("success" to false, "error" to "SecurityException: ${e.message}")
        } catch (e: Exception) {
            Log.e("FRPManager", "Error disabling FRP: ${e.message}")
            return mapOf("success" to false, "error" to e.message.toString())
        }
    }

    fun isFRPEnabled(): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return mapOf("success" to false, "error" to "Unsupported Android version. API 30+ required.", "status" to false)
        }

        try {
            if (!devicePolicyManager.isDeviceOwnerApp(context.packageName)) {
                return mapOf("success" to false, "error" to "App is not Device Owner.", "status" to false)
            }

            val policy = devicePolicyManager.getFactoryResetProtectionPolicy(adminComponentName)
            val isEnabled = policy?.isFactoryResetProtectionEnabled ?: false
            val accounts = policy?.factoryResetProtectionAccounts ?: emptyList()
            
            return mapOf(
                "success" to true, 
                "status" to isEnabled,
                "accounts" to accounts
            )
        } catch (e: SecurityException) {
            Log.e("FRPManager", "SecurityException getting FRP status: ${e.message}")
            return mapOf("success" to false, "error" to "SecurityException: ${e.message}", "status" to false)
        } catch (e: Exception) {
            Log.e("FRPManager", "Error getting FRP status: ${e.message}")
            return mapOf("success" to false, "error" to e.message.toString(), "status" to false)
        }
    }
}
