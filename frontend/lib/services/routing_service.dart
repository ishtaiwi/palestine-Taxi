import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';

/// Service for fetching driving routes using OSRM (Open Source Routing Machine)
/// Uses backend proxy to avoid CORS issues on web
class RoutingService {
  /// Get a driving route between multiple waypoints
  /// Returns the route geometry as a list of LatLng points and total distance in meters
  static Future<RouteResult?> getRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      return null;
    }

    try {
      // Use backend proxy to avoid CORS issues
      final waypointsData = waypoints
          .map((wp) => {'lat': wp.latitude, 'lng': wp.longitude})
          .toList();

      final url = Uri.parse('${AppConfig.apiBaseUrl}/routing/route');
      
      debugPrint('Fetching route from: $url');
      debugPrint('Waypoints: $waypointsData');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'waypoints': waypointsData}),
      ).timeout(
        const Duration(seconds: 15),
      );

      debugPrint('Route response status: ${response.statusCode}');
      debugPrint('Route response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['route'] != null) {
          final route = data['route'];
          final geometry = route['geometry'] as String;
          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();

          // Decode the polyline
          final routePoints = decodePolyline(geometry);
          
          debugPrint('Route decoded: ${routePoints.length} points, ${distance}m, ${duration}s');

          return RouteResult(
            points: routePoints,
            distance: distance,
            duration: duration,
            encodedPolyline: geometry,
          );
        }
      }

      debugPrint('Route request failed or returned no data');
      return null;
    } catch (e) {
      debugPrint('Error fetching route: $e');
      return null;
    }
  }

  /// Decode a polyline string into a list of LatLng points
  /// Uses the Polyline Algorithm: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    double lat = 0;
    double lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      // Proper zigzag decoding for signed integers
      double deltaLat = ((result & 1) == 1 ? -(result >> 1) - 1 : (result >> 1)).toDouble();
      lat += deltaLat;

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      double deltaLng = ((result & 1) == 1 ? -(result >> 1) - 1 : (result >> 1)).toDouble();
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Encode a list of LatLng points into a polyline string
  static String encodePolyline(List<LatLng> points) {
    if (points.isEmpty) return '';

    final StringBuffer encoded = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (final point in points) {
      int lat = (point.latitude * 1e5).round();
      int lng = (point.longitude * 1e5).round();

      _encodeValue(lat - prevLat, encoded);
      _encodeValue(lng - prevLng, encoded);

      prevLat = lat;
      prevLng = lng;
    }

    return encoded.toString();
  }

  static void _encodeValue(int value, StringBuffer encoded) {
    int v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      encoded.writeCharCode((0x20 | (v & 0x1F)) + 63);
      v >>= 5;
    }
    encoded.writeCharCode(v + 63);
  }
}

/// Result of a route calculation
class RouteResult {
  final List<LatLng> points;
  final double distance; // in meters
  final double duration; // in seconds
  final String encodedPolyline;

  RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    required this.encodedPolyline,
  });
}

