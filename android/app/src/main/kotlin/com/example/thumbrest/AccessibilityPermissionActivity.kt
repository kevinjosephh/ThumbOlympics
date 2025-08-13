package com.example.thumbrest

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings

class AccessibilityPermissionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
        finish()
    }
}
