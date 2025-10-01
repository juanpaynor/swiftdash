import 'dart:convert';
import 'package:http/http.dart' as http;

class MapboxService {
  static const String _accessToken = 'pk.eyJ1Ijoic3dpZnRkYXNoIiwiYSI6ImNtZzNiazczczEzZmQycnIwdno1Z2NtYW0ifQ.9zBJVXVCBLU3eN1jZQTJUA';
  static const String _baseUrl = 'https://api.mapbox.com';
  
  // Metro Manila center coordinates (for proximity and default map center)
  static const double metroManilaLat = 14.5995;
  static const double metroManilaLng = 121.0244;

  /// Geocode an address to get coordinates (Philippines only)
  static Future<MapboxGeocodeSuggestion?> geocodeAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      // Restrict search to Philippines using country code and bounding box
      final url = '$_baseUrl/geocoding/v5/mapbox.places/$encodedAddress.json?access_token=$_accessToken&limit=1&country=PH&bbox=116.9283,4.5693,126.6043,21.1210';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          final feature = features.first;
          final coordinates = feature['geometry']['coordinates'] as List;
          final placeName = feature['place_name'] as String;
          
          return MapboxGeocodeSuggestion(
            displayName: placeName,
            latitude: coordinates[1].toDouble(),
            longitude: coordinates[0].toDouble(),
          );
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  /// Reverse geocode coordinates to get an address (Philippines only)
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      // Add country restriction to Philippines
      final url = '$_baseUrl/geocoding/v5/mapbox.places/$longitude,$latitude.json?access_token=$_accessToken&limit=1&country=PH';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          return features.first['place_name'] as String;
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }
    return null;
  }

  /// Get autocomplete suggestions for an address (Philippines only)
  static Future<List<MapboxGeocodeSuggestion>> getAddressSuggestions(String query) async {
    if (query.length < 3) return [];
    
    try {
      final encodedQuery = Uri.encodeComponent(query);
      // Restrict search to Philippines with country code, bounding box, and proximity to Metro Manila
      final url = '$_baseUrl/geocoding/v5/mapbox.places/$encodedQuery.json?access_token=$_accessToken&limit=5&types=address,poi&country=PH&bbox=116.9283,4.5693,126.6043,21.1210&proximity=121.0244,14.5995';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        return features.map((feature) {
          final coordinates = feature['geometry']['coordinates'] as List;
          return MapboxGeocodeSuggestion(
            displayName: feature['place_name'] as String,
            latitude: coordinates[1].toDouble(),
            longitude: coordinates[0].toDouble(),
          );
        }).toList();
      }
    } catch (e) {
      print('Address suggestions error: $e');
    }
    return [];
  }

  /// Calculate distance between two points using Mapbox Directions API
  static Future<double?> calculateDistance(
    double fromLat, double fromLng,
    double toLat, double toLng,
  ) async {
    try {
      final url = '$_baseUrl/directions/v5/mapbox/driving/$fromLng,$fromLat;$toLng,$toLat?access_token=$_accessToken&geometries=geojson';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        
        if (routes.isNotEmpty) {
          final distance = routes.first['distance'] as num;
          return distance.toDouble() / 1000; // Convert meters to kilometers
        }
      }
    } catch (e) {
      print('Distance calculation error: $e');
    }
    return null;
  }
}

class MapboxGeocodeSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;

  MapboxGeocodeSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}