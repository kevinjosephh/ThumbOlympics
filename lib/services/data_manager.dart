import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  // Get today's date key
  String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  // Get date key from DateTime
  static String dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  // Instance method version for internal use
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  // CRITICAL: Read data directly from accessibility service's local storage
  // This bypasses Flutter SharedPreferences entirely
  Future<Map<String, dynamic>> _readFromAccessibilityStorage() async {
    try {
      // Use method channel to get data directly from accessibility service
      const platform = MethodChannel('thumbolympics/accessibility');
      
      final result = await platform.invokeMethod('getStoredData');
      if (result is Map) {
        final data = Map<String, dynamic>.from(result);
        developer.log('Read from accessibility storage: $data', name: 'DataManager');
        return data;
      }
    } catch (e) {
      developer.log('Error reading from accessibility storage: $e', name: 'DataManager');
    }
    
    // Return default values if method channel fails
    return {
      'dailyDistance': 0.0,
      'dailyScrolls': 0,
      'lifetimeDistance': 0.0,
      'lifetimeScrolls': 0,
      'lastDateKey': todayKey(),
      'isNewDay': false,
    };
  }

  // Load all data
  Future<Map<String, dynamic>> loadAllData() async {
    try {
      print('=== FLUTTER DEBUG: Starting data load from accessibility storage ===');
      developer.log('=== FLUTTER DEBUG: Starting data load from accessibility storage ===', name: 'ThumbRest');
      
      // Read data directly from accessibility service
      final data = await _readFromAccessibilityStorage();
      
      final dailyDistance = data['dailyDistance'] as double;
      final dailyScrolls = data['dailyScrolls'] as int;
      final lifetimeDistance = data['lifetimeDistance'] as double;
      final lifetimeScrolls = data['lifetimeScrolls'] as int;
      
      print('DataManager: Loaded data from accessibility storage:');
      print('  Daily: ${dailyDistance}m, $dailyScrolls scrolls');
      print('  Lifetime: ${lifetimeDistance}m, $lifetimeScrolls scrolls');
      
      developer.log('DataManager: Loaded data from accessibility storage:', name: 'ThumbRest');
      developer.log('  Daily: ${dailyDistance}m, $dailyScrolls scrolls', name: 'ThumbRest');
      developer.log('  Lifetime: ${lifetimeDistance}m, $lifetimeScrolls scrolls', name: 'ThumbRest');
      
      return data;
    } catch (e) {
      developer.log('Error loading data: $e', name: 'DataManager');
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

  // Save all current data - DISABLED (accessibility service handles persistence)
  Future<void> saveAllData({
    required double dailyDistance,
    required int dailyScrolls,
    required double lifetimeDistance,
    required int lifetimeScrolls,
    required String dateKey,
  }) async {
    try {
      // Use method channel to save data to accessibility service's storage
      const platform = MethodChannel('thumbolympics/accessibility');
      
      await platform.invokeMethod('saveAllData', {
        'dailyDistance': dailyDistance,
        'dailyScrolls': dailyScrolls,
        'lifetimeDistance': lifetimeDistance,
        'lifetimeScrolls': lifetimeScrolls,
        'dateKey': dateKey,
      });
      
      developer.log('Successfully saved all data via accessibility service', name: 'DataManager');
    } catch (e) {
      developer.log('Error saving data via accessibility service: $e', name: 'DataManager');
      rethrow;
    }
  }

  // Get weekly data for history screen
  Future<Map<String, Map<String, dynamic>>> getWeeklyData(DateTime weekStart) async {
    try {
      // Use method channel to get historical data from accessibility service
      const platform = MethodChannel('thumbolympics/accessibility');
      
      final result = await platform.invokeMethod('getWeeklyData', {
        'weekStart': weekStart.millisecondsSinceEpoch,
      });
      
      if (result is Map) {
        final data = Map<String, dynamic>.from(result);
        final weeklyData = <String, Map<String, dynamic>>{};
        
        // Convert the result to the expected format
        data.forEach((dateKey, dayData) {
          if (dayData is Map) {
            weeklyData[dateKey] = {
              'distance': (dayData['distance'] as num?)?.toDouble() ?? 0.0,
              'scrolls': (dayData['scrolls'] as num?)?.toInt() ?? 0,
            };
          }
        });
        
        return weeklyData;
      }
      
      // Fallback: return empty data for all 7 days
      Map<String, Map<String, dynamic>> weeklyData = {};
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateKey = _dateKey(date);
        weeklyData[dateKey] = {
          'distance': 0.0,
          'scrolls': 0,
        };
      }
      
      return weeklyData;
    } catch (e) {
      developer.log('Error getting weekly data: $e', name: 'DataManager');
      
      // Fallback: return empty data
      Map<String, Map<String, dynamic>> weeklyData = {};
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateKey = _dateKey(date);
        weeklyData[dateKey] = {
          'distance': 0.0,
          'scrolls': 0,
        };
      }
      
      return weeklyData;
    }
  }

  // Get app leaderboard data
  Future<List<MapEntry<String, double>>> getAppLeaderboard({bool isWeekly = false, DateTime? weekStart}) async {
    try {
      // Use method channel to get app data from accessibility service
      const platform = MethodChannel('thumbolympics/accessibility');
      
      final result = await platform.invokeMethod('getAppLeaderboard', {
        'isWeekly': isWeekly,
        'weekStart': weekStart?.millisecondsSinceEpoch,
      });
      
      if (result is Map) {
        final appData = Map<String, dynamic>.from(result);
        final leaderboard = <MapEntry<String, double>>[];
        
        // Convert the result to the expected format
        appData.forEach((packageName, distance) {
          if (distance is num) {
            leaderboard.add(MapEntry(packageName, distance.toDouble()));
          }
        });
        
        // Sort by distance (descending)
        leaderboard.sort((a, b) => b.value.compareTo(a.value));
        
        return leaderboard;
      }
      
      // Fallback: return empty leaderboard
      return [];
    } catch (e) {
      developer.log('Error getting app leaderboard: $e', name: 'DataManager');
      return [];
    }
  }


  // Reset daily data
  Future<void> resetDailyData() async {
    try {
      // TODO: Implement reset functionality in accessibility service
      developer.log('Reset daily data requested - not implemented yet', name: 'DataManager');
    } catch (e) {
      developer.log('Error resetting daily data: $e', name: 'DataManager');
    }
  }

  // Reset all data
  Future<void> resetAllData() async {
    try {
      // TODO: Implement reset functionality in accessibility service
      developer.log('Reset all data requested - not implemented yet', name: 'DataManager');
    } catch (e) {
      developer.log('Error resetting all data: $e', name: 'DataManager');
    }
  }

  // Get data for a specific date
  Future<Map<String, dynamic>> getDataForDate(DateTime date) async {
    try {
      // For now, only return current day's data
      final today = DateTime.now();
      if (date.year == today.year && date.month == today.month && date.day == today.day) {
        return await _readFromAccessibilityStorage();
      }
      
      // Return empty data for other dates
      return {
        'distance': 0.0,
        'scrolls': 0,
      };
    } catch (e) {
      developer.log('Error getting data for date: $e', name: 'DataManager');
      return {
        'distance': 0.0,
        'scrolls': 0,
      };
    }
  }

  // Save app-specific data for today
  Future<void> saveAppData(String packageName, double distance) async {
    try {
      if (packageName.isEmpty || distance <= 0) return;
      
      // Use method channel to save app data to accessibility service's storage
      const platform = MethodChannel('thumbolympics/accessibility');
      
      await platform.invokeMethod('saveAppData', {
        'packageName': packageName,
        'distance': distance,
        'dateKey': todayKey(),
      });
      
      developer.log('Successfully saved app data: $packageName += ${distance}m', name: 'DataManager');
    } catch (e) {
      developer.log('Error saving app data: $e', name: 'DataManager');
      // Don't rethrow - app data saving is not critical
    }
  }

  // Get daily app data
  Future<Map<String, double>> getDailyAppData() async {
    try {
      // TODO: Implement app-specific data retrieval from accessibility service
      return {};
    } catch (e) {
      developer.log('Error getting daily app data: $e', name: 'DataManager');
      return {};
    }
  }

  // Get weekly app data
  Future<Map<String, double>> getWeeklyAppData(DateTime weekStart) async {
    try {
      // TODO: Implement weekly app data retrieval from accessibility service
      return {};
    } catch (e) {
      developer.log('Error getting weekly app data: $e', name: 'DataManager');
      return {};
    }
  }

  // Load historical data
  Future<Map<String, Map<String, dynamic>>> loadHistoricalData() async {
    try {
      // TODO: Implement historical data loading from accessibility service
      return {};
    } catch (e) {
      developer.log('Error loading historical data: $e', name: 'DataManager');
      return {};
    }
  }
}