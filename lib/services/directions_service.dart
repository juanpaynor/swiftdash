import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/env.dart';

class DirectionsService {
  static String get _apiKey {
    final k = Env.googleMapsApiKey;
    if (k.isNotEmpty) return k;
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  }
  
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  /// Get directions between two points with polyline and distance info
  static Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'DRIVING',
  }) async {
    if (_apiKey.isEmpty) {
      print('DirectionsService: Google Maps API key not found');
      throw Exception('Google Maps API key not found');
    }

    final String url = '$_baseUrl?'
        'origin=${origin.latitude},${origin.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        'mode=${travelMode.toLowerCase()}&'
        'key=$_apiKey';

    try {
      print('DirectionsService: Making request to: ${url.replaceAll(_apiKey, 'API_KEY_HIDDEN')}');
      final response = await http.get(Uri.parse(url));
      
      print('DirectionsService: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        print('DirectionsService: API status: ${data['status']}');
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final result = DirectionsResult.fromMap(data);
          if (result.polylinePoints.isNotEmpty) {
            final first = result.polylinePoints.first;
            final last = result.polylinePoints.last;
            print('DirectionsService: Parsed ${result.polylinePoints.length} polyline points');
            print('DirectionsService: First point: ${first.latitude}, ${first.longitude} | Last point: ${last.latitude}, ${last.longitude}');
          }
          return result;
        } else {
          print('DirectionsService: API returned status: ${data['status']} with error: ${data['error_message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        print('DirectionsService: HTTP error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('DirectionsService: Exception occurred: $e');
      return null;
    }
  }

  /// Decode Google polyline string to list of LatLng points
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

class DirectionsResult {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationMinutes;
  final String distanceText;
  final String durationText;
  final LatLngBounds bounds;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
    required this.distanceText,
    required this.durationText,
    required this.bounds,
  });

  factory DirectionsResult.fromMap(Map<String, dynamic> map) {
    final route = map['routes'][0];
    final leg = route['legs'][0];
    
    // Extract polyline points: prefer detailed step-level points when available.
    List<LatLng> overviewPoints = [];
    try {
      final polylineEncoded = route['overview_polyline']?['points'];
      if (polylineEncoded is String && polylineEncoded.isNotEmpty) {
        overviewPoints = DirectionsService.decodePolyline(polylineEncoded);
      }
    } catch (_) {}

    final steps = (leg['steps'] as List?) ?? const [];
    final List<LatLng> stepPoints = <LatLng>[];
    for (final s in steps) {
      final sp = s['polyline']?['points'];
      if (sp is String && sp.isNotEmpty) {
        stepPoints.addAll(DirectionsService.decodePolyline(sp));
      }
    }

    // Choose the best set of points
    List<LatLng> polylinePoints = stepPoints.length >= 2 ? stepPoints : overviewPoints;

    // Defensive: if points look degenerate (all same lat or all same lng), fall back to overview
    bool isDegenerate(List<LatLng> pts) {
      if (pts.length < 2) return true;
      double minLat = pts.first.latitude, maxLat = pts.first.latitude;
      double minLng = pts.first.longitude, maxLng = pts.first.longitude;
      for (final p in pts) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      return (maxLat - minLat).abs() < 1e-6 || (maxLng - minLng).abs() < 1e-6;
    }

    if (isDegenerate(polylinePoints) && !isDegenerate(overviewPoints)) {
      polylinePoints = overviewPoints;
    }
    // Final safety: if still degenerate, clear to let UI fall back to straight line
    if (isDegenerate(polylinePoints)) {
      print('DirectionsService: Degenerate polyline detected, returning empty points to allow fallback');
      polylinePoints = [];
    }
    
    // Extract distance and duration
    final distanceValue = leg['distance']['value'] as int; // in meters
    final distanceText = leg['distance']['text'] as String;
    final durationValue = leg['duration']['value'] as int; // in seconds
    final durationText = leg['duration']['text'] as String;
    
    // Extract bounds
    final northeast = route['bounds']['northeast'];
    final southwest = route['bounds']['southwest'];
    final bounds = LatLngBounds(
      northeast: LatLng(northeast['lat'], northeast['lng']),
      southwest: LatLng(southwest['lat'], southwest['lng']),
    );

    return DirectionsResult(
      polylinePoints: polylinePoints,
      distanceKm: distanceValue / 1000.0, // convert to kilometers
      durationMinutes: (durationValue / 60).round(), // convert to minutes
      distanceText: distanceText,
      durationText: durationText,
      bounds: bounds,
    );
  }

  /// Calculate estimated price based on distance and base rates
  double calculatePrice({
    required double basePrice,
    required double pricePerKm,
  }) {
    return basePrice + (distanceKm * pricePerKm);
  }
}