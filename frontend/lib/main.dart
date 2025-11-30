import 'package:flutter/material.dart';
import 'screens/auth/login_page.dart';
import 'utils/server_time_sync.dart';

void main() {
  runApp(const TaxiPalestineApp());
  TimeSyncService.sync();
}
