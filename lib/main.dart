import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'services/reading_progress_service.dart';

void main() {
  runApp(const LumenApp());
}

class LumenApp extends StatelessWidget {
  const LumenApp({super.key, this.progressStore});

  final ReadingProgressStore? progressStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumen',

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB9E76A),
          brightness: Brightness.dark,
          surface: const Color(0xFF141714),
        ),
        scaffoldBackgroundColor: const Color(0xFF101210),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101210),
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF101210),
          selectedItemColor: Color(0xFFB9E76A),
          unselectedItemColor: Color(0xFFA1A5A1),
        ),
        dividerColor: Colors.white12,
      ),
      home: const MainNavigation(),
    );
  }
}
