package com.thumbolympics.app

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.text.TextUtils

object AccessibilityServiceUtils {
    fun isServiceEnabled(context: Context, service: Class<*>): Boolean {
        val expectedComponentName = ComponentName(context, service)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)

        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (ComponentName.unflattenFromString(componentName) == expectedComponentName) {
                return true
            }
        }
        return false
    }
}

// Add this to your accessibility service
private fun logServiceHealth() {
    Log.d(TAG, "Service Health Check:")
    Log.d(TAG, "  - Method channel: ${methodChannel != null}")
    Log.d(TAG, "  - Service info: ${serviceInfo != null}")
    Log.d(TAG, "  - Last offsets size: ${lastOffsets.size}")
    Log.d(TAG, "  - Memory: ${Runtime.getRuntime().let { "${it.totalMemory() - it.freeMemory()}/${it.totalMemory()}" }}")
}

// Call this periodically or when errors occur