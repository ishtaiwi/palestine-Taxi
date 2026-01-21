import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/terminal/walkin_terminal_page.dart';

/// Standalone Terminal Application Entry Point
/// 
/// This is a separate app build specifically for terminal/kiosk devices.
/// It only shows the walk-in booking terminal and has no access to
/// login or other main app features.
/// 
/// To run this app separately:
/// - For Android: flutter run -t lib/terminal_main.dart
/// - For iOS: flutter run -t lib/terminal_main.dart
/// - For Web: flutter run -d chrome -t lib/terminal_main.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const TerminalApp());
}

class TerminalApp extends StatelessWidget {
  const TerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pal Taxi Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0A1929),
        scaffoldBackgroundColor: const Color(0xFF0A1929),
      ),
      // Add localization support for DatePicker and other Material widgets
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ar', ''), // Arabic
      ],
      // Terminal app always goes directly to terminal page
      home: const WalkinTerminalPage(),
      // Disable back button navigation (terminal should be fullscreen kiosk mode)
      builder: (context, child) {
        return PopScope(
          canPop: false, // Prevent back navigation - terminal should always stay on screen
          child: child!,
        );
      },
    );
  }
}

