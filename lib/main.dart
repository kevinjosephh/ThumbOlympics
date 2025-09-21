import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/data_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Ensure data manager is initialized on app startup
  final dataManager = DataManager();
  await dataManager.loadAllData();
  
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
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
