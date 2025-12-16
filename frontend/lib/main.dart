import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'config/app_config.dart';
import 'screens/auth/login_page.dart';
import 'utils/server_time_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  
  Stripe.publishableKey = AppConfig.stripePublishableKey;
  await Stripe.instance.applySettings();

  runApp(const TaxiPalestineApp());
  TimeSyncService.sync();
  
  print('app started');
}
