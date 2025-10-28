import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/env.dart';

/// Traffic congestion level
enum CongestionLevel {
  low,      // Green - free flowing traffic
  moderate, // Yellow - moderate congestion
  heavy,    // Orange - heavy congestion
  severe,   // Red - severe congestion
}

/// Traffic-aware route segment with congestion data
class TrafficSegment {
  final List<Map<String, double>> coordinates;
  final CongestionLevel congestion;
  final double distance; // meters
  final double duration; // seconds

  TrafficSegment({
    required this.coordinates,
    required this.congestion,
    required this.distance,
    required this.duration,
  });

  /// Get color for this segment based on congestion
  Color get color {
    switch (congestion) {
      case CongestionLevel.low:
        return const Color(0xFF34D399); // Green
      case CongestionLevel.moderate:
        return const Color(0xFFFBBF24); // Yellow
      case CongestionLevel.heavy:
        return const Color(0xFFFB923C); // Orange
      case CongestionLevel.severe:
        return const Color(0xFFEF4444); // Red
    }
  }
}

/// Matrix API route result with traffic data
class TrafficAwareRoute {
  final List<TrafficSegment> segments;
  final double totalDistance; // meters
  final double totalDuration; // seconds
  final String durationInTraffic; // human-readable (e.g., "15 min")
  final Map<String, double> trafficStats; // % of route in each congestion level

  TrafficAwareRoute({
    required this.segments,
    required this.totalDistance,
    required this.totalDuration,
    required this.durationInTraffic,
    required this.trafficStats,
  });

  /// Get all coordinates as a single list for polyline rendering
  List<Map<String, double>> get allCoordinates {
    return segments.expand((segment) => segment.coordinates).toList();
  }

  /// Get distance in kilometers
  double get distanceKm => totalDistance / 1000;

  /// Get duration in minutes
  double get durationMinutes => totalDuration / 60;

  /// Check if route has significant traffic
  bool get hasHeavyTraffic {
    final heavyPercent = trafficStats['heavy'] ?? 0.0;
    final severePercent = trafficStats['severe'] ?? 0.0;
    return (heavyPercent + severePercent) > 20.0; // More than 20% heavy/severe traffic
  }
}

/// Mapbox Matrix API Service for traffic-aware routing
/// Uses Matrix API to get real-time traffic data and accurate ETAs
/// Cost-effective: ~$0.005 per request = ~$1.50 per 1000 deliveries (2-3 calls per delivery)
class MapboxMatrixService {
  static String get _accessToken => Env.mapboxAccessToken;
  static const String _baseUrl = 'https://api.mapbox.com';

