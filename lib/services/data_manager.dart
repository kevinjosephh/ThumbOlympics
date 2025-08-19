import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  // Storage keys
  static const String _kDailyDistance = 'dailyDistance';
  static const String _kDailyScrolls = 'dailyScrolls';
  static const String _kLifetimeDistance = 'lifetimeDistance';
  static const String _kLifetimeScrolls = 'lifetimeScrolls';
  static const String _kLastDateKey = 'lastDateKey';
  static const String _kDailyPrefix = 'daily_';
  static const String _kAppDataPrefix = 'app_';
  static const String _kDailyAppDataPrefix = 'daily_app_';
  static const String _kWeeklyAppDataPrefix = 'weekly_app_';

  // Get today's key
  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  // Get date key from DateTime
  static String dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  // Load all data
  Future<Map<String, dynamic>> loadAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(_kLastDateKey) ?? todayKey();
      final today = todayKey();

      double dailyDistance = 0.0;
      int dailyScrolls = 0;

      // Check if it's a new day
      if (savedDate == today) {
        dailyDistance = prefs.getDouble(_kDailyDistance) ?? 0.0;
        dailyScrolls = prefs.getInt(_kDailyScrolls) ?? 0;
      }

      final lifetimeDistance = prefs.getDouble(_kLifetimeDistance) ?? 0.0;
      final lifetimeScrolls = prefs.getInt(_kLifetimeScrolls) ?? 0;

      return {
        'dailyDistance': dailyDistance,
        'dailyScrolls': dailyScrolls,
        'lifetimeDistance': lifetimeDistance,
        'lifetimeScrolls': lifetimeScrolls,
        'lastDateKey': savedDate,
        'isNewDay': savedDate != today,
      };
    } catch (e) {
      return {
        'dailyDistance': 0.0,
        'dailyScrolls': 0,
        'lifetimeDistance': 0.0,
        'lifetimeScrolls': 0,
        'lastDateKey': todayKey(),
        'isNewDay': false,
      };
    }
  }

  // Save all current data for a specific date key
  Future<void> saveAllData({
    required double dailyDistance,
    required int dailyScrolls,
    required double lifetimeDistance,
    required int lifetimeScrolls,
    // The date key (yyyy-m-d) that the daily values correspond to
    required String dateKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Persist the last active date key
      await prefs.setString(_kLastDateKey, dateKey);
      await prefs.setDouble(_kDailyDistance, dailyDistance);
      await prefs.setInt(_kDailyScrolls, dailyScrolls);
      await prefs.setDouble(_kLifetimeDistance, lifetimeDistance);
      await prefs.setInt(_kLifetimeScrolls, lifetimeScrolls);

      // Also save today's data for history
      await prefs.setDouble('$_kDailyPrefix$dateKey', dailyDistance);
      await prefs.setInt('${_kDailyPrefix}scrolls_$dateKey', dailyScrolls);
    } catch (e) {
      // Handle error silently for now
    }
  }

  // Load historical data
  Future<Map<String, Map<String, dynamic>>> loadHistoricalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      Map<String, Map<String, dynamic>> historicalData = {};

      for (String key in keys) {
        if (key.startsWith(_kDailyPrefix) && !key.contains('scrolls_')) {
          final dateStr = key.substring(_kDailyPrefix.length);
          final distance = prefs.getDouble(key) ?? 0.0;
          final scrolls = prefs.getInt('${_kDailyPrefix}scrolls_$dateStr') ?? 0;
          
          historicalData[dateStr] = {
            'distance': distance,
            'scrolls': scrolls,
          };
        }
      }

      // If no historical data exists, generate some sample data for demo
      if (historicalData.isEmpty) {
        historicalData = await _generateSampleHistoricalData();
      }

      return historicalData;
    } catch (e) {
      return await _generateSampleHistoricalData();
    }
  }

  // Generate sample historical data for demo purposes
  Future<Map<String, Map<String, dynamic>>> _generateSampleHistoricalData() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, Map<String, dynamic>> sampleData = {};
    final now = DateTime.now();
    
    // Generate 30 days of sample data
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateKey(date);
      
      // Generate realistic data with some variation
      double dailyDistance = 50 + (i % 10) * 30 + (i % 3) * 20; // 50-200m range
      int dailyScrolls = (dailyDistance / 0.15).round(); // Approximate scrolls
      
      // Weekend might have higher usage
      if (date.weekday >= 6) {
        dailyDistance *= 1.5;
        dailyScrolls = (dailyScrolls * 1.5).round();
      }

      sampleData[dateStr] = {
        'distance': dailyDistance,
        'scrolls': dailyScrolls,
      };

      // Save to preferences for persistence
      await prefs.setDouble('$_kDailyPrefix$dateStr', dailyDistance);
      await prefs.setInt('${_kDailyPrefix}scrolls_$dateStr', dailyScrolls);
    }

    return sampleData;
  }

  // Reset daily data
  Future<void> resetDailyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = todayKey();
      
      await prefs.setString(_kLastDateKey, today);
      await prefs.setDouble(_kDailyDistance, 0.0);
      await prefs.setInt(_kDailyScrolls, 0);
      await prefs.setDouble('$_kDailyPrefix$today', 0.0);
      await prefs.setInt('${_kDailyPrefix}scrolls_$today', 0);
    } catch (e) {
      // Handle error
    }
  }

  // Reset all data
  Future<void> resetAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all data
      await prefs.clear();
      
      // Set default values
      final today = todayKey();
      await prefs.setString(_kLastDateKey, today);
      await prefs.setDouble(_kDailyDistance, 0.0);
      await prefs.setInt(_kDailyScrolls, 0);
      await prefs.setDouble(_kLifetimeDistance, 0.0);
      await prefs.setInt(_kLifetimeScrolls, 0);
    } catch (e) {
      // Handle error
    }
  }

  // Get data for a specific date
  Future<Map<String, dynamic>> getDataForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = dateKey(date);
      
      final distance = prefs.getDouble('$_kDailyPrefix$dateStr') ?? 0.0;
      final scrolls = prefs.getInt('${_kDailyPrefix}scrolls_$dateStr') ?? 0;
      
      return {
        'distance': distance,
        'scrolls': scrolls,
      };
    } catch (e) {
      return {
        'distance': 0.0,
        'scrolls': 0,
      };
    }
  }

  // Get weekly data
  Future<Map<String, Map<String, dynamic>>> getWeeklyData(DateTime weekStart) async {
    Map<String, Map<String, dynamic>> weekData = {};
    
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateStr = dateKey(date);
      final dayData = await getDataForDate(date);
      weekData[dateStr] = dayData;
    }
    
    return weekData;
  }

  // Save app-specific data for today
  Future<void> saveAppData(String packageName, double distance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = todayKey();
      
      // Get current app data for today
      final currentData = await getDailyAppData();
      final currentDistance = currentData[packageName] ?? 0.0;
      final newDistance = currentDistance + distance;
      
      // Save updated data
      await prefs.setDouble('$_kDailyAppDataPrefix$today:$packageName', newDistance);
    } catch (e) {
      // Handle error silently
    }
  }

  // Get daily app data
  Future<Map<String, double>> getDailyAppData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = todayKey();
      final keys = prefs.getKeys();
      Map<String, double> appData = {};

      for (String key in keys) {
        if (key.startsWith('$_kDailyAppDataPrefix$today:')) {
          final packageName = key.substring('$_kDailyAppDataPrefix$today:'.length);
          final distance = prefs.getDouble(key) ?? 0.0;
          if (distance > 0) {
            appData[packageName] = distance;
          }
        }
      }

      return appData;
    } catch (e) {
      return {};
    }
  }

  // Get weekly app data
  Future<Map<String, double>> getWeeklyAppData(DateTime weekStart) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      Map<String, double> weeklyAppData = {};

      // Collect data for each day of the week
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final currentDateKey = dateKey(date);

        for (String key in keys) {
          if (key.startsWith('$_kDailyAppDataPrefix$currentDateKey:')) {
            final packageName = key.substring('$_kDailyAppDataPrefix$currentDateKey:'.length);
            final distance = prefs.getDouble(key) ?? 0.0;
            weeklyAppData[packageName] = (weeklyAppData[packageName] ?? 0.0) + distance;
          }
        }
      }

      return weeklyAppData;
    } catch (e) {
      return {};
    }
  }

  // Get app leaderboard (sorted by distance)
  Future<List<MapEntry<String, double>>> getAppLeaderboard({bool isWeekly = false, DateTime? weekStart}) async {
    try {
      Map<String, double> appData;
      
      if (isWeekly && weekStart != null) {
        appData = await getWeeklyAppData(weekStart);
      } else {
        appData = await getDailyAppData();
      }

      // Convert to list and sort by distance (descending)
      final sortedList = appData.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedList;
    } catch (e) {
      return [];
    }
  }
}