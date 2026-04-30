import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class CalibreFwsApp extends StatelessWidget {
  const CalibreFwsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calibre Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90D9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90D9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
