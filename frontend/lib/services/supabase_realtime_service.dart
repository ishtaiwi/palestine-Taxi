import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseRealtimeService {
  static SupabaseClient? _client;
  static RealtimeChannel? _channel;
  static Function(Map<String, dynamic>)? _onLocationUpdate;

  /// Initialize Supabase client
  /// Note: You'll need to add SUPABASE_URL and SUPABASE_ANON_KEY to your app config
  static Future<void> initialize() async {
    if (_client != null) {
      return;
    }

    // TODO: Add Supabase URL and anon key to app_config.dart
    // For now, we'll need to get these from environment or config
    // You can get these from your Supabase project settings
    
    // Example initialization (you'll need to add these values):
    // await Supabase.initialize(
    //   url: 'YOUR_SUPABASE_URL',
    //   anonKey: 'YOUR_SUPABASE_ANON_KEY',
    // );
    
    // _client = Supabase.instance.client;
  }

  /// Subscribe to vehicle location updates
  static Future<void> subscribeToVehicleLocations(
    Function(Map<String, dynamic>) onUpdate,
  ) async {
    try {
      await initialize();
      if (_client == null) {
        print('Supabase client not initialized');
        return;
      }

      _onLocationUpdate = onUpdate;

      // Subscribe to vehicle_location table changes
      _channel = _client!.channel('vehicle_locations')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicle_location',
          callback: (payload) {
            if (_onLocationUpdate != null) {
              _onLocationUpdate!(payload.newRecord);
            }
          },
        )
        ..subscribe();

      print('Subscribed to vehicle location updates');
    } catch (e) {
      print('Error subscribing to vehicle locations: $e');
    }
  }

  /// Unsubscribe from vehicle location updates
  static Future<void> unsubscribe() async {
    try {
      await _channel?.unsubscribe();
      _channel = null;
      _onLocationUpdate = null;
      print('Unsubscribed from vehicle location updates');
    } catch (e) {
      print('Error unsubscribing: $e');
    }
  }

  /// Get Supabase client instance
  static SupabaseClient? get client => _client;
}

