import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/data_manager.dart';
import '../models/milestone_models.dart';
import '../utils/constants.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime selectedWeek = DateTime.now();
  Map<String, Map<String, dynamic>> weeklyData = {};
  final List<String> weekDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  bool isLoading = true;

  final DataManager _dataManager = DataManager();

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    setState(() => isLoading = true);
    try {
      final startOfWeek = AppConstants.getStartOfWeek(selectedWeek);
      final data = await _dataManager.getWeeklyData(startOfWeek);
      setState(() {
        weeklyData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Failed to load weekly data');
    }
  }

  void _previousWeek() {
    setState(() {
      selectedWeek = selectedWeek.subtract(const Duration(days: 7));
    });
    _loadWeeklyData();
  }

  void _nextWeek() {
    final now = DateTime.now();
    final currentWeekStart = AppConstants.getStartOfWeek(now);
    final selectedWeekStart = AppConstants.getStartOfWeek(selectedWeek);
    if (selectedWeekStart.isBefore(currentWeekStart)) {
      setState(() {
        selectedWeek = selectedWeek.add(const Duration(days: 7));
      });
      _loadWeeklyData();
    }
  }

  double _getWeeklyAverage() {
    if (weeklyData.isEmpty) return 0.0;
    final total = weeklyData.values
        .map((data) => (data['distance'] as double))
        .fold<double>(0.0, (sum, d) => sum + d);
    return total / 7;
  }

  double _getWeeklyTotal() {
    if (weeklyData.isEmpty) return 0.0;
    return weeklyData.values
        .map((data) => (data['distance'] as double))
        .fold<double>(0.0, (sum, d) => sum + d);
  }

  int _getWeeklyTotalScrolls() {
    if (weeklyData.isEmpty) return 0;
    return weeklyData.values
        .map((data) => (data['scrolls'] as int))
        .fold<int>(0, (sum, s) => sum + s);
  }

  List<MilestoneAchievement> _getWeeklyMilestones() {
    final weeklyTotal = _getWeeklyTotal();
    final achievements = <MilestoneAchievement>[];
    final sortedMilestones = AppConstants.distanceComparisons.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final milestone in sortedMilestones) {
      if (weeklyTotal >= milestone.value) {
        achievements.add(MilestoneAchievement(
          name: milestone.key,
          distance: milestone.value,
          achievedOn: AppConstants.getStartOfWeek(selectedWeek),
        ));
      }
    }
    achievements.sort((a, b) => b.distance.compareTo(a.distance));
    return achievements.take(5).toList();
  }

  String _getWeekRange() {
    final start = AppConstants.getStartOfWeek(selectedWeek);
    final end = start.add(const Duration(days: 6));
    return AppConstants.formatDateRange(start, end);
  }

  bool _isCurrentWeek() {
    final now = DateTime.now();
    final currentWeekStart = AppConstants.getStartOfWeek(now);
    final selectedWeekStart = AppConstants.getStartOfWeek(selectedWeek);
    return currentWeekStart.isAtSameMomentAs(selectedWeekStart);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxDistance = weeklyData.values.isEmpty
        ? 100.0
        : weeklyData.values
            .map((data) => data['distance'] as double)
            .reduce((a, b) => math.max(a, b));

    final weeklyAverage = _getWeeklyAverage();
    final weeklyTotal = _getWeeklyTotal();
    final weeklyTotalScrolls = _getWeeklyTotalScrolls();
    final milestones = _getWeeklyMilestones();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppConstants.lightBlue, AppConstants.primaryBlue],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildWeekSelector(),
                              const SizedBox(height: 24),
                              _buildBarChart(maxDistance),
                              const SizedBox(height: 24),
                              _buildWeeklyStats(weeklyAverage, weeklyTotal, weeklyTotalScrolls),
                              const SizedBox(height: 20),
                              if (milestones.isNotEmpty) ...[
                                _buildMilestonesSection(milestones),
                                const SizedBox(height: 20),
                              ],
                              _buildWeeklyInsights(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          ),
          const Expanded(
            child: Text(
              'History',
              style: AppConstants.headlineStyle,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousWeek,
            icon: const Icon(Icons.chevron_left),
            color: AppConstants.primaryBlue,
            iconSize: 28,
          ),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isCurrentWeek() ? 'This Week' : 'Week',
                  style: AppConstants.subtitleStyle,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _getWeekRange(),
                  style: AppConstants.titleStyle,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isCurrentWeek() ? null : _nextWeek,
            icon: const Icon(Icons.chevron_right),
            color: _isCurrentWeek() ? Colors.grey[400] : AppConstants.primaryBlue,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  /// Fixed Bar Chart (no overflow, no horizontal scroll)
  Widget _buildBarChart(double maxDistance) {
    const double barsAreaHeight = 160; // where bars + tooltip live
    const double labelsHeight = 36;    // day + date labels
    const double chartHeight = barsAreaHeight + labelsHeight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / 7;
          final barWidth = math.min(32.0, slotWidth * 0.5); // fits without scroll

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Daily Distance',
                      style: AppConstants.titleStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Max: ${AppConstants.formatDistance(maxDistance)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppConstants.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chart area
              SizedBox(
                height: chartHeight,
                width: constraints.maxWidth,
                child: Column(
                  children: [
                    // Bars track
                    SizedBox(
                      height: barsAreaHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (index) {
                          final startOfWeek = AppConstants.getStartOfWeek(selectedWeek);
                          final date = startOfWeek.add(Duration(days: index));
                          final dateKey = AppConstants.getDateKey(date);
                          final data = weeklyData[dateKey];
                          final distance = (data?['distance'] as double?) ?? 0.0;
                          final scrolls = (data?['scrolls'] as int?) ?? 0;
                          final isToday = AppConstants.getDateKey(DateTime.now()) == dateKey;

                          // allocate space for tooltip to avoid overflow inside bars track
                          const double minTooltipSpace = 18.0; // approx tooltip height
                          final maxBarSpace = distance > 0 ? (barsAreaHeight - minTooltipSpace) : barsAreaHeight;
                          final proportionalHeight = (maxDistance > 0 ? (distance / maxDistance) : 0) * maxBarSpace;
                          final barHeight = math.max(4.0, proportionalHeight);

                          return Expanded(
                            child: GestureDetector(
                              onTap: distance > 0 ? () => _showDayDetails(date, distance, scrolls) : null,
                              child:SingleChildScrollView(
                                child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (distance > 0)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        AppConstants.formatDistance(distance),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  Container(
                                    width: barWidth,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      gradient: distance > 0
                                          ? LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: isToday
                                                  ? [
                                                      AppConstants.successGreen,
                                                      AppConstants.successGreen.withOpacity(0.7),
                                                    ]
                                                  : [
                                                      AppConstants.primaryBlue,
                                                      AppConstants.lightBlue,
                                                    ],
                                            )
                                          : null,
                                      color: distance == 0 ? Colors.grey[300] : null,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ],
                              ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Labels track
                    SizedBox(
                      height: labelsHeight,
                      child: Row(
                        children: List.generate(7, (index) {
                          final startOfWeek = AppConstants.getStartOfWeek(selectedWeek);
                          final date = startOfWeek.add(Duration(days: index));
                          final dayLabel = weekDays[index];
                          final dateKey = AppConstants.getDateKey(date);
                          final isToday = AppConstants.getDateKey(DateTime.now()) == dateKey;

                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  dayLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isToday ? AppConstants.successGreen : Colors.grey[600],
                                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDayDetails(DateTime date, double distance, int scrolls) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '${AppConstants.getMonthName(date.month)} ${date.day}, ${date.year}',
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow(Icons.straighten, 'Distance', AppConstants.formatDistance(distance)),
              const SizedBox(height: 8),
              _buildStatRow(Icons.touch_app, 'Scrolls', AppConstants.formatNumber(scrolls)),
              const SizedBox(height: 8),
              _buildStatRow(Icons.speed, 'Avg per Scroll',
                  scrolls > 0 ? AppConstants.formatDistance(distance / scrolls) : '0 m'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppConstants.primaryBlue),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildWeeklyStats(double average, double total, int totalScrolls) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                'Average',
                AppConstants.formatDistance(average),
                '${(average * 7).toStringAsFixed(0)}m weekly target',
                Icons.trending_up,
                AppConstants.warningOrange,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: cardWidth,
              child: _buildStatCard(
                'Total',
                AppConstants.formatDistance(total),
                '${AppConstants.formatNumber(totalScrolls)} scrolls',
                Icons.thumb_up,
                AppConstants.primaryBlue,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String primary, String secondary, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppConstants.subtitleStyle,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            primary,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            secondary,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesSection(List<MilestoneAchievement> milestones) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: AppConstants.successGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Milestones This Week',
                  style: AppConstants.titleStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.successGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${milestones.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...milestones.asMap().entries.map((entry) {
            final index = entry.key;
            final milestone = entry.value;
            return Container(
              margin: EdgeInsets.only(bottom: index < milestones.length - 1 ? 12 : 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.successGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppConstants.successGreen.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppConstants.successGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          milestone.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        Text(
                          AppConstants.formatDistance(milestone.distance),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppConstants.successGreen,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.star,
                    color: Colors.amber[600],
                    size: 20,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeeklyInsights() {
    final weeklyTotal = _getWeeklyTotal();
    final weeklyAverage = _getWeeklyAverage();
    final activeDays =
        weeklyData.values.where((data) => (data['distance'] as double) > 0).length;

    String insight;
    IconData insightIcon;
    Color insightColor;

    if (activeDays == 0) {
      insight = "No scrolling activity this week. Time to get those thumbs moving! 💪";
      insightIcon = Icons.hourglass_empty;
      insightColor = Colors.grey;
    } else if (activeDays <= 2) {
      insight = "Light scrolling week. Try to be more consistent! 📱";
      insightIcon = Icons.timeline;
      insightColor = AppConstants.warningOrange;
    } else if (activeDays <= 4) {
      insight = "Good progress! You're building a solid scrolling habit 📈";
      insightIcon = Icons.trending_up;
      insightColor = AppConstants.primaryBlue;
    } else if (activeDays <= 6) {
      insight = "Excellent consistency! You're a scrolling champion! 🏆";
      insightIcon = Icons.star;
      insightColor = AppConstants.successGreen;
    } else {
      insight = "Perfect week! You've scrolled every single day! 🎉";
      insightIcon = Icons.celebration;
      insightColor = AppConstants.successGreen;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            insightColor.withOpacity(0.1),
            insightColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: insightColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: insightColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(insightIcon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Weekly Insight',
                  style: AppConstants.titleStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _buildInsightStat('Active Days', '$activeDays/7'),
              _buildInsightStat('Best Day', _getBestDay()),
              _buildInsightStat('Total', AppConstants.formatDistance(weeklyTotal)),
              _buildInsightStat('Avg/Day', AppConstants.formatDistance(weeklyAverage)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _getBestDay() {
    if (weeklyData.isEmpty) return 'None';
    double maxD = 0;
    String bestDay = 'None';
    weeklyData.forEach((dateKey, data) {
      final d = data['distance'] as double;
      if (d > maxD) {
        maxD = d;
        final parts = dateKey.split('-');
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        bestDay = weekDays[date.weekday - 1];
      }
    });
    return bestDay;
  }
}
