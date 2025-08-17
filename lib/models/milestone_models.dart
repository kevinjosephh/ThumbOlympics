enum MilestoneState { inProgress, upcoming, completed }

class MilestoneView {
  final String label;
  final double meters;
  final double progress; // 0..1 relative to lifetimeDistance
  final MilestoneState state;

  MilestoneView({
    required this.label,
    required this.meters,
    required this.progress,
    required this.state,
  });
}

class MilestoneAchievement {
  final String name;
  final double distance;
  final DateTime achievedOn;

  MilestoneAchievement({
    required this.name,
    required this.distance,
    required this.achievedOn,
  });
}

class DailyData {
  final DateTime date;
  final double distance;
  final int scrolls;

  DailyData({
    required this.date,
    required this.distance,
    required this.scrolls,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'distance': distance,
      'scrolls': scrolls,
    };
  }

  factory DailyData.fromJson(Map<String, dynamic> json) {
    return DailyData(
      date: DateTime.parse(json['date']),
      distance: json['distance']?.toDouble() ?? 0.0,
      scrolls: json['scrolls'] ?? 0,
    );
  }
}

class WeeklySummary {
  final DateTime weekStart;
  final List<DailyData> dailyData;
  final double totalDistance;
  final int totalScrolls;
  final double averageDistance;
  final List<MilestoneAchievement> milestonesAchieved;

  WeeklySummary({
    required this.weekStart,
    required this.dailyData,
    required this.totalDistance,
    required this.totalScrolls,
    required this.averageDistance,
    required this.milestonesAchieved,
  });

  factory WeeklySummary.fromDailyData(DateTime weekStart, List<DailyData> dailyData) {
    final totalDistance = dailyData.fold<double>(0, (sum, data) => sum + data.distance);
    final totalScrolls = dailyData.fold<int>(0, (sum, data) => sum + data.scrolls);
    final averageDistance = dailyData.isNotEmpty ? totalDistance / dailyData.length : 0.0;

    return WeeklySummary(
      weekStart: weekStart,
      dailyData: dailyData,
      totalDistance: totalDistance,
      totalScrolls: totalScrolls,
      averageDistance: averageDistance,
      milestonesAchieved: [], // Will be calculated separately
    );
  }
}