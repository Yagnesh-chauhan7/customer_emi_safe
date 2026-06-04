package com.example.customer_emi_app

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.Manifest
import java.security.SecureRandom

class MyDeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        const val PREFS_NAME = "emi_admin_prefs"
        const val KEY_RESET_TOKEN = "reset_password_token"
        const val TOKEN_SIZE = 32 // must be >= 32 bytes

        /**
         * Generates a cryptographically random 32-byte token, stores it in
         * SharedPreferences, and registers it with DevicePolicyManager so that
         * resetPasswordWithToken() can be used later — even after the user sets a
         * PIN / password / biometric.
         *
         * Must be called while the app is Device Owner and BEFORE any password is
         * set (i.e., immediately on onEnabled / onProfileProvisioningComplete).
         */
        fun generateAndSetResetToken(context: Context) {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = ComponentName(context, MyDeviceAdminReceiver::class.java)

            if (!dpm.isDeviceOwnerApp(context.packageName)) return
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return // API 26+

            try {
                val prefs: SharedPreferences =
                    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

                // Reuse existing token if already set and active
                val existingHex = prefs.getString(KEY_RESET_TOKEN, null)
                if (existingHex != null) {
                    val existingToken = hexToBytes(existingHex)
                    try {
                        if (dpm.isResetPasswordTokenActive(adminComponent)) {
                            Log.d("MyDeviceAdminReceiver", "Reset token already active — skipping regeneration")
                            return
                        }
                        // Token exists but not active yet — try re-registering it
                        val success = dpm.setResetPasswordToken(adminComponent, existingToken)
                        if (success) {
                            Log.d("MyDeviceAdminReceiver", "Existing token re-registered successfully")
                            return
                        }
                    } catch (e: Exception) {
                        Log.w("MyDeviceAdminReceiver", "Error checking existing token, generating new one: ${e.message}")
                    }
                }

                // Generate new random token
                val token = ByteArray(TOKEN_SIZE)
                SecureRandom().nextBytes(token)
                val tokenHex = bytesToHex(token)

                val success = dpm.setResetPasswordToken(adminComponent, token)
                if (success) {
                    prefs.edit().putString(KEY_RESET_TOKEN, tokenHex).apply()
                    Log.d("MyDeviceAdminReceiver", "Reset password token generated and registered successfully")
                } else {
                    Log.w("MyDeviceAdminReceiver", "setResetPasswordToken returned false — device may not support token-based reset")
                }
            } catch (e: Exception) {
                Log.e("MyDeviceAdminReceiver", "Error generating reset token: ${e.message}", e)
            }
        }

        fun bytesToHex(bytes: ByteArray): String =
            bytes.joinToString("") { "%02x".format(it) }

        fun hexToBytes(hex: String): ByteArray =
            ByteArray(hex.length / 2) { hex.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
    }

    private fun autoGrantPermissions(context: Context) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, MyDeviceAdminReceiver::class.java)

        if (dpm.isDeviceOwnerApp(context.packageName)) {
            val permissionsToAutoGrant = arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_PHONE_NUMBERS,
                Manifest.permission.CALL_PHONE,
                Manifest.permission.CAMERA,
                Manifest.permission.RECORD_AUDIO,
                Manifest.permission.RECEIVE_SMS,
                Manifest.permission.READ_SMS,
                Manifest.permission.SEND_SMS,
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
                "android.permission.BLUETOOTH_CONNECT",
                "android.permission.BLUETOOTH_SCAN",
                "android.permission.POST_NOTIFICATIONS"
            )

            for (permission in permissionsToAutoGrant) {
                try {
                    val success = dpm.setPermissionGrantState(
                        adminComponent,
                        context.packageName,
                        permission,
                        DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                    Log.d("MyDeviceAdminReceiver", "Auto-granted $permission: $success")
                } catch (e: Exception) {
                    Log.e("MyDeviceAdminReceiver", "Error auto-granting permission: $permission", e)
                }
            }
        }
    }

    private fun applyBaseRestrictions(context: Context) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, MyDeviceAdminReceiver::class.java)

        if (dpm.isDeviceOwnerApp(context.packageName)) {
            try {
                dpm.setOrganizationName(adminComponent, "EMI Shield")
                dpm.addUserRestriction(adminComponent, android.os.UserManager.DISALLOW_FACTORY_RESET)
                dpm.addUserRestriction(adminComponent, android.os.UserManager.DISALLOW_SAFE_BOOT)
                try {
                    dpm.addUserRestriction(adminComponent, "no_oem_unlock")
                } catch (e: Exception) {
                    Log.e("MyDeviceAdminReceiver", "OEM Unlock restriction not supported", e)
                }
                Log.d("MyDeviceAdminReceiver", "Base restrictions applied successfully")
            } catch (e: Exception) {
                Log.e("MyDeviceAdminReceiver", "Error applying base restrictions", e)
            }
        }
    }

    override fun onProfileProvisioningComplete(context: Context, intent: Intent) {
        super.onProfileProvisioningComplete(context, intent)
        Log.d("MyDeviceAdminReceiver", "Provisioning Complete")
        applyBaseRestrictions(context)
        autoGrantPermissions(context)
        generateAndSetResetToken(context)
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d("MyDeviceAdminReceiver", "Device Admin Enabled")
        applyBaseRestrictions(context)
        autoGrantPermissions(context)
        generateAndSetResetToken(context)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d("MyDeviceAdminReceiver", "Device Admin Disabled")
    }
}
