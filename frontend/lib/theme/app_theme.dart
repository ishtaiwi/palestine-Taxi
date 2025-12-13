import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const String _themeKey = 'app_theme_mode';
  static bool _isDarkMode = true;

  // Dark mode colors
  static const Color darkBackground = Color(0xFF060A1A);
  static const Color darkAppBar = Color(0xFF060A1A);
  static const Color darkCardBackground = Color(0x0FFFFFFF);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0x3FFFFFFF);
  static const Color darkDateBackground = Colors.black87;
  // Light mode colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightAppBar = Color(0xFFF5F5F5);
  static const Color lightCardBackground = Colors.white;
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const lightDateBackground = Colors.white;

  // Get current theme colors
  static Color get backgroundColor =>
      _isDarkMode ? darkBackground : lightBackground;
  static Color get appBarColor => _isDarkMode ? darkAppBar : lightAppBar;
  static Color get cardBackground =>
      _isDarkMode ? darkCardBackground : lightCardBackground;
  static Color get textPrimary =>
      _isDarkMode ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary =>
      _isDarkMode ? darkTextSecondary : lightTextSecondary;
  static Color get borderColor => _isDarkMode ? darkBorder : lightBorder;
  static Color get datePickerColor =>
      _isDarkMode ? darkDateBackground : lightDateBackground;

  // Helper methods for common color patterns
  static Color getCardBackground([double opacity = 0.05]) {
    return _isDarkMode
        ? Colors.black.withValues(alpha: opacity)
        : darkenColor(Colors.white, 0.07);
  }

  static Color getCardBorder([double opacity = 0.15]) {
    return _isDarkMode
        ? Colors.white.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity * 0.4);
  }

  static Color getShadowColor([double opacity = 0.3]) {
    return _isDarkMode
        ? Colors.black.withValues(alpha: opacity)
        : Colors.black.withValues(alpha: opacity * 0.1);
  }

  /// Lighten a color by adjusting its HSL lightness value
  /// [color] - The color to lighten
  /// [amount] - Amount to lighten (0.0 to 1.0, where 0 = no change, 1.0 = white)
  static Color lightenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Darken a color by adjusting its HSL lightness value
  /// [color] - The color to darken
  /// [amount] - Amount to darken (0.0 to 1.0, where 0 = no change, 1.0 = black)
  static Color darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
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