  /// Get traffic-aware route between two or more points
  /// Returns route with color-coded segments based on congestion levels
  /// 
  /// Usage:
  /// - Call #1: Location selection - route preview (pickup → delivery)
  /// - Call #2: Driver assignment - multi-leg route (driver → pickup → delivery)
  /// - Call #3: Pickup complete - direct route (driver → delivery)
  /// 
  /// Parameters:
  /// - [coordinates]: List of [lng, lat] pairs. First is origin, last is destination, middle are waypoints
  /// - [annotations]: Additional data to request (default: duration, distance, congestion)
  /// - [overview]: Route geometry detail level (default: full)
  static Future<TrafficAwareRoute?> getTrafficAwareRoute(
    List<List<double>> coordinates, {
    List<String> annotations = const ['duration', 'distance', 'congestion', 'congestion_numeric'],
    String overview = 'full',
  }) async {
    if (coordinates.length < 2) {
      debugPrint('❌ MapboxMatrixService: Need at least 2 coordinates for route');
      return null;
    }

    try {
      // Build coordinates string: lng1,lat1;lng2,lat2;...
      final coordString = coordinates
          .map((coord) => '${coord[0]},${coord[1]}')
          .join(';');

      // Build annotations string
      final annotationsString = annotations.join(',');

      // Build URL for Matrix API request
      final url = '$_baseUrl/directions/v5/mapbox/driving-traffic/$coordString?'
          'access_token=$_accessToken'
          '&annotations=$annotationsString'
          '&overview=$overview'
          '&geometries=geojson'
          '&steps=false'; // We don't need turn-by-turn steps

      debugPrint('🚦 ═══════════════════════════════════════════════');
      debugPrint('🚦 MAPBOX MATRIX API REQUEST');
      debugPrint('🚦 ═══════════════════════════════════════════════');
      debugPrint('🚦 Profile: driving-traffic (includes real-time traffic)');
      debugPrint('🚦 Waypoints: ${coordinates.length}');
      debugPrint('🚦 Coordinates: $coordString');
      debugPrint('🚦 Annotations: $annotationsString');

      final response = await http.get(Uri.parse(url));

      debugPrint('🚦 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('❌ Matrix API error: ${response.statusCode}');
        debugPrint('   Response: ${response.body}');
        debugPrint('🚦 ═══════════════════════════════════════════════');
        return null;
      }

      final data = json.decode(response.body);

      // Validate response structure
      if (data['routes'] == null || data['routes'].isEmpty) {
        debugPrint('❌ No routes found in response');
        debugPrint('🚦 ═══════════════════════════════════════════════');
        return null;
      }

      final route = data['routes'][0];
      
      // Extract route metadata
      final distance = (route['distance'] as num).toDouble(); // meters
      final duration = (route['duration'] as num).toDouble(); // seconds

      debugPrint('📊 Route metadata:');
      debugPrint('   - Distance: ${(distance / 1000).toStringAsFixed(2)} km');
      debugPrint('   - Duration: ${(duration / 60).toStringAsFixed(1)} min');

      // Extract geometry (polyline coordinates)
      final geometry = route['geometry'];
      if (geometry == null || geometry['coordinates'] == null) {
        debugPrint('❌ No geometry found in route');
        debugPrint('🚦 ═══════════════════════════════════════════════');
        return null;
      }

      final List<dynamic> geometryCoords = geometry['coordinates'];
      
      // Extract congestion data from annotations
      final legs = route['legs'] as List? ?? [];
      
      // Parse traffic segments from legs
      final segments = _parseTrafficSegments(legs, geometryCoords);

      if (segments.isEmpty) {
        debugPrint('⚠️ No traffic segments parsed, falling back to single segment');
        // Fallback: create single segment with unknown congestion
        segments.add(TrafficSegment(
          coordinates: geometryCoords.map<Map<String, double>>((coord) => {
            'lng': (coord[0] as num).toDouble(),
            'lat': (coord[1] as num).toDouble(),
          }).toList(),
          congestion: CongestionLevel.low,
          distance: distance,
          duration: duration,
        ));
      }

      // Calculate traffic statistics
      final trafficStats = _calculateTrafficStats(segments, distance);

      debugPrint('📊 Traffic breakdown:');
      debugPrint('   - Low (green): ${trafficStats['low']?.toStringAsFixed(1)}%');
      debugPrint('   - Moderate (yellow): ${trafficStats['moderate']?.toStringAsFixed(1)}%');
      debugPrint('   - Heavy (orange): ${trafficStats['heavy']?.toStringAsFixed(1)}%');
      debugPrint('   - Severe (red): ${trafficStats['severe']?.toStringAsFixed(1)}%');

      final result = TrafficAwareRoute(
        segments: segments,
        totalDistance: distance,
        totalDuration: duration,
        durationInTraffic: _formatDuration(duration),
        trafficStats: trafficStats,
      );

      debugPrint('✅ Traffic-aware route successfully parsed!');
      debugPrint('   - Segments: ${segments.length}');
      debugPrint('   - Total coordinates: ${result.allCoordinates.length}');
      debugPrint('   - Heavy traffic: ${result.hasHeavyTraffic ? "YES" : "NO"}');
      debugPrint('🚦 ═══════════════════════════════════════════════');

      return result;

    } catch (e, stackTrace) {
      debugPrint('❌ MapboxMatrixService error: $e');
      debugPrint('   Stack trace: $stackTrace');
      debugPrint('🚦 ═══════════════════════════════════════════════');
      return null;
    }
  }

