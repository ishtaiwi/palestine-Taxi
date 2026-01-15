import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_config.dart';
import 'screens/auth/login_page.dart';
import 'utils/server_time_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (skip on web for now due to compatibility issues)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      print('Firebase initialized successfully');
    } catch (e) {
      print('Warning: Firebase initialization failed: $e');
      // Continue even if Firebase fails (for development)
    }
  } else {
    print('⚠️ Firebase initialization skipped on web platform');
  }

  try {
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
    print('Stripe initialized successfully');
  } catch (e) {
    print('Warning: Stripe initialization failed: $e');
  }

  runApp(const TaxiPalestineApp());
  TimeSyncService.sync();
  
  print('App started');
}
