import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'api_service.dart';

class NavigationService {
  /// Navigate to base station using device's default maps app
  static Future<bool> navigateToBaseStation({
    required double latitude,
    required double longitude,
    String? name,
  }) async {
    try {
      // Try Google Maps first
      final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude${name != null ? '&destination_place_id=$name' : ''}',
      );

      if (await canLaunchUrl(googleMapsUrl)) {
        return await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }

      // Fallback to generic maps URL
      final mapsUrl = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude${name != null ? '($name)' : ''}');
      if (await canLaunchUrl(mapsUrl)) {
        return await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      }

      return false;
    } catch (e) {
      print('Error launching navigation: $e');
      return false;
    }
  }

  /// Navigate along line path using waypoints
  /// For offline support, we'll cache the path and use it even when offline
  static Future<bool> navigateAlongLinePath({
    required String lineid,
    List<Map<String, dynamic>>? waypoints,
  }) async {
    try {
      // If waypoints not provided, fetch from API or cache
      if (waypoints == null || waypoints.isEmpty) {
        waypoints = await _getLinePathWaypoints(lineid);
      }

      if (waypoints == null || waypoints.isEmpty) {
        return false;
      }

      // Cache the path for offline use
      await _cacheLinePath(lineid, waypoints);

      // Build navigation URL with waypoints
      if (waypoints.length == 1) {
        // Single destination
        final waypoint = waypoints[0];
        return await navigateToBaseStation(
          latitude: waypoint['lat']?.toDouble() ?? waypoint['latitude']?.toDouble() ?? 0.0,
          longitude: waypoint['lng']?.toDouble() ?? waypoint['longitude']?.toDouble() ?? 0.0,
          name: waypoint['name']?.toString(),
        );
      } else {
        // Multiple waypoints - use Google Maps with waypoints
        final waypointsStr = waypoints
            .map((wp) => '${wp['lat']?.toDouble() ?? wp['latitude']?.toDouble()},${wp['lng']?.toDouble() ?? wp['longitude']?.toDouble()}')
            .join('/');

                        final googleMapsUrl = Uri.parse(
                          'https://www.google.com/maps/dir/$waypointsStr',
                        );

        if (await canLaunchUrl(googleMapsUrl)) {
          return await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
        }
      }

      return false;
    } catch (e) {
      print('Error navigating along line path: $e');
      // Try offline cached path
      return await _navigateFromCache(lineid);
    }
  }

  /// Get line path waypoints from API or cache
  static Future<List<Map<String, dynamic>>?> _getLinePathWaypoints(String lineid) async {
    try {
      // Try API first
      final result = await ApiService.getLinePath(lineid);
      if (result['success'] == true && result['path'] != null) {
        final path = result['path'] as Map<String, dynamic>;
        if (path['waypoints'] != null) {
          final waypoints = (path['waypoints'] as List)
              .map((wp) => Map<String, dynamic>.from(wp))
              .toList();
          // Cache it
          await _cacheLinePath(lineid, waypoints);
          return waypoints;
        }
      }
    } catch (e) {
      print('Error fetching line path from API: $e');
    }

    // Try cache
    return await _getCachedLinePath(lineid);
  }

  /// Cache line path for offline use
  static Future<void> _cacheLinePath(
    String lineid,
    List<Map<String, dynamic>> waypoints,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'line_path_$lineid',
        jsonEncode(waypoints),
      );
    } catch (e) {
      print('Error caching line path: $e');
    }
  }

  /// Get cached line path
  static Future<List<Map<String, dynamic>>?> _getCachedLinePath(String lineid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('line_path_$lineid');
      if (cached != null) {
        final decoded = jsonDecode(cached) as List;
        return decoded.map((wp) => Map<String, dynamic>.from(wp)).toList();
      }
    } catch (e) {
      print('Error getting cached line path: $e');
    }
    return null;
  }

  /// Navigate using cached path (offline)
  static Future<bool> _navigateFromCache(String lineid) async {
    final waypoints = await _getCachedLinePath(lineid);
    if (waypoints == null || waypoints.isEmpty) {
      return false;
    }

    return await navigateAlongLinePath(
      lineid: lineid,
      waypoints: waypoints,
    );
  }

  /// Calculate distance to base station
  static double calculateDistanceToBaseStation({
    required double currentLat,
    required double currentLng,
    required double stationLat,
    required double stationLng,
  }) {
    // Use Haversine formula (same as backend)
    const double earthRadius = 6371000; // meters

    final dLat = _toRadians(stationLat - currentLat);
    final dLng = _toRadians(stationLng - currentLng);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(currentLat)) *
            math.cos(_toRadians(stationLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

