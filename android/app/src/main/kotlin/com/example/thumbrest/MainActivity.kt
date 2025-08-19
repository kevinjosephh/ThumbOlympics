package com.example.thumbrest

import android.content.Intent
import android.provider.Settings
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "thumbolympics/accessibility"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Connect the accessibility service to the method channel
        ThumbRestAccessibilityService.setMethodChannel(methodChannel)
        Log.d(TAG, "Accessibility service method channel connected")

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open accessibility settings", null)
                    }
                }
                "isAccessibilityServiceEnabled" -> {
                    try {
                        val isEnabled = AccessibilityServiceUtils.isServiceEnabled(
                            this,
                            ThumbRestAccessibilityService::class.java
                        )
                        Log.d(TAG, "Accessibility service enabled: $isEnabled")
                        result.success(isEnabled)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error checking accessibility service status", e)
                        result.error("ERROR", "Could not check accessibility service status", null)
                    }
                }
                "testAccessibilityService" -> {
                    try {
                        // Send a test scroll event to verify the service is working
                        val testData = mapOf(
                            "distanceMeters" to 0.1,
                            "timestamp" to System.currentTimeMillis(),
                            "packageName" to "test",
                            "isTouchInteraction" to false
                        )
                        methodChannel.invokeMethod("onScroll", testData)
                        Log.d(TAG, "Test scroll event sent")
                        result.success("Test scroll event sent successfully")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending test scroll event", e)
                        result.error("ERROR", "Could not send test scroll event", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
