import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

void main() => runApp(const HiltonJiraApp());

class HiltonJiraApp extends StatelessWidget {
  const HiltonJiraApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 2),
      ),
      home: const DashboardScreen(),
    );
  }
}