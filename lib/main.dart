import 'dart:async';
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
        primarySwatch: Colors.blue,
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
    with WidgetsBindingObserver {
  double totalScrollDistance = 0.0; // in meters
  int scrollCount = 0;
  bool isAccessibilityEnabled = false;
  static const _platform = MethodChannel('thumbolympics/accessibility');

  // Real-world distance comparisons (in meters) - expanded for better perspective
  static const Map<String, double> distanceComparisons = {
    // Small everyday objects & spaces
    'Football Field': 109.7,
    'Swimming Pool (Olympic)': 50.0,
    
    // Buildings & Landmarks
    'Statue of Liberty': 93.0,
    'London Eye': 135.0,
    'Big Ben': 96.0,
    'Eiffel Tower': 324.0,
    'Empire State Building': 443.0,
    'Burj Khalifa': 828.0,
    
    // Natural Features
    'Mount Everest': 8848.0,
    'Grand Canyon (depth)': 1800.0,
    'Niagara Falls (height)': 51.0,
    'Angel Falls': 979.0,
    
    // Sports & Activities
    'Marathon': 42195.0,
    'Half Marathon': 21097.0,
    '10K Race': 10000.0,
    '5K Race': 5000.0,
    'Mile Run': 1609.0,
    
    // Transportation
    'Boeing 747 Length': 70.6,
    'Cruise Ship (avg)': 300.0,
    'Titanic Length': 269.0,
    
    // Cultural & Historical
    'Taj Mahal': 73.0,
    'Machu Picchu (elevation)': 2430.0,
    'Colosseum': 48.0,
    'Great Wall of China': 21196000.0, // Full length
    
    // Fun & Quirky
    'Blue Whale Length': 30.0,
    'T-Rex Length': 12.0,
    'Giraffe Height': 5.5,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadScrollData();

    _platform.setMethodCallHandler((call) async {
      if (call.method == "onScroll") {
        try {
          // Handle scroll data from accessibility service
          if (call.arguments is Map) {
            final data = Map<String, dynamic>.from(call.arguments);
            final pixels = data['distance'] as int? ?? 150;
            
            // Convert pixels to meters (roughly 1 pixel = 0.000264583 meters on average)
            // This is an approximation based on typical phone screen density
            // For better accuracy, we could use device-specific DPI information
            final scrollDistance = pixels * 0.000264583;
            
            setState(() {
              totalScrollDistance += scrollDistance;
              scrollCount++;
            });
            _saveScrollData();
          } else {
            // Fallback for old format
            const scrollDistance = 0.15; // meters per scroll event
            setState(() {
              totalScrollDistance += scrollDistance;
              scrollCount++;
            });
            _saveScrollData();
          }
        } catch (e) {
          // Silent error handling for production
          setState(() {
            totalScrollDistance += 0.15;
            scrollCount++;
          });
          _saveScrollData();
        }
      }
    });

    _checkAccessibilityAndStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when app lifecycle changes (e.g., coming back from settings)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibilityAndStart();
    }
  }

  /// Opens the Accessibility Settings screen
  Future<void> _openAccessibilitySettings() async {
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      // Silent error handling for production
    }
  }

  /// Check if the accessibility service is enabled
  Future<bool> _isAccessibilityEnabled() async {
    try {
      final bool result =
          await _platform.invokeMethod('isAccessibilityServiceEnabled');
      return result;
    } catch (e) {
      return false;
    }
  }

  /// If enabled, start session tracking
  Future<void> _checkAccessibilityAndStart() async {
    final enabled = await _isAccessibilityEnabled();
    setState(() {
      isAccessibilityEnabled = enabled;
    });
  }

  Future<void> _loadScrollData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        totalScrollDistance = prefs.getDouble('totalScrollDistance') ?? 0.0;
        scrollCount = prefs.getInt('scrollCount') ?? 0;
      });
    } catch (e) {
      // Silent error handling for production
    }
  }

  Future<void> _saveScrollData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('totalScrollDistance', totalScrollDistance);
      await prefs.setInt('scrollCount', scrollCount);
    } catch (e) {
      // Silent error handling for production
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else if (meters < 1) {
      return '${(meters * 100).toStringAsFixed(0)} cm';
    } else {
      return '${meters.toStringAsFixed(1)} m';
    }
  }

  List<MapEntry<String, double>> _getRelevantComparisons() {
    final allComparisons = distanceComparisons.entries.toList();
    final completed = <MapEntry<String, double>>[];
    final inProgress = <MapEntry<String, double>>[];
    final upcoming = <MapEntry<String, double>>[];
    
    for (final entry in allComparisons) {
      final ratio = totalScrollDistance / entry.value;
      
      if (ratio >= 1.0) {
        // Completed milestones
        completed.add(entry);
      } else if (ratio >= 0.01) {
        // At least 1% progress - show as in progress
        inProgress.add(entry);
      } else {
        // Future milestones
        upcoming.add(entry);
      }
    }
    
    // Sort completed by ratio (highest multiples first)
    completed.sort((a, b) {
      final ratioA = totalScrollDistance / a.value;
      final ratioB = totalScrollDistance / b.value;
      return ratioB.compareTo(ratioA);
    });
    
    // Sort in-progress by completion percentage (closest to completion first)
    inProgress.sort((a, b) {
      final ratioA = totalScrollDistance / a.value;
      final ratioB = totalScrollDistance / b.value;
      return ratioB.compareTo(ratioA);
    });
    
    // Sort upcoming by distance (closest/smallest first)
    upcoming.sort((a, b) => a.value.compareTo(b.value));
    
    final result = <MapEntry<String, double>>[];
    
    // Add in-progress items first (up to 3) - current goals
    result.addAll(inProgress.take(3));
    
    // Add some upcoming milestones (up to 2) - future motivation  
    final remainingSlotsBeforeCompleted = 5 - result.length - completed.length.clamp(0, 2);
    if (remainingSlotsBeforeCompleted > 0) {
      result.addAll(upcoming.take(remainingSlotsBeforeCompleted));
    }
    
    // Add completed items at the bottom (up to 2) - achievements
    result.addAll(completed.take(2));
    
    return result.take(5).toList();
  }

  String _getPlayfulMessage() {
    if (totalScrollDistance < 1) {
      return "Baby steps in the scrolling Olympics! 👶";
    } else if (totalScrollDistance < 10) {
      return "You're getting the hang of this! 🤸‍♂️";
    } else if (totalScrollDistance < 50) {
      return "Now we're scrolling! 💪";
    } else if (totalScrollDistance < 100) {
      return "Serious scrolling athlete in training! 🏅";
    } else if (totalScrollDistance < 500) {
      return "Olympic-level thumb endurance! 🥇";
    } else if (totalScrollDistance < 1000) {
      return "You could've climbed a skyscraper! 🏔️";
    } else if (totalScrollDistance < 5000) {
      return "Marathon-level scrolling dedication! 🏃‍♀️";
    } else if (totalScrollDistance < 10000) {
      return "You're in the scrolling hall of fame! 🏆";
    } else {
      return "Legendary scroll master! 👑";
    }
  }

  String _getScrollAdvice() {
    if (totalScrollDistance < 10) {
      return "Keep exploring! The scrolling world awaits! 🌟";
    } else if (totalScrollDistance < 50) {
      return "Stay hydrated during your scroll sessions! 💧";
    } else if (totalScrollDistance < 100) {
      return "Don't forget to stretch those thumbs! 🤲";
    } else if (totalScrollDistance < 500) {
      return "Consider some cross-training with other apps! 📱";
    } else if (totalScrollDistance < 1000) {
      return "Maybe it's time for a scrolling break? 🏋️‍♂️";
    } else {
      return "You've definitely earned a gold medal! 🥇";
    }
  }

  @override
  Widget build(BuildContext context) {
    final relevantComparisons = _getRelevantComparisons();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThumbOlympics'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAccessibilityAndStart,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        isAccessibilityEnabled 
                            ? Icons.accessibility_new 
                            : Icons.accessibility,
                        size: 48,
                        color: isAccessibilityEnabled ? Colors.green : Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isAccessibilityEnabled 
                            ? 'Tracking Your Scroll Journey' 
                            : 'Enable Accessibility Service',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isAccessibilityEnabled 
                            ? 'Every scroll is being measured...' 
                            : 'Start your scrolling adventure!',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              if (isAccessibilityEnabled) ...[
                // Total Distance Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Total Scroll Distance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDistance(totalScrollDistance),
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getPlayfulMessage(),
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getScrollAdvice(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Scroll Count Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Scroll Events',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$scrollCount',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'That\'s a lot of swiping! 📱',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Distance Comparisons
                if (relevantComparisons.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Scroll Journey',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          ...relevantComparisons.asMap().entries.map((entry) {
                            final index = entry.key;
                            final comparison = entry.value;
                            final ratio = totalScrollDistance / comparison.value;
                            final percentage = (ratio * 100).toStringAsFixed(1);
                            final remaining = comparison.value - totalScrollDistance;
                            final isCompleted = ratio >= 1.0;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: isCompleted 
                                    ? Colors.green.withOpacity(0.1)
                                    : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: isCompleted 
                                      ? Colors.green.withOpacity(0.3)
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Progress indicator or completion icon
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCompleted 
                                          ? Colors.green
                                          : Theme.of(context).primaryColor.withOpacity(0.2),
                                    ),
                                    child: Icon(
                                      isCompleted ? Icons.check : Icons.flag,
                                      color: isCompleted 
                                          ? Colors.white 
                                          : Theme.of(context).primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                comparison.key,
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: isCompleted ? Colors.green.shade700 : null,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatDistance(comparison.value),
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (isCompleted) ...[
                                          Text(
                                            '🎉 Completed! You scrolled ${ratio.toStringAsFixed(1)}x this distance!',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.green.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ] else ...[
                                          // Progress bar for in-progress items
                                          Row(
                                            children: [
                                              Expanded(
                                                child: LinearProgressIndicator(
                                                  value: ratio.clamp(0.0, 1.0),
                                                  backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Theme.of(context).primaryColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$percentage%',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_formatDistance(remaining)} to go',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              
              // Action Buttons
              ElevatedButton.icon(
                onPressed: _openAccessibilitySettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Accessibility Settings'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 8),
              if (totalScrollDistance > 0)
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() {
                      totalScrollDistance = 0.0;
                      scrollCount = 0;
                    });
                    await _saveScrollData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Counter'),
                ),
              const SizedBox(height: 16), // Bottom padding for safe area
            ],
          ),
        ),
      ),
    );
  }
}