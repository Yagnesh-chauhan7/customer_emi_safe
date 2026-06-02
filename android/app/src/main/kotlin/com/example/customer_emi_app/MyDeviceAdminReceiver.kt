package com.example.customer_emi_app

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.Manifest

class MyDeviceAdminReceiver : DeviceAdminReceiver() {
    
    private fun autoGrantPermissions(context: Context) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, MyDeviceAdminReceiver::class.java)

        if (dpm.isDeviceOwnerApp(context.packageName)) {
            val permissionsToAutoGrant = arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
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
                    Log.d("MyDeviceAdminReceiver", "Auto-granted \$permission: \$success")
                } catch (e: Exception) {
                    Log.e("MyDeviceAdminReceiver", "Error auto-granting permission: \$permission", e)
                }
            }
        }
    }

    private fun applyBaseRestrictions(context: Context) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, MyDeviceAdminReceiver::class.java)

        if (dpm.isDeviceOwnerApp(context.packageName)) {
            try {
                // Set the organization name that appears on the lock screen and settings
                // Instead of "This device is managed by your organization", it will say:
                // "This device is managed by [Your Company Name]"
                dpm.setOrganizationName(adminComponent, "EMI Shield")

                // Permanently block factory reset, safe boot, and OEM unlock from Settings
                dpm.addUserRestriction(adminComponent, android.os.UserManager.DISALLOW_FACTORY_RESET)
                dpm.addUserRestriction(adminComponent, android.os.UserManager.DISALLOW_SAFE_BOOT)
                try {
                    dpm.addUserRestriction(adminComponent, "no_oem_unlock")
                } catch (e: Exception) {
                    Log.e("MyDeviceAdminReceiver", "OEM Unlock restriction not supported", e)
                }
                Log.d("MyDeviceAdminReceiver", "Base restrictions (Factory Reset & OEM Unlock blocked) applied successfully")
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
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d("MyDeviceAdminReceiver", "Device Admin Enabled")
        applyBaseRestrictions(context)
        autoGrantPermissions(context)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d("MyDeviceAdminReceiver", "Device Admin Disabled")
    }
}
