import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const String _themeKey = 'app_theme_mode';
  static bool _isDarkMode = true;

  // Dark mode colors
  static const Color darkBackground = Color(0xFF060A1A);
  static const Color darkAppBar = Color(0xFF1E3A5F);
  static const Color darkCardBackground = Color(0x0FFFFFFF);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0x3FFFFFFF);

  // Light mode colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightAppBar = Color(0xFF2196F3);
  static const Color lightCardBackground = Colors.white;
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightBorder = Color(0xFFE0E0E0);

  // Get current theme colors
  static Color get backgroundColor => _isDarkMode ? darkBackground : lightBackground;
  static Color get appBarColor => _isDarkMode ? darkAppBar : lightAppBar;
  static Color get cardBackground => _isDarkMode 
      ? darkCardBackground 
      : lightCardBackground;
  static Color get textPrimary => _isDarkMode ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => _isDarkMode ? darkTextSecondary : lightTextSecondary;
  static Color get borderColor => _isDarkMode ? darkBorder : lightBorder;

  // Helper methods for common color patterns
  static Color getCardBackground([double opacity = 0.05]) {
    return _isDarkMode 
        ? Colors.white.withOpacity(opacity)
        : Colors.black.withOpacity(opacity * 0.1);
  }

  static Color getCardBorder([double opacity = 0.15]) {
    return _isDarkMode
        ? Colors.white.withOpacity(opacity)
        : Colors.black.withOpacity(opacity * 0.1);
  }

  static Color getShadowColor([double opacity = 0.3]) {
    return _isDarkMode
        ? Colors.black.withOpacity(opacity)
        : Colors.black.withOpacity(opacity * 0.1);
  }

  // Initialize theme from preferences
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? true;
  }

  // Get current theme mode
  static bool get isDarkMode => _isDarkMode;

  // Toggle theme
  static Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }

  // Set theme
  static Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }
}

