import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

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
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}