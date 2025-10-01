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

  /// Get autocomplete suggestions for an address (Philippines only) - Hybrid approach for speed + accuracy
  static Future<List<MapboxGeocodeSuggestion>> getAddressSuggestions(String query) async {
    if (query.length < 2) return [];
    
    print('MapboxService: Searching for "$query"');
    
    try {
      // Use Search Box API for accuracy, but optimize for speed with parallel processing
      final suggestUri = Uri.parse('https://api.mapbox.com/search/searchbox/v1/suggest')
          .replace(queryParameters: {
        'q': query,
        'access_token': _accessToken,
        'session_token': 'fast_session_${DateTime.now().millisecondsSinceEpoch}',
        'language': 'en',
        'limit': '4', // Reduced to 4 for speed
        'country': 'PH',
        'proximity': '121.0581,14.5995', // Metro Manila center
        'types': 'poi,address', // Focus on POIs and addresses
        'bbox': '120.9,14.2,121.2,14.8', // Metro Manila bounding box
      });
      
      final suggestResponse = await http.get(suggestUri);
      
      print('MapboxService: Search Box API response: ${suggestResponse.statusCode}');
      
      if (suggestResponse.statusCode != 200) {
        print('MapboxService: Search Box API error: ${suggestResponse.statusCode}');
        return [];
      }
      
      final suggestData = json.decode(suggestResponse.body);
      final suggestions = suggestData['suggestions'] as List? ?? [];
      
      print('MapboxService: Found ${suggestions.length} suggestions');
      
      if (suggestions.isEmpty) {
        print('MapboxService: No suggestions found');
        return [];
      }
      
      // OPTIMIZATION: Process all retrieve calls in parallel instead of sequential
      List<Future<MapboxGeocodeSuggestion?>> futures = [];
      
      for (var suggestion in suggestions) {
        final mapboxId = suggestion['mapbox_id'] as String?;
        final name = suggestion['name'] as String? ?? '';
        final fullAddress = suggestion['full_address'] as String? ?? name;
        
        if (mapboxId != null && mapboxId.isNotEmpty) {
          // Create future for parallel processing
          futures.add(_retrieveSuggestionDetails(mapboxId, name, fullAddress, query));
        }
      }
      
      // Wait for all retrieve calls to complete in parallel (MUCH faster!)
      final results = await Future.wait(futures);
      
      // Filter out null results and return
      final validResults = results.where((result) => result != null).cast<MapboxGeocodeSuggestion>().toList();
      
      print('MapboxService: Returning ${validResults.length} results');
      return validResults;
      
    } catch (e) {
      print('MapboxService: Search error: $e');
      return [];
    }
  }
  
  /// Helper method to retrieve individual suggestion details (for parallel processing)
  static Future<MapboxGeocodeSuggestion?> _retrieveSuggestionDetails(String mapboxId, String name, String fullAddress, String originalQuery) async {
    try {
      final retrieveUri = Uri.parse('https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId')
          .replace(queryParameters: {
        'session_token': 'fast_retrieve_${DateTime.now().millisecondsSinceEpoch}',
        'access_token': _accessToken,
      });
      
      final retrieveResponse = await http.get(retrieveUri);
      
      if (retrieveResponse.statusCode == 200) {
        final retrieveData = json.decode(retrieveResponse.body);
        final features = retrieveData['features'] as List? ?? [];
        
        if (features.isNotEmpty) {
          final feature = features.first;
          final geometry = feature['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List?;
          final properties = feature['properties'] as Map<String, dynamic>?;
          
          if (coordinates != null && coordinates.length >= 2 && properties != null) {
            final detailedName = properties['name'] as String? ?? name;
            final detailedAddress = properties['full_address'] as String? ?? fullAddress;
            
            // Smart display name selection - prioritize names that match the search
            String displayName;
            if (detailedName.isNotEmpty && detailedName.toLowerCase().contains(originalQuery.toLowerCase())) {
              displayName = detailedName;
            } else if (detailedAddress.isNotEmpty) {
              displayName = detailedAddress;
            } else {
              displayName = detailedName.isNotEmpty ? detailedName : name;
            }
            
            print('MapboxService: Retrieved: "$displayName"');
            
            return MapboxGeocodeSuggestion(
              displayName: displayName,
              latitude: coordinates[1].toDouble(),
              longitude: coordinates[0].toDouble(),
            );
          }
        }
      } else {
        print('MapboxService: Retrieve error for $mapboxId: ${retrieveResponse.statusCode}');
      }
    } catch (e) {
      print('MapboxService: Retrieve exception for $mapboxId: $e');
    }
    
    return null;
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

  /// Get route between two points (Philippines only)
  static Future<List<Map<String, double>>?> getRoute(double startLat, double startLng, double endLat, double endLng) async {
    try {
      final url = '$_baseUrl/directions/v5/mapbox/driving/$startLng,$startLat;$endLng,$endLat?access_token=$_accessToken&geometries=geojson&overview=full';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          if (geometry != null && geometry['coordinates'] != null) {
            final List<dynamic> coordinates = geometry['coordinates'];
            return coordinates.map<Map<String, double>>((coord) => {
              'lng': coord[0].toDouble(),
              'lat': coord[1].toDouble(),
            }).toList();
          }
        }
      }
      return null;
    } catch (e) {
      print('Route error: $e');
      return null;
    }
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