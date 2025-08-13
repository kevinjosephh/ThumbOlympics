package com.example.thumbrest

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.MethodChannel

class ThumbRestAccessibilityService : AccessibilityService() {

    companion object {
        private var channel: MethodChannel? = null
        private const val TAG = "ThumbRestAccessibilityService"
        
        fun setMethodChannel(ch: MethodChannel) {
            channel = ch
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_VIEW_SCROLLED or AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.DEFAULT
        info.notificationTimeout = 100
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let {
            try {
                if (it.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
                    val scrollY = it.scrollY
                    val scrollX = it.scrollX
                    
                    // Calculate scroll distance in pixels
                    var scrollDistance = 0
                    if (scrollY != 0) {
                        scrollDistance = Math.abs(scrollY)
                    } else if (scrollX != 0) {
                        scrollDistance = Math.abs(scrollX)
                    }
                    
                    // If we can't get exact scroll values, estimate based on text content
                    if (scrollDistance == 0) {
                        val text = it.text
                        if (text != null && text.isNotEmpty()) {
                            // Estimate scroll distance based on text length
                            scrollDistance = Math.min(200, text.joinToString().length * 6)
                        } else {
                            // Default scroll distance if we can't determine
                            scrollDistance = 150
                        }
                    }
                    
                    // Send scroll distance to Flutter
                    val scrollData = mapOf(
                        "distance" to scrollDistance,
                        "timestamp" to System.currentTimeMillis()
                    )
                    channel?.invokeMethod("onScroll", scrollData)
                }
            } catch (e: Exception) {
                // Silent error handling for production
            }
        }
    }

    override fun onInterrupt() {
        // Service interrupted
    }
}
