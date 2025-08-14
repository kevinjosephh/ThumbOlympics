import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ThumbOlympicsApp());
}

class ThumbOlympicsApp extends StatelessWidget {
  const ThumbOlympicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ThumbOlympics',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1976D2),
        useMaterial3: true,
      ),
      home: const ThumbOlympicsHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ThumbOlympicsHomePage extends StatefulWidget {
  const ThumbOlympicsHomePage({super.key});

  @override
  State<ThumbOlympicsHomePage> createState() => _ThumbOlympicsHomePageState();
}

class _ThumbOlympicsHomePageState extends State<ThumbOlympicsHomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ---------- Counters ----------
  // Daily
  double dailyDistance = 0.0; // meters
  int dailyScrolls = 0;
  // Lifetime
  double lifetimeDistance = 0.0; // meters
  int lifetimeScrolls = 0;

  String lastDateKey = _todayKey();
  bool isAccessibilityEnabled = false;

  // Animation for progress ring & thumb
  late final AnimationController _pulseCtrl;
  late final AnimationController _progressCtrl;
  double _uiProgress = 0.0; // animated value for ring

  static const _platform = MethodChannel('thumbolympics/accessibility');

  // ---------- Milestones (in meters) ----------
  static const Map<String, double> distanceComparisons = {
    // Everyday / Small
    'Giraffe Height': 5.5,
    'T-Rex Length': 12.0,
    'Blue Whale Length': 30.0,
    'Swimming Pool (Olympic)': 50.0,
    'Niagara Falls (height)': 51.0,
    'Football Field': 109.7,
    'Big Ben': 96.0,
    'Statue of Liberty': 93.0,
    'Taj Mahal': 73.0,
    'Boeing 747 Length': 70.6,

    // Landmarks
    'London Eye': 135.0,
    'Eiffel Tower': 324.0,
    'Empire State Building': 443.0,
    'Burj Khalifa': 828.0,

    // Nature
    'Angel Falls': 979.0,
    'Grand Canyon (depth)': 1800.0,
    'Machu Picchu (elevation)': 2430.0,
    'Mount Everest': 8848.0,

    // Sports
    'Mile Run': 1609.0,
    '5K Race': 5000.0,
    '10K Race': 10000.0,
    'Half Marathon': 21097.0,
    'Marathon': 42195.0,

    // Vehicles / Big
    'Titanic Length': 269.0,
    'Cruise Ship (avg)': 300.0,

    // Absurd
    'Colosseum': 48.0,
    'Great Wall of China': 21196000.0,
  };

  // ---------- Lifecycle ----------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    _loadAll();

    _platform.setMethodCallHandler((call) async {
      if (call.method == 'onScroll') {
        try {
          if (call.arguments is Map) {
            final data = Map<String, dynamic>.from(call.arguments);
            final pixels = (data['distance'] as num?)?.toDouble() ?? 150.0;
            // Approx conversion: 1 px ≈ 0.000264583 m
            final scrollDistance = pixels * 0.000264583;
            _bump(scrollDistance);
          } else {
            // Fallback per event
            _bump(0.15);
          }
        } catch (e) {
          _bump(0.15);
        }
      }
    });

    _checkAccessibilityAndStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityAndStart();
      _ensureDailyBoundary();
    }
  }

  // ---------- Storage ----------
  static const _kDailyDistance = 'dailyDistance';
  static const _kDailyScrolls = 'dailyScrolls';
  static const _kLifetimeDistance = 'lifetimeDistance';
  static const _kLifetimeScrolls = 'lifetimeScrolls';
  static const _kLastDateKey = 'lastDateKey';

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDate = prefs.getString(_kLastDateKey) ?? _todayKey();
      lastDateKey = savedDate;

      lifetimeDistance = prefs.getDouble(_kLifetimeDistance) ?? 0.0;
      lifetimeScrolls = prefs.getInt(_kLifetimeScrolls) ?? 0;

      if (savedDate == _todayKey()) {
        dailyDistance = prefs.getDouble(_kDailyDistance) ?? 0.0;
        dailyScrolls = prefs.getInt(_kDailyScrolls) ?? 0;
      } else {
        dailyDistance = 0.0;
        dailyScrolls = 0;
        lastDateKey = _todayKey();
      }

      setState(() {});
      _animateProgressTo(_progressToNextGoal());
    } catch (_) {
      // Best effort; keep defaults
    }
  }

  Future<void> _saveAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastDateKey, lastDateKey);
      await prefs.setDouble(_kDailyDistance, dailyDistance);
      await prefs.setInt(_kDailyScrolls, dailyScrolls);
      await prefs.setDouble(_kLifetimeDistance, lifetimeDistance);
      await prefs.setInt(_kLifetimeScrolls, lifetimeScrolls);
    } catch (_) {}
  }

  Future<void> _resetToday() async {
    dailyDistance = 0.0;
    dailyScrolls = 0;
    lastDateKey = _todayKey();
    setState(() {});
    await _saveAll();
    _animateProgressTo(_progressToNextGoal());
  }

  Future<void> _resetAll() async {
    dailyDistance = 0.0;
    dailyScrolls = 0;
    lifetimeDistance = 0.0;
    lifetimeScrolls = 0;
    lastDateKey = _todayKey();
    setState(() {});
    await _saveAll();
    _animateProgressTo(_progressToNextGoal());
  }

  void _ensureDailyBoundary() async {
    final today = _todayKey();
    if (lastDateKey != today) {
      lastDateKey = today;
      dailyDistance = 0.0;
      dailyScrolls = 0;
      setState(() {});
      await _saveAll();
      _animateProgressTo(_progressToNextGoal());
    }
  }

  // ---------- Accessibility ----------
  Future<void> _openAccessibilitySettings() async {
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<bool> _isAccessibilityEnabled() async {
    try {
      final bool result =
          await _platform.invokeMethod('isAccessibilityServiceEnabled');
      return result;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkAccessibilityAndStart() async {
    final enabled = await _isAccessibilityEnabled();
    setState(() => isAccessibilityEnabled = enabled);
  }

  // ---------- Helpers ----------
  void _bump(double meters) async {
    _ensureDailyBoundary();

    dailyDistance += meters;
    dailyScrolls += 1;
    lifetimeDistance += meters;
    lifetimeScrolls += 1;
    setState(() {});
    await _saveAll();

    final newProgress = _progressToNextGoal();
    _animateProgressTo(newProgress);
  }

  void _animateProgressTo(double target) {
    final begin = _uiProgress;
    final end = target.clamp(0.0, 1.0);
    _progressCtrl.stop();
    _progressCtrl.reset();
    final tween = Tween<double>(begin: begin, end: end);
    _progressCtrl.addListener(() {
      setState(() {
        _uiProgress = tween.evaluate(_progressCtrl);
      });
    });
    _progressCtrl.forward();
  }

  String _fmtDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    if (meters < 1) return '${(meters * 100).toStringAsFixed(0)} cm';
    return '${meters.toStringAsFixed(0)} m';
  }

  MapEntry<String, double>? _nextGoal() {
    final entries = distanceComparisons.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in entries) {
      if (lifetimeDistance < e.value) return e;
    }
    return entries.isNotEmpty ? entries.last : null;
  }

  double _progressToNextGoal() {
    final goal = _nextGoal();
    if (goal == null || goal.value <= 0) return 0;
    return (lifetimeDistance / goal.value).clamp(0.0, 1.0);
  }

  List<_MilestoneView> _milestonesForPanel() {
    final items = distanceComparisons.entries
        .map((e) => _MilestoneView(
              label: e.key,
              meters: e.value,
              progress: (lifetimeDistance / e.value).clamp(0.0, 1.0),
              state: lifetimeDistance >= e.value
                  ? _MilestoneState.completed
                  : (lifetimeDistance / e.value >= 0.01
                      ? _MilestoneState.inProgress
                      : _MilestoneState.upcoming),
            ))
        .toList();

    // Get 3 most nearest upcoming/in-progress milestones
    final upcoming = items
        .where((i) => i.state == _MilestoneState.upcoming || i.state == _MilestoneState.inProgress)
        .toList();
    
    // Sort by distance (nearest first)
    upcoming.sort((a, b) => a.meters.compareTo(b.meters));
    final nearestMilestones = upcoming.take(3).toList();

    // Get 3 most impressive completed milestones
    final completed = items
        .where((i) => i.state == _MilestoneState.completed)
        .toList();
    
    // Sort by distance value (most impressive/largest first)
    completed.sort((a, b) => b.meters.compareTo(a.meters));
    final impressiveCompleted = completed.take(3).toList();

    // Combine them: nearest first, then impressive completed
    return [
      ...nearestMilestones,
      ...impressiveCompleted,
    ];
  }

  String _headline() {
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

  String _achievementBlurb() {
    final items = _milestonesForPanel();
    for (final m in items) {
      if (m.state == _MilestoneState.completed) {
        return "🏁 You just scrolled the height of ${m.label}!";
      }
    }
    for (final m in items) {
      if (m.state == _MilestoneState.inProgress && m.progress > 0.1) {
        return "🎯 ${(m.progress * 100).toStringAsFixed(0)}% of the way to ${m.label}!";
      }
    }
    return "🚀 Keep scrolling to reach your first milestone!";
  }

  // ---------- UI ----------
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
              // ---------- Status Banner ----------
              Container(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Text(
                      "ThumbOlympics",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600
                      ),
                    )
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAccessibilityEnabled
                          ? Icons.flash_on
                          : Icons.block_flipped,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isAccessibilityEnabled
                            ? 'Thumb in Beast Mode'
                            : 'Enable Accessibility Service to start tracking',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isAccessibilityEnabled)
                      TextButton(
                        onPressed: _openAccessibilitySettings,
                        child: const Text('Enable'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ---------- Big Progress Ring ----------
              Center(
                child: ScaleTransition(
                  scale: _pulseCtrl,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: CustomPaint(
                      painter: RingProgressPainter(
                        progress: _uiProgress,
                        backgroundColor: Colors.white.withOpacity(0.28),
                        foregroundColor: Colors.white,
                        strokeWidth: 10,
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
              ),
              const SizedBox(height: 10),

              // Distances + Next Goal
              Column(
                children: [
                  Text(
                    _fmtDistance(lifetimeDistance),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Next: $nextLabel • ${(_uiProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '(${_fmtDistance(nextMeters)})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---------- Cards Row: Today / Lifetime ----------
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      title: 'Today',
                      primary: _fmtDistance(dailyDistance),
                      secondary: '$dailyScrolls scrolls',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      title: 'Lifetime',
                      primary: _fmtDistance(lifetimeDistance),
                      secondary: '$lifetimeScrolls scrolls',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---------- Achievement ----------
              _achievementCard(_achievementBlurb()),
              const SizedBox(height: 12),

              // ---------- Milestones ----------
              _milestonesCard(_milestonesForPanel()),
              const SizedBox(height: 8),

              // Optional guidance / fun line
              Text(
                _headline(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Small UI Builders ----------
  Widget _statCard({
    required String title,
    required String primary,
    required String secondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(
            primary,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            secondary,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, size: 28, color: Color(0xFF1976D2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
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

  Widget _milestonesCard(List<_MilestoneView> items) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.flag, size: 20, color: Color(0xFF1976D2)),
              const SizedBox(width: 8),
              const Text(
                'Milestones',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _fmtDistance(lifetimeDistance),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final m in items) _milestoneRow(m),
        ],
      ),
    );
  }

  Widget _milestoneRow(_MilestoneView m) {
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: m.state == _MilestoneState.completed
          ? const Color(0xFF2E7D32)
          : Colors.black,
    );
    final subStyle = TextStyle(fontSize: 12, color: Colors.grey[700]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            m.state == _MilestoneState.completed
                ? Icons.check_circle
                : (m.state == _MilestoneState.inProgress
                    ? Icons.timelapse
                    : Icons.flag_outlined),
            size: 18,
            color: m.state == _MilestoneState.completed
                ? const Color(0xFF2E7D32)
                : const Color(0xFF1976D2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.label, style: labelStyle),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: m.progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      m.state == _MilestoneState.completed
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1976D2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${(m.progress * 100).toStringAsFixed(0)}%', style: subStyle),
                    const Spacer(),
                    Text(_fmtDistance(m.meters), style: subStyle),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Painter: ring between 200 and 180 ----------
class RingProgressPainter extends CustomPainter {
  final double progress; // 0..1
  final Color backgroundColor;
  final Color foregroundColor;
  final double strokeWidth;

  RingProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - (strokeWidth / 2);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // background ring
    canvas.drawCircle(center, radius, bgPaint);

    // progress arc
    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant RingProgressPainter old) {
    return old.progress != progress ||
        old.backgroundColor != backgroundColor ||
        old.foregroundColor != foregroundColor ||
        old.strokeWidth != strokeWidth;
  }
}

// ---------- Milestone helpers ----------
enum _MilestoneState { inProgress, upcoming, completed }

class _MilestoneView {
  final String label;
  final double meters;
  final double progress; // 0..1 relative to lifetimeDistance
  final _MilestoneState state;

  _MilestoneView({
    required this.label,
    required this.meters,
    required this.progress,
    required this.state,
  });
}