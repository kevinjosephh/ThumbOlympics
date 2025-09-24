package com.thumbolympics.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.hypot
import java.util.Calendar

class ThumbRestAccessibilityService : AccessibilityService() {

    companion object {
        private var methodChannel: MethodChannel? = null
        private const val TAG = "ThumbRestAccessibilityService"
        // Track last known scroll offsets per window to compute deltas
        private val lastOffsets: MutableMap<Int, Pair<Int, Int>> = mutableMapOf()
        // Track touch interaction state
        private var isTouchInteraction = false
        private var lastTouchTime = 0L
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
            Log.d(TAG, "Method channel set/updated")
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
        
        // Try to reconnect to the method channel if it's null
        if (methodChannel == null) {
            Log.w(TAG, "Method channel is null after service restart - may need to reopen app")
        }
        try {
            val info = serviceInfo
            info.flags = info.flags or AccessibilityServiceInfo.FLAG_REQUEST_ENHANCED_WEB_ACCESSIBILITY
            serviceInfo = info
        } catch (e: Exception) {
            Log.e(TAG, "Error setting service flags", e)
        }
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
        try {
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
                sendScrollData(clampedDistance.toDouble(), packageName, isTouchInteraction)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception in scroll handling", e)
            // Don't crash, just log and continue
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "Out of memory in scroll handling", e)
            // Clear any cached data and continue
            lastOffsets.clear()
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error in scroll handling", e)
            // Don't crash the service
        }
    }

    // Check if the service is still properly connected
    private fun isServiceHealthy(): Boolean {
        return methodChannel != null && serviceInfo != null
    }

    private fun sendScrollData(distanceMeters: Double, packageName: String, isTouchInteraction: Boolean = false) {
        Log.d(TAG, "Sending scroll data: ${distanceMeters}m from $packageName")
        
        val scrollData = mapOf(
            "distanceMeters" to distanceMeters,
            "timestamp" to System.currentTimeMillis(),
            "packageName" to packageName,
            "isTouchInteraction" to isTouchInteraction
        )
        
        // Always persist locally first to ensure data is never lost
        persistScrollLocally(distanceMeters, packageName)
        
        // Try to send via method channel if available
        val channel = methodChannel
        if (channel != null && isServiceHealthy()) {
            try {
                channel.invokeMethod("onScroll", scrollData)
                Log.d(TAG, "Successfully sent scroll data via channel")
            } catch (e: Exception) {
                Log.w(TAG, "Channel present but failed to send data", e)
                // Data is already persisted locally, so this failure is not critical
            }
        } else {
            Log.d(TAG, "Channel is null or service unhealthy - data persisted locally only")
        }
    }

    private fun persistScrollLocally(distanceMeters: Double, packageName: String) {
        try {
            Log.d(TAG, "Starting persistScrollLocally with distance: $distanceMeters, package: $packageName")
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Keys must match Flutter side in DataManager
            val todayKey = getTodayKey()

            // Read existing totals with type-safe handling
            val dailyDistance = readDoubleFromPrefs(prefs, "flutter.dailyDistance", 0.0)
            val lifetimeDistance = readDoubleFromPrefs(prefs, "flutter.lifetimeDistance", 0.0)
            
            val dailyScrolls = readIntFromPrefs(prefs, "flutter.dailyScrolls", 0)
            val lifetimeScrolls = readIntFromPrefs(prefs, "flutter.lifetimeScrolls", 0)
            val lastDateKey = prefs.getString("flutter.lastDateKey", todayKey) ?: todayKey

            val editor = prefs.edit()

            Log.d(TAG, "Current data - Daily: $dailyDistance, Lifetime: $lifetimeDistance, LastDate: $lastDateKey, Today: $todayKey")

            // Day rollover handling
            if (lastDateKey != todayKey) {
                Log.d(TAG, "Day rollover detected: $lastDateKey -> $todayKey")
                // Persist the previous day's final totals under its own date keys
                val prevDay = lastDateKey
                // Use the exact same key format that Flutter DataManager expects
                editor.putLong("flutter.daily_$prevDay", java.lang.Double.doubleToRawLongBits(dailyDistance))
                editor.putInt("flutter.daily_scrolls_$prevDay", dailyScrolls)
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

            // Update current day totals
            editor.putLong("flutter.dailyDistance", java.lang.Double.doubleToRawLongBits(newDailyDistance))
            editor.putInt("flutter.dailyScrolls", newDailyScrolls)
            editor.putLong("flutter.lifetimeDistance", java.lang.Double.doubleToRawLongBits(newLifetimeDistance))
            editor.putInt("flutter.lifetimeScrolls", newLifetimeScrolls)
            editor.putString("flutter.lastDateKey", todayKey)

            // CRITICAL: Always save today's data to historical keys so Flutter can read it
            // This ensures data persists even if app is killed
            editor.putLong("flutter.daily_$todayKey", java.lang.Double.doubleToRawLongBits(newDailyDistance))
            editor.putInt("flutter.daily_scrolls_$todayKey", newDailyScrolls)
            
            // Also ensure lifetime totals are updated in case Flutter reads them directly
            editor.putLong("flutter.lifetimeDistance", java.lang.Double.doubleToRawLongBits(newLifetimeDistance))
            editor.putInt("flutter.lifetimeScrolls", newLifetimeScrolls)

            // Save today's per-app distance with the correct key format for MainActivity.kt
            if (packageName.isNotEmpty() && packageName != "unknown" && packageName != "test") {
                val appKey = "flutter.daily_app_${todayKey}_$packageName"
                val existingApp = java.lang.Double.longBitsToDouble(
                    prefs.getLong(appKey, java.lang.Double.doubleToRawLongBits(0.0))
                )
                editor.putLong(appKey, java.lang.Double.doubleToRawLongBits(existingApp + distanceMeters))
            }

            // Use commit() instead of apply() to ensure immediate write
            val success = editor.commit()
            
            if (success) {
                Log.d(TAG, "Data persisted locally - Daily: ${newDailyDistance}m (${newDailyScrolls} scrolls), Lifetime: ${newLifetimeDistance}m (${newLifetimeScrolls} scrolls)")
            } else {
                Log.e(TAG, "Failed to commit data to SharedPreferences")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist scroll locally", e)
            e.printStackTrace()
        }
    }

    private fun getTodayKey(): String {
        val cal = Calendar.getInstance()
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return "$y-$m-$d"
    }

    override fun onInterrupt() {
        Log.w(TAG, "Accessibility service interrupted")
        // Don't clear the method channel on interrupt, as it might reconnect
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        lastOffsets.clear()
        isTouchInteraction = false
        Log.d(TAG, "Accessibility service unbound - requesting restart")
        // Return true to indicate we want to be restarted
        return true
    }

    override fun onDestroy() {
        Log.d(TAG, "Accessibility service destroyed - attempting to restart")
        
        // Clear internal state
        lastOffsets.clear()
        isTouchInteraction = false
        
        // CRITICAL: Ensure final data persistence before service is destroyed
        try {
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val todayKey = getTodayKey()
            
            // Force commit any pending data
            val editor = prefs.edit()
            editor.putString("flutter.lastDateKey", todayKey)
            editor.commit()
            
            Log.d(TAG, "Final data persistence completed before service destruction")
        } catch (e: Exception) {
            Log.e(TAG, "Error during final data persistence", e)
        }
        
        // Clear the static method channel reference
        methodChannel = null
        
        // Attempt to restart the service by sending a broadcast
        try {
            val intent = Intent("com.thumbolympics.app.RESTART_SERVICE")
            intent.setPackage(packageName)
            sendBroadcast(intent)
            Log.d(TAG, "Restart broadcast sent")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send restart broadcast", e)
        }
        
        super.onDestroy()
    }
    
    // Helper functions to safely read SharedPreferences with type conversion
    private fun readDoubleFromPrefs(prefs: android.content.SharedPreferences, key: String, defaultValue: Double): Double {
        return try {
            // Try to read as Long first (proper double storage)
            java.lang.Double.longBitsToDouble(
                prefs.getLong(key, java.lang.Double.doubleToRawLongBits(defaultValue))
            )
        } catch (e: ClassCastException) {
            try {
                // Fallback: try to read as String and parse
                val stringValue = prefs.getString(key, defaultValue.toString())
                stringValue?.toDoubleOrNull() ?: defaultValue
            } catch (e2: Exception) {
                Log.w(TAG, "Error reading $key as double, using default $defaultValue", e2)
                defaultValue
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error reading $key, using default $defaultValue", e)
            defaultValue
        }
    }
    
    private fun readIntFromPrefs(prefs: android.content.SharedPreferences, key: String, defaultValue: Int): Int {
        return try {
            prefs.getInt(key, defaultValue)
        } catch (e: ClassCastException) {
            try {
                // Fallback: try to read as String and parse
                val stringValue = prefs.getString(key, defaultValue.toString())
                stringValue?.toIntOrNull() ?: defaultValue
            } catch (e2: Exception) {
                try {
                    // Fallback: try to read as Long and convert
                    prefs.getLong(key, defaultValue.toLong()).toInt()
                } catch (e3: Exception) {
                    Log.w(TAG, "Error reading $key as int, using default $defaultValue", e3)
                    defaultValue
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error reading $key, using default $defaultValue", e)
            defaultValue
        }
    }
}
