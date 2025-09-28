import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:mapbox_gl/mapbox_gl.dart' as mbx;
import '../config/env.dart';

class MapboxRouteResult {
  final List<mbx.LatLng> points;
  final double distanceKm; // total distance
  MapboxRouteResult({required this.points, required this.distanceKm});
}

class MapboxGeocodeSuggestion {
  final String placeName;
  final double latitude;
  final double longitude;
  MapboxGeocodeSuggestion({
    required this.placeName,
    required this.latitude,
    required this.longitude,
  });
}

class MapboxService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.mapbox.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static String get _token => Env.mapboxAccessToken;

  // Driving route using Mapbox Directions API
  static Future<MapboxRouteResult?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_token.isEmpty) return null;
    final coords = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    try {
      final resp = await _dio.get(
        '/directions/v5/mapbox/driving/$coords',
        queryParameters: {
          'alternatives': 'false',
          'geometries': 'geojson',
          'overview': 'full',
          'steps': 'false',
          'access_token': _token,
        },
      );
      final data = resp.data;
      if (data == null || data['routes'] == null || (data['routes'] as List).isEmpty) {
        return null;
      }
      final route = data['routes'][0];
      final geometry = route['geometry'];
      final coordsList = (geometry['coordinates'] as List?)?.cast<List?>() ?? [];
      final points = <mbx.LatLng>[];
      for (final c in coordsList) {
        if (c == null || c.length < 2) continue;
        final lon = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        points.add(mbx.LatLng(lat, lon));
      }
      final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
      return MapboxRouteResult(points: points, distanceKm: distanceMeters / 1000.0);
    } catch (_) {
      return null;
    }
  }

  // Forward geocoding for search
  static Future<List<MapboxGeocodeSuggestion>> forwardGeocode(String query, {int limit = 5}) async {
    if (_token.isEmpty || query.trim().isEmpty) return [];
    try {
      final resp = await _dio.get(
        '/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json',
        queryParameters: {
          'access_token': _token,
          'autocomplete': 'true',
          'limit': '$limit',
        },
      );
      final data = resp.data;
      final features = (data['features'] as List?) ?? [];
      return features.map((f) {
        final center = (f['center'] as List?) ?? [];
        final lon = (center.isNotEmpty ? (center[0] as num?)?.toDouble() : null) ?? 0.0;
        final lat = (center.length > 1 ? (center[1] as num?)?.toDouble() : null) ?? 0.0;
        return MapboxGeocodeSuggestion(
          placeName: f['place_name'] ?? '',
          latitude: lat,
          longitude: lon,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Reverse geocoding to get address text from lat/lng
  static Future<String?> reverseGeocode({required double latitude, required double longitude}) async {
    if (_token.isEmpty) return null;
    try {
      final resp = await _dio.get(
        '/geocoding/v5/mapbox.places/$longitude,$latitude.json',
        queryParameters: {
          'access_token': _token,
          'limit': '1',
        },
      );
      final data = resp.data;
      final features = (data['features'] as List?) ?? [];
      if (features.isEmpty) return null;
      return features.first['place_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
