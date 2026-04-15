import 'package:flutter/material.dart';
import 'screens/setup_screen.dart';

void main() {
  runApp(const DebateArenaApp());
}

class DebateArenaApp extends StatelessWidget {
  const DebateArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Debate Arena',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const SetupScreen(),
    );
  }
}
