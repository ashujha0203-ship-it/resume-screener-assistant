import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF315C72),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF7F9FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF7F9FA),
      foregroundColor: Color(0xFF18252D),
      centerTitle: false,
      elevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFD8E8EE),
    ),
  );
}
