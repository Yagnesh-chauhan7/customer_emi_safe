package com.example.customer_emi_app

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.Intent
import android.os.Bundle
import android.util.Log

class PolicyComplianceActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("PolicyComplianceActivity", "PolicyComplianceActivity onCreate action: ${intent.action}")

        val action = intent.action
        if (action == "android.app.action.GET_PROVISIONING_MODE") {
            val resultIntent = Intent().apply {
                putExtra(
                    DevicePolicyManager.EXTRA_PROVISIONING_MODE,
                    DevicePolicyManager.PROVISIONING_MODE_FULLY_MANAGED_DEVICE
                )
            }
            setResult(RESULT_OK, resultIntent)
            Log.d("PolicyComplianceActivity", "GET_PROVISIONING_MODE result set to fully managed")
        } else if (action == "android.app.action.ADMIN_POLICY_COMPLIANCE") {
            setResult(RESULT_OK)
            Log.d("PolicyComplianceActivity", "ADMIN_POLICY_COMPLIANCE result set to OK")
        } else {
            setResult(RESULT_OK)
        }
        
        finish()
    }
}
