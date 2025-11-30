import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart'; // adjust import if needed

class TimeSyncService {
  static Duration _offset = Duration.zero;

  /// Sync device time with server time
  static Future<void> sync() async {
    final url = Uri.parse("${AppConfig.apiBaseUrl}/time");

    print("🌐 [TimeSync] Syncing from: $url");

    final res = await http.get(url);

    print("📥 [TimeSync] Raw body: ${res.body}");

    if (res.statusCode != 200) {
      print("❌ [TimeSync] Failed to load server time.");
      throw Exception("Failed to sync time");
    }

    final data = jsonDecode(res.body);
    final serverTimeString = data["time"];

    print("🕒 [TimeSync] Server time string: $serverTimeString");

    // Correctly parse server time (local)
    final serverTime = _parseServerLocalTime(serverTimeString);

    print("🕒 [TimeSync] Server DateTime parsed (LOCAL): $serverTime");

    final deviceTime = DateTime.now();
    print("📱 [TimeSync] Device local time: $deviceTime");

    _offset = serverTime.difference(deviceTime);

    print("⚖️ [TimeSync] Calculated offset: $_offset");

    final computed = DateTime.now().add(_offset);
    print("🧮 [TimeSync] Computed server time now: $computed");

    print("✅ [TimeSync] Sync complete.");
  }

  /// Parse server ISO string WITHOUT converting to UTC
  /// Server format example: 2025-11-30T01:16:35.152+02:00
  static DateTime _parseServerLocalTime(String isoString) {
    // Remove timezone (+02:00)
    final tzRegex = RegExp(r'([+-]\d{2}):(\d{2})$');
    final datePart = isoString.replaceFirst(tzRegex, "");

    // Parse the datePart as local time (correct behavior)
    return DateTime.parse(datePart);
  }

  /// Get current server-synced time
  static DateTime now() => DateTime.now().add(_offset);
}
