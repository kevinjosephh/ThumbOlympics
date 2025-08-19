package com.example.thumbrest

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.content.Context
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.hypot
import java.util.Calendar

class ThumbRestAccessibilityService : AccessibilityService() {

    companion object {
        private var channel: MethodChannel? = null
        private const val TAG = "ThumbRestAccessibilityService"
        // Track last known scroll offsets per window to compute deltas
        private val lastOffsets: MutableMap<Int, Pair<Int, Int>> = mutableMapOf()
        // Track touch interaction state
        private var isTouchInteraction = false
        private var lastTouchTime = 0L
        
        fun setMethodChannel(ch: MethodChannel) {
            channel = ch
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Reset internal state when service connects to avoid stale deltas
        lastOffsets.clear()
        isTouchInteraction = false
        lastTouchTime = 0L
        
        val info = AccessibilityServiceInfo()
        info.eventTypes = (AccessibilityEvent.TYPE_VIEW_SCROLLED or 
                          AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                          AccessibilityEvent.TYPE_TOUCH_INTERACTION_START or
                          AccessibilityEvent.TYPE_TOUCH_INTERACTION_END or
                          AccessibilityEvent.TYPE_VIEW_CLICKED or
                          AccessibilityEvent.TYPE_VIEW_LONG_CLICKED)
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = (AccessibilityServiceInfo.DEFAULT or
                     AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                     AccessibilityServiceInfo.FLAG_REQUEST_TOUCH_EXPLORATION_MODE or
                     AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY or
                     AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS or
                     AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS)
        info.notificationTimeout = 50
        serviceInfo = info
        
        Log.d(TAG, "Accessibility service connected with enhanced scroll detection")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let {
            try {
                when (it.eventType) {
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                        // Reset offsets on window changes to avoid stale deltas or jumps
                        lastOffsets.clear()
                        Log.d(TAG, "Window state changed, cleared offsets")
                        return
                    }
                    
                    AccessibilityEvent.TYPE_TOUCH_INTERACTION_START -> {
                        isTouchInteraction = true
                        lastTouchTime = System.currentTimeMillis()
                        Log.d(TAG, "Touch interaction started")
                        return
                    }
                    
                    AccessibilityEvent.TYPE_TOUCH_INTERACTION_END -> {
                        isTouchInteraction = false
                        Log.d(TAG, "Touch interaction ended")
                        return
                    }
                    
                    AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                        handleScrollEvent(it)
                    }
                    
                    AccessibilityEvent.TYPE_VIEW_CLICKED,
                    AccessibilityEvent.TYPE_VIEW_LONG_CLICKED -> {
                        // Log these events for debugging but don't process as scrolls
                        val packageName = it.packageName?.toString() ?: "unknown"
                        Log.d(TAG, "View interaction in $packageName: ${it.eventType}")
                        return
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing accessibility event: ${e.message}")
            }
        }
    }
    
    private fun handleScrollEvent(event: AccessibilityEvent) {
        val currentY = event.scrollY
        val currentX = event.scrollX
        val windowId = event.windowId
        val packageName = event.packageName?.toString() ?: "unknown"
        
        Log.d(TAG, "Scroll event from $packageName: x=$currentX, y=$currentY, windowId=$windowId")

        // Ignore invalid values sometimes reported by certain views
        if ((currentY < 0 && currentX < 0) || windowId < 0) {
            Log.d(TAG, "Ignoring invalid scroll values")
            return
        }

        val prev = lastOffsets[windowId]
        var deltaYpx = if (prev != null) abs(currentY - prev.first) else 0
        var deltaXpx = if (prev != null) abs(currentX - prev.second) else 0

        // Update last offsets for this window
        lastOffsets[windowId] = Pair(currentY, currentX)

        // Some apps (e.g., YouTube) report zero scrollX/Y but provide scroll deltas (API 28+)
        if (deltaYpx == 0 && deltaXpx == 0) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                val dy = kotlin.math.abs(event.scrollDeltaY)
                val dx = kotlin.math.abs(event.scrollDeltaX)
                if (dy > 0 || dx > 0) {
                    deltaYpx = dy
                    deltaXpx = dx
                }
            }
        }

        // Fallback: infer distance from list index changes when pixel deltas are unavailable
        if (deltaYpx == 0 && deltaXpx == 0) {
            val fromIdx = event.fromIndex
            val toIdx = event.toIndex
            if (fromIdx >= 0 && toIdx >= 0 && fromIdx != toIdx) {
                val dmTmp = resources.displayMetrics
                val approxItemPx = (100f * dmTmp.density).toInt() // ~100dp per row
                val steps = kotlin.math.abs(toIdx - fromIdx)
                deltaYpx = approxItemPx * steps
            }
        }

