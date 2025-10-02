import 'dart:math' as math;
import 'mapbox_service.dart';

// Simple coordinate class for Mapbox compatibility
class DirectionPoint {
  final double lat;
  final double lng;
  
  DirectionPoint(this.lat, this.lng);
}

class DirectionsService {
  /// Calculate distance using Mapbox Directions API (preferred) or straight-line distance (fallback)
  static Future<double> getDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String travelMode = 'DRIVING',
  }) async {
    // Use Mapbox Directions API for accurate road distance
    final mapboxDistance = await MapboxService.calculateDistance(
      startLat, startLng, endLat, endLng
    );
    
    if (mapboxDistance != null) {
      print('DirectionsService: Using Mapbox Directions distance: $mapboxDistance km');
      return mapboxDistance;
    }
    
    // Fallback to straight-line distance
    final straightLineDistance = _calculateDistance(startLat, startLng, endLat, endLng);
    print('DirectionsService: Using straight-line distance: $straightLineDistance km');
    return straightLineDistance;
  }

  /// Get route points for Mapbox integration
  static Future<List<DirectionPoint>> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String travelMode = 'DRIVING',
  }) async {
    // Use Mapbox route service
    final routePoints = await MapboxService.getRoute(startLat, startLng, endLat, endLng);
    
    if (routePoints != null && routePoints.isNotEmpty) {
      return routePoints
          .map((point) => DirectionPoint(point['lat']!, point['lng']!))
          .toList();
    }
    
    // Fallback to straight line if no route found
    return [
      DirectionPoint(startLat, startLng),
      DirectionPoint(endLat, endLng),
    ];
  }

  /// Get estimated duration in seconds (using average speed estimation since Mapbox doesn't provide duration in the current service)
  static Future<int> getDuration({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String travelMode = 'DRIVING',
  }) async {
    // Get the actual road distance from Mapbox
    final distance = await getDistance(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      travelMode: travelMode,
    );
    
    // Estimate duration based on road distance
    // Assume average speed of 30 km/h in Metro Manila traffic
    final estimatedHours = distance / 30.0; // 30 km/h average speed
    return (estimatedHours * 3600).round(); // Convert to seconds
  }

  /// Calculate straight-line distance between two points using the Haversine formula
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLng = (lng2 - lng1) * (math.pi / 180);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.pow(math.sin(dLng / 2), 2) * math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }
}