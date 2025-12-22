import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

class SupabaseRealtimeService {
  static SupabaseClient? _client;
  static RealtimeChannel? _channel;
  static Function(Map<String, dynamic>)? _onLocationUpdate;

  /// Initialize Supabase client by fetching config from server
  static Future<void> initialize() async {
    if (_client != null) {
      return;
    }

    try {
      // Fetch Supabase configuration from server
      final config = await ApiService.getSupabaseConfig();

      if (config['success'] != true) {
        print('Failed to get Supabase config: ${config['message']}');
        return;
      }

      final String? url = config['url'];
      final String? anonKey = config['anonKey'];

      if (url == null || anonKey == null) {
        print('Supabase URL or anon key is null');
        return;
      }

      // Initialize Supabase with fetched configuration
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );

      _client = Supabase.instance.client;
      print('Supabase client initialized successfully');
    } catch (e) {
      print('Error initializing Supabase client: $e');
    }
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
