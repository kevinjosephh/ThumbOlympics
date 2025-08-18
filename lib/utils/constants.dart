import 'package:flutter/material.dart';

class AppConstants {
  // Conversion rates
  // Deprecated: prefer native-provided meters via Android accessibility service
  static const double pixelToMeterConversion = 0.000264583;
  // Conservative fallback when no native distance is provided
  static const double defaultScrollDistance = 0.02; // meters (~2 cm) per event fallback

  // Milestone distances in meters
  static const Map<String, double> distanceComparisons = {
    // Small objects/heights
    'Giraffe Height': 5.5,
    'T-Rex Length': 12.0,
    'Blue Whale Length': 30.0,
    'Colosseum': 48.0,
    'Swimming Pool (Olympic)': 50.0,
    'Niagara Falls (height)': 51.0,
    'Boeing 747 Length': 70.6,
    'Taj Mahal': 73.0,
    'Statue of Liberty': 93.0,
    'Big Ben': 96.0,
    'Football Field': 109.7,

    // Medium landmarks
    'London Eye': 135.0,
    'Titanic Length': 269.0,
    'Cruise Ship (avg)': 300.0,
    'Eiffel Tower': 324.0,
    'Empire State Building': 443.0,
    'Burj Khalifa': 828.0,

    // Natural features
    'Angel Falls': 979.0,
    'Mile Run': 1609.0,
    'Grand Canyon (depth)': 1800.0,
    'Machu Picchu (elevation)': 2430.0,
    '5K Race': 5000.0,
    'Mount Everest': 8848.0,
    '10K Race': 10000.0,
    'Half Marathon': 21097.0,
    'Marathon': 42195.0,

    // Mega distances
    'Great Wall of China': 21196000.0,
  };

  // UI Constants
  static const double defaultBorderRadius = 16.0;
  static const double defaultPadding = 16.0;
  static const double defaultMargin = 8.0;

  // Animation durations
  static const Duration progressAnimationDuration = Duration(milliseconds: 800);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 2000);
  static const Duration snackBarDuration = Duration(seconds: 3);

  // Colors
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF1E88E5);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);

  // Text styles
  static const TextStyle headlineStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.grey,
  );

  // Formatting
  static String formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    if (meters < 1) return '${(meters * 100).toStringAsFixed(0)} cm';
    return '${meters.toStringAsFixed(0)} m';
  }

  static String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  static String getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  static DateTime getStartOfWeek(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  static String getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  static String formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}-${end.day} ${getMonthName(start.month)} ${start.year}';
    } else if (start.year == end.year) {
      return '${start.day} ${getMonthName(start.month)} - ${end.day} ${getMonthName(end.month)} ${start.year}';
    } else {
      return '${start.day} ${getMonthName(start.month)} ${start.year} - ${end.day} ${getMonthName(end.month)} ${end.year}';
    }
  }
}