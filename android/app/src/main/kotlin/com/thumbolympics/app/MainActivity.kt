package com.thumbolympics.app

import android.content.Intent
import android.provider.Settings
import android.os.Bundle
import android.util.Log
import android.content.Context
import android.content.pm.PackageManager
import android.os.PowerManager
import android.net.Uri
import android.os.Build
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
                "getStoredData" -> {
                    try {
                        // Get data directly from accessibility service's SharedPreferences
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        
                        // Read the raw data that accessibility service stored
                        val rawDailyDistance = prefs.getLong("flutter.dailyDistance", java.lang.Double.doubleToRawLongBits(0.0))
                        val rawLifetimeDistance = prefs.getLong("flutter.lifetimeDistance", java.lang.Double.doubleToRawLongBits(0.0))
                        val rawDailyScrolls = prefs.getInt("flutter.dailyScrolls", 0)
                        val rawLifetimeScrolls = prefs.getInt("flutter.lifetimeScrolls", 0)
                        val lastDateKey = prefs.getString("flutter.lastDateKey", "2025-9-21") ?: "2025-9-21"
                        
                        // Convert raw long bits back to doubles
                        val dailyDistance = java.lang.Double.longBitsToDouble(rawDailyDistance)
                        val lifetimeDistance = java.lang.Double.longBitsToDouble(rawLifetimeDistance)
                        
                        val data = mapOf(
                            "dailyDistance" to dailyDistance,
                            "dailyScrolls" to rawDailyScrolls,
                            "lifetimeDistance" to lifetimeDistance,
                            "lifetimeScrolls" to rawLifetimeScrolls,
                            "lastDateKey" to lastDateKey,
                            "isNewDay" to false
                        )
                        
                        Log.d(TAG, "Retrieved stored data: Daily: ${dailyDistance}m (${rawDailyScrolls} scrolls), Lifetime: ${lifetimeDistance}m (${rawLifetimeScrolls} scrolls)")
                        result.success(data)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error retrieving stored data", e)
                        result.error("ERROR", "Could not retrieve stored data", null)
                    }
                }
                
                "getWeeklyData" -> {
                    try {
                        val weekStartMs = call.argument<Long>("weekStart") ?: 0L
                        val weekStart = java.util.Date(weekStartMs)
                        val calendar = java.util.Calendar.getInstance()
                        calendar.time = weekStart
                        
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val weeklyData = mutableMapOf<String, Map<String, Any>>()
                        
                        // Get data for each day of the week
                        for (i in 0..6) {
                            val date = java.util.Calendar.getInstance()
                            date.time = weekStart
                            date.add(java.util.Calendar.DAY_OF_MONTH, i)
                            
                            val dateKey = "${date.get(java.util.Calendar.YEAR)}-${date.get(java.util.Calendar.MONTH) + 1}-${date.get(java.util.Calendar.DAY_OF_MONTH)}"
                            
                            // Try to get daily data for this date
                            val dailyKey = "flutter.daily_$dateKey"
                            val scrollsKey = "flutter.daily_scrolls_$dateKey"
                            
                            val distance = prefs.getLong(dailyKey, 0L)
                            val scrolls = prefs.getInt(scrollsKey, 0)
                            
                            val distanceDouble = if (distance != 0L) java.lang.Double.longBitsToDouble(distance) else 0.0
                            
                            weeklyData[dateKey] = mapOf(
                                "distance" to distanceDouble,
                                "scrolls" to scrolls
                            )
                        }
                        
                        Log.d(TAG, "Retrieved weekly data for week starting $weekStart: ${weeklyData.size} days")
                        result.success(weeklyData)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error retrieving weekly data", e)
                        result.error("ERROR", "Could not retrieve weekly data", null)
                    }
                }
                "saveAllData" -> {
                    try {
                        val dailyDistance = call.argument<Double>("dailyDistance") ?: 0.0
                        val dailyScrolls = call.argument<Int>("dailyScrolls") ?: 0
                        val lifetimeDistance = call.argument<Double>("lifetimeDistance") ?: 0.0
                        val lifetimeScrolls = call.argument<Int>("lifetimeScrolls") ?: 0
                        val dateKey = call.argument<String>("dateKey") ?: getTodayKey()
                        
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val editor = prefs.edit()
                        
                        // Save main data
                        editor.putLong("flutter.dailyDistance", java.lang.Double.doubleToRawLongBits(dailyDistance))
                        editor.putInt("flutter.dailyScrolls", dailyScrolls)
                        editor.putLong("flutter.lifetimeDistance", java.lang.Double.doubleToRawLongBits(lifetimeDistance))
                        editor.putInt("flutter.lifetimeScrolls", lifetimeScrolls)
                        editor.putString("flutter.lastDateKey", dateKey)
                        
                        // Also save daily historical data
                        editor.putLong("flutter.daily_$dateKey", java.lang.Double.doubleToRawLongBits(dailyDistance))
                        editor.putInt("flutter.daily_scrolls_$dateKey", dailyScrolls)
                        
                        editor.apply()
                        
                        Log.d(TAG, "Saved all data: Daily: ${dailyDistance}m (${dailyScrolls} scrolls), Lifetime: ${lifetimeDistance}m (${lifetimeScrolls} scrolls)")
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error saving all data", e)
                        result.error("ERROR", "Could not save all data", null)
                    }
                }

                "saveAppData" -> {
                    try {
                        val packageName = call.argument<String>("packageName") ?: ""
                        val distance = call.argument<Double>("distance") ?: 0.0
                        val dateKey = call.argument<String>("dateKey") ?: getTodayKey()
                        
                        if (packageName.isNotEmpty() && distance > 0) {
                            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                            val editor = prefs.edit()
                            
                            // Save app-specific data for today
                            val appKey = "flutter.daily_app_${dateKey}_$packageName"
                            val currentDistance = prefs.getLong(appKey, 0L)
                            val currentDistanceDouble = if (currentDistance != 0L) java.lang.Double.longBitsToDouble(currentDistance) else 0.0
                            val newTotal = currentDistanceDouble + distance
                            
                            editor.putLong(appKey, java.lang.Double.doubleToRawLongBits(newTotal))
                            editor.apply()
                            
                            Log.d(TAG, "Saved app data: $packageName += ${distance}m (total: ${newTotal}m) for $dateKey")
                        }
                        
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error saving app data", e)
                        result.error("ERROR", "Could not save app data", null)
                    }
                }
                "getAppLeaderboard" -> {
                    try {
                        val isWeekly = call.argument<Boolean>("isWeekly") ?: false
                        val weekStartMs = call.argument<Long>("weekStart")
                        
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val appData = mutableMapOf<String, Double>()
                        
                        val keys = prefs.all.keys
                        val prefix = if (isWeekly && weekStartMs != null) {
                            // Weekly app data - aggregate all days in the week
                            val weekStart = java.util.Date(weekStartMs)
                            val calendar = java.util.Calendar.getInstance()
                            calendar.time = weekStart
                            
                            // Collect data from all 7 days of the week
                            for (dayOffset in 0..6) {
                                val date = java.util.Calendar.getInstance()
                                date.time = weekStart
                                date.add(java.util.Calendar.DAY_OF_MONTH, dayOffset)
                                val dateKey = "${date.get(java.util.Calendar.YEAR)}-${date.get(java.util.Calendar.MONTH) + 1}-${date.get(java.util.Calendar.DAY_OF_MONTH)}"
                                val dayPrefix = "flutter.daily_app_${dateKey}_"
                                
                                // Find all app entries for this day
                                for (key in keys) {
                                    if (key.startsWith(dayPrefix)) {
                                        val packageName = key.substring(dayPrefix.length)
                                        val distance = prefs.getLong(key, 0L)
                                        val distanceDouble = if (distance != 0L) java.lang.Double.longBitsToDouble(distance) else 0.0
                                        
                                        if (distanceDouble > 0) {
                                            appData[packageName] = (appData[packageName] ?: 0.0) + distanceDouble
                                        }
                                    }
                                }
                            }
                        } else {
                            // Daily app data
                            val todayKey = getTodayKey()
                            val dayPrefix = "flutter.daily_app_${todayKey}_"
                            
                            // Find all app data entries for today
                            for (key in keys) {
                                if (key.startsWith(dayPrefix)) {
                                    val packageName = key.substring(dayPrefix.length)
                                    val distance = prefs.getLong(key, 0L)
                                    val distanceDouble = if (distance != 0L) java.lang.Double.longBitsToDouble(distance) else 0.0
                                    
                                    if (distanceDouble > 0) {
                                        appData[packageName] = distanceDouble
                                    }
                                }
                            }
                        }
                        
                        Log.d(TAG, "Retrieved app leaderboard (${if (isWeekly) "weekly" else "daily"}): ${appData.size} apps")
                        result.success(appData)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error retrieving app leaderboard", e)
                        result.error("ERROR", "Could not retrieve app leaderboard", null)
                    }
                }
                "requestBatteryOptimizationExemption" -> {
                    try {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        val packageName = packageName
                        
                        if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success("Battery optimization exemption requested")
                        } else {
                            result.success("Already exempt from battery optimization")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error requesting battery optimization exemption", e)
                        result.error("ERROR", "Could not request battery optimization exemption", null)
                    }
                }

                "checkBatteryOptimizationStatus" -> {
                    try {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)
                        result.success(isIgnoring)
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not check battery optimization status", null)
                    }
                }
                "startForegroundService" -> {
                    try {
                        val serviceIntent = Intent(this, ForegroundService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        Log.d(TAG, "Foreground service started")
                        result.success("Foreground service started")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error starting foreground service", e)
                        result.error("ERROR", "Could not start foreground service", null)
                    }
                }

                "stopForegroundService" -> {
                    try {
                        val serviceIntent = Intent(this, ForegroundService::class.java)
                        stopService(serviceIntent)
                        Log.d(TAG, "Foreground service stopped")
                        result.success("Foreground service stopped")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error stopping foreground service", e)
                        result.error("ERROR", "Could not stop foreground service", null)
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

    // Utility function to get today's date key in the format "YYYY-M-D"
    private fun getTodayKey(): String {
        val calendar = java.util.Calendar.getInstance()
        val year = calendar.get(java.util.Calendar.YEAR)
        val month = calendar.get(java.util.Calendar.MONTH) + 1 // Calendar.MONTH is 0-based
        val day = calendar.get(java.util.Calendar.DAY_OF_MONTH)
        return "$year-$month-$day"
    }
}