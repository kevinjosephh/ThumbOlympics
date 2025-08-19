import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thumbolympics/screens/history_screen.dart';
import '../services/data_manager.dart';
import '../widgets/ring_progress_painter.dart';
import '../models/milestone_models.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ---------- Data Variables ----------
  double dailyDistance = 0.0;
  int dailyScrolls = 0;
  double lifetimeDistance = 0.0;
  int lifetimeScrolls = 0;
  String lastDateKey = DataManager.todayKey();
  bool isAccessibilityEnabled = false;

  // Animation controllers
  late final AnimationController _pulseCtrl;
  late final AnimationController _progressCtrl;
  double _uiProgress = 0.0;

  // Services
  final DataManager _dataManager = DataManager();
  static const _platform = MethodChannel('thumbolympics/accessibility');

  // Stream controller for real-time updates
  late StreamController<Map<String, dynamic>> _dataStreamController;
  late Stream<Map<String, dynamic>> dataStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize stream controller
    _dataStreamController = StreamController<Map<String, dynamic>>.broadcast();
    dataStream = _dataStreamController.stream;

    // Initialize animations
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Load initial data
    _loadAllData();

    // Set up platform channel handler
    _platform.setMethodCallHandler(_handleMethodCall);

    // Check accessibility status
    _checkAccessibilityAndStart();

    // Set up periodic data sync
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncData();
    });

    // Lightweight health check: periodically verify the service is still enabled
    // and refresh state if it was toggled or crashed.
    Timer.periodic(const Duration(minutes: 2), (timer) async {
      final enabled = await _isAccessibilityEnabled();
      if (mounted && enabled != isAccessibilityEnabled) {
        setState(() => isAccessibilityEnabled = enabled);
      }
      if (!mounted) timer.cancel();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _dataStreamController.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityAndStart();
      _ensureDailyBoundary();
    } else if (state == AppLifecycleState.paused) {
      _saveAllData();
    }
  }

  // ---------- Data Management ----------
  Future<void> _loadAllData() async {
    try {
      final data = await _dataManager.loadAllData();
      
      setState(() {
        dailyDistance = data['dailyDistance'];
        dailyScrolls = data['dailyScrolls'];
        lifetimeDistance = data['lifetimeDistance'];
        lifetimeScrolls = data['lifetimeScrolls'];
        lastDateKey = data['lastDateKey'];
      });

      if (data['isNewDay']) {
        _ensureDailyBoundary();
      }

      _animateProgressTo(_progressToNextGoal());
      _broadcastDataUpdate();
    } catch (e) {
      // Handle error gracefully
      _showErrorSnackBar('Failed to load data. Using defaults.');
    }
  }

  Future<void> _saveAllData() async {
    try {
      await _dataManager.saveAllData(
        dailyDistance: dailyDistance,
        dailyScrolls: dailyScrolls,
        lifetimeDistance: lifetimeDistance,
        lifetimeScrolls: lifetimeScrolls,
        dateKey: lastDateKey,
      );
      _broadcastDataUpdate();
    } catch (e) {
      _showErrorSnackBar('Failed to save data.');
    }
  }

  void _broadcastDataUpdate() {
    _dataStreamController.add({
      'dailyDistance': dailyDistance,
      'dailyScrolls': dailyScrolls,
      'lifetimeDistance': lifetimeDistance,
      'lifetimeScrolls': lifetimeScrolls,
    });
  }

  Future<void> _syncData() async {
    await _ensureDailyBoundary();
    await _saveAllData();
  }

  Future<void> _ensureDailyBoundary() async {
    final today = DataManager.todayKey();
    if (lastDateKey != today) {
      // Persist previous day's final totals under its own date key
      final previousDateKey = lastDateKey;
      try {
        await _dataManager.saveAllData(
          dailyDistance: dailyDistance,
          dailyScrolls: dailyScrolls,
          lifetimeDistance: lifetimeDistance,
          lifetimeScrolls: lifetimeScrolls,
          dateKey: previousDateKey,
        );
      } catch (_) {}

      // Rollover to the new day
      lastDateKey = today;
      dailyDistance = 0.0;
      dailyScrolls = 0;
      if (mounted) setState(() {});

      // Save the zeroed values for the new day
      await _saveAllData();
      _animateProgressTo(_progressToNextGoal());
    }
  }

  // ---------- Platform Channel Handlers ----------
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onScroll') {
      try {
        if (call.arguments is Map) {
          final data = Map<String, dynamic>.from(call.arguments);
          // Prefer distance in meters if provided by native side
          final meters = (data['distanceMeters'] as num?)?.toDouble();
          if (meters != null && meters.isFinite && meters > 0) {
            _recordScrollActivity(meters);
          } else {
            // Backward compat: fall back to pixel-based distance if present
            final pixels = (data['distance'] as num?)?.toDouble();
            if (pixels != null && pixels > 0) {
              final scrollDistance = pixels * AppConstants.pixelToMeterConversion;
              _recordScrollActivity(scrollDistance);
            } else {
              _recordScrollActivity(AppConstants.defaultScrollDistance);
            }
          }
        } else {
          _recordScrollActivity(AppConstants.defaultScrollDistance);
        }
      } catch (e) {
        _recordScrollActivity(AppConstants.defaultScrollDistance);
      }
    }
    return null;
  }

  // ---------- Scroll Activity Recording ----------
  void _recordScrollActivity(double meters) async {
    if (!isAccessibilityEnabled) return;

    await _ensureDailyBoundary();

    setState(() {
      dailyDistance += meters;
      dailyScrolls += 1;
      lifetimeDistance += meters;
      lifetimeScrolls += 1;
    });

    await _saveAllData();
    _animateProgressTo(_progressToNextGoal());
    
    // Check for milestone achievements
    _checkMilestoneAchievements();
  }

  void _checkMilestoneAchievements() {
    final previousProgress = (lifetimeDistance - AppConstants.defaultScrollDistance);
    final currentMilestone = _nextGoal();
    
    if (currentMilestone != null && 
        previousProgress < currentMilestone.value && 
        lifetimeDistance >= currentMilestone.value) {
      _showMilestoneAchievement(currentMilestone.key);
    }
  }

  void _showMilestoneAchievement(String milestone) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '🎉 Achievement Unlocked: $milestone!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------- Accessibility Management ----------
  Future<void> _openAccessibilitySettings() async {
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      _showErrorSnackBar('Unable to open accessibility settings.');
    }
  }

  Future<bool> _isAccessibilityEnabled() async {
    try {
      final bool result = await _platform.invokeMethod('isAccessibilityServiceEnabled');
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkAccessibilityAndStart() async {
    final enabled = await _isAccessibilityEnabled();
    if (mounted) {
      setState(() => isAccessibilityEnabled = enabled);
    }
  }

  // ---------- Progress and Milestone Calculations ----------
  void _animateProgressTo(double target) {
    final begin = _uiProgress;
    final end = target.clamp(0.0, 1.0);
    _progressCtrl.stop();
    _progressCtrl.reset();
    final tween = Tween<double>(begin: begin, end: end);
    _progressCtrl.addListener(() {
      if (mounted) {
        setState(() {
          _uiProgress = tween.evaluate(_progressCtrl);
        });
      }
    });
    _progressCtrl.forward();
  }

  MapEntry<String, double>? _nextGoal() {
    final entries = AppConstants.distanceComparisons.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in entries) {
      if (lifetimeDistance < e.value) return e;
    }
    return entries.isNotEmpty ? entries.last : null;
  }

  double _progressToNextGoal() {
    final goal = _nextGoal();
    if (goal == null || goal.value <= 0) return 0.0;
    return (lifetimeDistance / goal.value).clamp(0.0, 1.0);
  }

  List<MilestoneView> _milestonesForPanel() {
    final items = AppConstants.distanceComparisons.entries
        .map((e) => MilestoneView(
              label: e.key,
              meters: e.value,
              progress: (lifetimeDistance / e.value).clamp(0.0, 1.0),
              state: lifetimeDistance >= e.value
                  ? MilestoneState.completed
                  : (lifetimeDistance / e.value >= 0.01
                      ? MilestoneState.inProgress
                      : MilestoneState.upcoming),
            ))
        .toList();

    final upcoming = items
        .where((i) => i.state == MilestoneState.upcoming || i.state == MilestoneState.inProgress)
        .toList();
    
    upcoming.sort((a, b) => a.meters.compareTo(b.meters));
    final nearestMilestones = upcoming.take(3).toList();

    final completed = items
        .where((i) => i.state == MilestoneState.completed)
        .toList();
    
    completed.sort((a, b) => b.meters.compareTo(a.meters));
    final impressiveCompleted = completed.take(3).toList();

    return [...nearestMilestones, ...impressiveCompleted];
  }

  // ---------- UI Helpers ----------
  String _formatDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    if (meters < 1) return '${(meters * 100).toStringAsFixed(0)} cm';
    return '${meters.toStringAsFixed(0)} m';
  }

  String _getHeadline() {
    final p = lifetimeDistance;
    if (p < 1) return "Baby steps in the scrolling Olympics! 👶";
    if (p < 10) return "You're getting the hang of this! 🤸‍♂️";
    if (p < 50) return "Now we're scrolling! 💪";
    if (p < 100) return "Serious scrolling athlete in training! 🏅";
    if (p < 500) return "Olympic-level thumb endurance! 🥇";
    if (p < 1000) return "You could've climbed a skyscraper! 🏔️";
    if (p < 5000) return "Marathon-level scrolling dedication! 🏃‍♀️";
    if (p < 10000) return "You're in the scrolling hall of fame! 🏆";
    return "Legendary scroll master! 👑";
  }

  String _getAchievementBlurb() {
    final items = _milestonesForPanel();
    for (final m in items) {
      if (m.state == MilestoneState.completed) {
        return "🏁 You just scrolled the height of ${m.label}!";
      }
    }
    for (final m in items) {
      if (m.state == MilestoneState.inProgress && m.progress > 0.1) {
        return "🎯 ${(m.progress * 100).toStringAsFixed(0)}% of the way to ${m.label}!";
      }
    }
    return "🚀 Keep scrolling to reach your first milestone!";
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }


  // ---------- UI Build Method ----------
  @override
  Widget build(BuildContext context) {
    final nextGoal = _nextGoal();
    final nextLabel = nextGoal?.key ?? 'Goal';
    final nextMeters = nextGoal?.value ?? 1.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              // ---------- Header ----------
              _buildHeader(),
              const SizedBox(height: 16),

              // ---------- Status Banner ----------
              _buildStatusBanner(),
              const SizedBox(height: 20),

              // ---------- Progress Ring ----------
              _buildProgressRing(),
              const SizedBox(height: 10),

              // ---------- Distance Display ----------
              _buildDistanceDisplay(nextLabel, nextMeters),
              const SizedBox(height: 16),

              // ---------- Stats Cards ----------
              _buildStatsCards(),
              const SizedBox(height: 16),

              // ---------- Achievement Card ----------
              _buildAchievementCard(),
              const SizedBox(height: 12),

              // ---------- Milestones Card ----------
              _buildMilestonesCard(),
              const SizedBox(height: 12),

              // ---------- Headline ----------
              _buildHeadline(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "ThumbOlympics",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                );
              },
              icon: const Icon(Icons.history, color: Colors.white, size: 28),
              tooltip: 'View History',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAccessibilityEnabled ? Icons.flash_on : Icons.block_flipped,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAccessibilityEnabled
                      ? 'Thumb in Beast Mode! 🔥'
                      : 'Enable Accessibility Service',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (!isAccessibilityEnabled)
                  const Text(
                    'Allow scroll tracking to start your journey',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (!isAccessibilityEnabled)
            ElevatedButton(
              onPressed: _openAccessibilitySettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1976D2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressRing() {
    return Center(
      child: ScaleTransition(
        scale: _pulseCtrl,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: CustomPaint(
            painter: RingProgressPainter(
              progress: _uiProgress,
              backgroundColor: Colors.white.withOpacity(0.28),
              foregroundColor: Colors.white,
              strokeWidth: 12,
            ),
            child: Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.thumb_up,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceDisplay(String nextLabel, double nextMeters) {
    return Column(
      children: [
        Text(
          _formatDistance(lifetimeDistance),
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                'Next: $nextLabel • ${(_uiProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '(${_formatDistance(nextMeters)})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Today',
            primary: _formatDistance(dailyDistance),
            secondary: '$dailyScrolls scrolls',
            icon: Icons.today,
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Lifetime',
            primary: _formatDistance(lifetimeDistance),
            secondary: '$lifetimeScrolls scrolls',
            icon: Icons.all_inclusive,
            color: const Color(0xFF2196F3),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String primary,
    required String secondary,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            primary,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            secondary,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1976D2).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getAchievementBlurb(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1976D2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesCard() {
    final items = _milestonesForPanel();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flag, size: 16, color: Color(0xFF1976D2)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Milestones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                _formatDistance(lifetimeDistance),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((m) => _buildMilestoneRow(m)),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow(MilestoneView milestone) {
    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: milestone.state == MilestoneState.completed
          ? const Color(0xFF2E7D32)
          : Colors.black87,
    );
    final subStyle = TextStyle(fontSize: 12, color: Colors.grey[600]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: milestone.state == MilestoneState.completed
            ? const Color(0xFF2E7D32).withOpacity(0.05)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: milestone.state == MilestoneState.completed
              ? const Color(0xFF2E7D32).withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: milestone.state == MilestoneState.completed
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF1976D2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              milestone.state == MilestoneState.completed
                  ? Icons.check
                  : (milestone.state == MilestoneState.inProgress
                      ? Icons.timelapse
                      : Icons.flag_outlined),
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(milestone.label, style: labelStyle),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: milestone.progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      milestone.state == MilestoneState.completed
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1976D2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${(milestone.progress * 100).toStringAsFixed(0)}%', style: subStyle),
                    const Spacer(),
                    Text(_formatDistance(milestone.meters), style: subStyle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadline() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        _getHeadline(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.95),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}