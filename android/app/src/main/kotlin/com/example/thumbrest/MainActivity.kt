package com.example.thumbrest

import android.content.Intent
import android.provider.Settings
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "thumbolympics/accessibility"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        if (messenger != null) {
            val methodChannel = MethodChannel(messenger, CHANNEL)
            
            // Connect the accessibility service to the method channel
            ThumbRestAccessibilityService.setMethodChannel(methodChannel)
            
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
                            result.success(isEnabled)
                        } catch (e: Exception) {
                            result.error("ERROR", "Could not check accessibility service status", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }
}