        // Convert pixel deltas to meters using device physical DPI
        val dm = resources.displayMetrics
        val yDpi = if (dm.ydpi > 0f) dm.ydpi else dm.densityDpi.toFloat()
        val xDpi = if (dm.xdpi > 0f) dm.xdpi else dm.densityDpi.toFloat()

        val metersY = (deltaYpx / yDpi) * 0.0254f
        val metersX = (deltaXpx / xDpi) * 0.0254f

        // Total distance moved along the scroll plane
        val distanceMeters = hypot(metersX, metersY)

        // Guard against improbable spikes to reduce risk of ANRs/exceptions downstream
        val clampedDistance = if (distanceMeters.isFinite()) distanceMeters.coerceAtMost(5.0f) else 0f

        if (clampedDistance > 0f) {
            val scrollData = mapOf(
                "distanceMeters" to clampedDistance.toDouble(),
                "timestamp" to System.currentTimeMillis(),
                "packageName" to packageName,
                "isTouchInteraction" to isTouchInteraction
            )
            Log.d(TAG, "Sending scroll data: ${clampedDistance}m from $packageName")

            val ch = channel
            if (ch != null) {
                try {
                    ch.invokeMethod("onScroll", scrollData)
                } catch (e: Exception) {
                    Log.w(TAG, "Channel present but failed to send; persisting locally", e)
                    persistScrollLocally(clampedDistance.toDouble(), packageName)
                }
            } else {
                // Flutter engine not attached; persist locally so the app can read it later
                persistScrollLocally(clampedDistance.toDouble(), packageName)
            }
        }
    }

    private fun persistScrollLocally(distanceMeters: Double, packageName: String) {
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Keys must match Flutter side in DataManager
            val todayKey = getTodayKey()

            // Read existing totals
            val dailyDistance = java.lang.Double.longBitsToDouble(
                prefs.getLong("flutter.dailyDistance", java.lang.Double.doubleToRawLongBits(0.0))
            )
            val lifetimeDistance = java.lang.Double.longBitsToDouble(
                prefs.getLong("flutter.lifetimeDistance", java.lang.Double.doubleToRawLongBits(0.0))
            )
            val dailyScrolls = prefs.getInt("flutter.dailyScrolls", 0)
            val lifetimeScrolls = prefs.getInt("flutter.lifetimeScrolls", 0)
            val lastDateKey = prefs.getString("flutter.lastDateKey", todayKey)

            val editor = prefs.edit()

            // Day rollover handling
            if (lastDateKey != todayKey) {
                // Persist the previous day's final totals under its own date keys
                val prevDay = lastDateKey ?: todayKey
                editor.putLong("flutter.daily_${'$'}prevDay", java.lang.Double.doubleToRawLongBits(dailyDistance))
                editor.putInt("flutter.daily_scrolls_${'$'}prevDay", dailyScrolls)
                // Reset counters for new day
                editor.putString("flutter.lastDateKey", todayKey)
                editor.putLong("flutter.dailyDistance", java.lang.Double.doubleToRawLongBits(0.0))
                editor.putInt("flutter.dailyScrolls", 0)
            }

            // Update running totals
            val newDailyDistance = if (lastDateKey == todayKey) dailyDistance + distanceMeters else distanceMeters
            val newLifetimeDistance = lifetimeDistance + distanceMeters
            val newDailyScrolls = if (lastDateKey == todayKey) dailyScrolls + 1 else 1
            val newLifetimeScrolls = lifetimeScrolls + 1

            editor.putLong("flutter.dailyDistance", java.lang.Double.doubleToRawLongBits(newDailyDistance))
            editor.putInt("flutter.dailyScrolls", newDailyScrolls)
            editor.putLong("flutter.lifetimeDistance", java.lang.Double.doubleToRawLongBits(newLifetimeDistance))
            editor.putInt("flutter.lifetimeScrolls", newLifetimeScrolls)
            editor.putString("flutter.lastDateKey", todayKey)

            // Save today's per-app distance
            if (packageName.isNotEmpty() && packageName != "unknown" && packageName != "test") {
                val appKey = "flutter.daily_app_${'$'}todayKey:${'$'}packageName"
                val existingApp = java.lang.Double.longBitsToDouble(
                    prefs.getLong(appKey, java.lang.Double.doubleToRawLongBits(0.0))
                )
                editor.putLong(appKey, java.lang.Double.doubleToRawLongBits(existingApp + distanceMeters))
            }

            editor.apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist scroll locally", e)
        }
    }

    private fun getTodayKey(): String {
        val cal = Calendar.getInstance()
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return "${'$'}y-${'$'}m-${'$'}d"
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        lastOffsets.clear()
        isTouchInteraction = false
        Log.d(TAG, "Accessibility service unbound")
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        lastOffsets.clear()
        isTouchInteraction = false
        Log.d(TAG, "Accessibility service destroyed")
        // Do not hold stale channel references
        try {
            // Best-effort: if app recreates engine it will set the channel again
        } finally {
            super.onDestroy()
        }
    }
}