  /// Parse traffic segments from route legs and congestion annotations
  static List<TrafficSegment> _parseTrafficSegments(
    List<dynamic> legs,
    List<dynamic> geometryCoords,
  ) {
    final List<TrafficSegment> segments = [];

    try {
      int coordIndex = 0;

      for (var leg in legs) {
        final annotation = leg['annotation'];
        if (annotation == null) continue;

        // Get congestion data
        final congestionData = annotation['congestion'] as List? ?? [];
        final congestionNumericData = annotation['congestion_numeric'] as List? ?? [];
        final distanceData = annotation['distance'] as List? ?? [];
        final durationData = annotation['duration'] as List? ?? [];

        debugPrint('📊 Leg has ${congestionData.length} congestion segments');
        if (congestionData.isNotEmpty) {
          debugPrint('   Sample congestion values: ${congestionData.take(5).join(", ")}');
        }
        if (congestionNumericData.isNotEmpty) {
          debugPrint('   Sample numeric values: ${congestionNumericData.take(5).join(", ")}');
        }

        // Each annotation point corresponds to a segment between two coordinates
        for (int i = 0; i < congestionData.length; i++) {
          if (coordIndex + 1 >= geometryCoords.length) break;

          // Get congestion level
          final congestionStr = congestionData[i] as String? ?? 'unknown';
          final congestionNumeric = i < congestionNumericData.length 
              ? (congestionNumericData[i] as num?)?.toInt() ?? 0
              : 0;
          
          final congestion = _parseCongestionLevel(congestionStr, congestionNumeric);

          // Get segment coordinates
          final segmentCoords = [
            {
              'lng': (geometryCoords[coordIndex][0] as num).toDouble(),
              'lat': (geometryCoords[coordIndex][1] as num).toDouble(),
            },
            {
              'lng': (geometryCoords[coordIndex + 1][0] as num).toDouble(),
              'lat': (geometryCoords[coordIndex + 1][1] as num).toDouble(),
            },
          ];

          // Get segment distance and duration
          final segmentDistance = i < distanceData.length 
              ? (distanceData[i] as num).toDouble()
              : 0.0;
          final segmentDuration = i < durationData.length
              ? (durationData[i] as num).toDouble()
              : 0.0;

          segments.add(TrafficSegment(
            coordinates: segmentCoords,
            congestion: congestion,
            distance: segmentDistance,
            duration: segmentDuration,
          ));

          coordIndex++;
        }
      }

      // If we have remaining coordinates, group them into final segment
      if (coordIndex < geometryCoords.length - 1) {
        final remainingCoords = geometryCoords
            .sublist(coordIndex)
            .map<Map<String, double>>((coord) => {
              'lng': (coord[0] as num).toDouble(),
              'lat': (coord[1] as num).toDouble(),
            })
            .toList();

        segments.add(TrafficSegment(
          coordinates: remainingCoords,
          congestion: CongestionLevel.low, // Default to low for remaining
          distance: 0.0,
          duration: 0.0,
        ));
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing traffic segments: $e');
    }

    return segments;
  }

  /// Parse congestion level from string and numeric values
  static CongestionLevel _parseCongestionLevel(String congestionStr, int? congestionNumeric) {
    // Mapbox congestion values:
    // - String: low, moderate, heavy, severe
    // - Numeric: 0-100 (traffic intensity)
    
    switch (congestionStr.toLowerCase()) {
      case 'low':
        return CongestionLevel.low;
      case 'moderate':
        return CongestionLevel.moderate;
      case 'heavy':
        return CongestionLevel.heavy;
      case 'severe':
        return CongestionLevel.severe;
      default:
        // Fallback to numeric if available
        if (congestionNumeric != null) {
          if (congestionNumeric < 25) return CongestionLevel.low;
          if (congestionNumeric < 50) return CongestionLevel.moderate;
          if (congestionNumeric < 75) return CongestionLevel.heavy;
          return CongestionLevel.severe;
        }
        return CongestionLevel.low; // Default to low
    }
  }

  /// Calculate traffic statistics (% of route in each congestion level)
  static Map<String, double> _calculateTrafficStats(
    List<TrafficSegment> segments,
    double totalDistance,
  ) {
    if (totalDistance == 0) {
      return {
        'low': 100.0,
        'moderate': 0.0,
        'heavy': 0.0,
        'severe': 0.0,
      };
    }

    double lowDistance = 0;
    double moderateDistance = 0;
    double heavyDistance = 0;
    double severeDistance = 0;

    for (var segment in segments) {
      switch (segment.congestion) {
        case CongestionLevel.low:
          lowDistance += segment.distance;
          break;
        case CongestionLevel.moderate:
          moderateDistance += segment.distance;
          break;
        case CongestionLevel.heavy:
          heavyDistance += segment.distance;
          break;
        case CongestionLevel.severe:
          severeDistance += segment.distance;
          break;
      }
    }

    return {
      'low': (lowDistance / totalDistance) * 100,
      'moderate': (moderateDistance / totalDistance) * 100,
      'heavy': (heavyDistance / totalDistance) * 100,
      'severe': (severeDistance / totalDistance) * 100,
    };
  }

  /// Format duration into human-readable string
  static String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours hr';
      }
      return '$hours hr $remainingMinutes min';
    }
  }

  /// Calculate client-side ETA using driver's actual GPS speed
  /// This is used BETWEEN Matrix API calls to show real-time ETA updates
  /// No API cost - uses driver's actual speed from GPS
  /// 
  /// Parameters:
  /// - [remainingDistanceMeters]: Distance left to destination
  /// - [driverSpeedMps]: Driver's actual speed in meters per second from GPS
  /// - [fallbackDurationSeconds]: Fallback duration if speed is 0 or invalid
  static String calculateClientSideETA({
    required double remainingDistanceMeters,
    required double driverSpeedMps,
    double? fallbackDurationSeconds,
  }) {
    // If driver is not moving or speed is invalid, use fallback
    if (driverSpeedMps <= 0 || driverSpeedMps.isNaN || driverSpeedMps.isInfinite) {
      if (fallbackDurationSeconds != null) {
        return _formatDuration(fallbackDurationSeconds);
      }
      return 'Calculating...';
    }

    // Calculate ETA: time = distance / speed
    final etaSeconds = remainingDistanceMeters / driverSpeedMps;

    // Sanity check: cap at reasonable maximum (4 hours)
    if (etaSeconds > 14400) {
      return _formatDuration(fallbackDurationSeconds ?? 3600); // Default to 1 hour
    }

    return _formatDuration(etaSeconds);
  }

  /// Get distance remaining from current driver position to destination
  /// This is a helper for client-side ETA calculations
  /// Uses simple Haversine formula (good enough for short distances)
  static double getDistanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    const double earthRadius = 6371000; // Earth's radius in meters
    final double dLat = _toRadians(toLat - fromLat);
    final double dLng = _toRadians(toLng - fromLng);
    
    final double a = 
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(fromLat)) * cos(_toRadians(toLat)) *
         sin(dLng / 2) * sin(dLng / 2));
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }
}
