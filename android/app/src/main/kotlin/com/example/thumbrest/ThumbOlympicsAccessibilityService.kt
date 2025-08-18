package com.example.thumbrest

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.hypot

class ThumbRestAccessibilityService : AccessibilityService() {

    companion object {
        private var channel: MethodChannel? = null
        private const val TAG = "ThumbRestAccessibilityService"
        // Track last known scroll offsets per window to compute deltas
        private val lastOffsets: MutableMap<Int, Pair<Int, Int>> = mutableMapOf()
        
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
                    val currentY = it.scrollY
                    val currentX = it.scrollX
                    val windowId = it.windowId

                    val prev = lastOffsets[windowId]
                    val deltaYpx = if (prev != null) abs(currentY - prev.first) else 0
                    val deltaXpx = if (prev != null) abs(currentX - prev.second) else 0

                    // Update last offsets for this window
                    lastOffsets[windowId] = Pair(currentY, currentX)

                    // Convert pixel deltas to meters using device physical DPI
                    val dm = resources.displayMetrics
                    val yDpi = if (dm.ydpi > 0f) dm.ydpi else dm.densityDpi.toFloat()
                    val xDpi = if (dm.xdpi > 0f) dm.xdpi else dm.densityDpi.toFloat()

                    val metersY = (deltaYpx / yDpi) * 0.0254f
                    val metersX = (deltaXpx / xDpi) * 0.0254f

                    // Total distance moved along the scroll plane
                    val distanceMeters = hypot(metersX, metersY)

                    if (distanceMeters > 0f) {
                        val scrollData = mapOf(
                            "distanceMeters" to distanceMeters.toDouble(),
                            "timestamp" to System.currentTimeMillis()
                        )
                        channel?.invokeMethod("onScroll", scrollData)
                    }
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
