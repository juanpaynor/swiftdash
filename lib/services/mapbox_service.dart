import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../config/env.dart';

class MapboxService {
  // SECURE: Access token loaded from environment variables
  static String get _accessToken => Env.mapboxAccessToken;
  static const String _baseUrl = 'https://api.mapbox.com';
  
  // Metro Manila center coordinates (for proximity and default map center)
  static const double metroManilaLat = 14.5995;
  static const double metroManilaLng = 121.0244;

  // OPTIMIZATION: Add caching to drastically reduce API calls
  static final Map<String, List<MapboxGeocodeSuggestion>> _searchCache = {};
  static final Map<String, String?> _reverseGeocodeCache = {};
  static const int _cacheMaxSize = 100; // Limit cache size
  static const Duration _cacheExpiry = Duration(hours: 24); // Cache for 24 hours
  static final Map<String, DateTime> _cacheTimestamps = {};

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

  /// Reverse geocode coordinates to get an address (Philippines only) - OPTIMIZED: With caching
  static Future<String?> reverseGeocode(double latitude, double longitude) async {
    // OPTIMIZATION: Check cache first
    final cacheKey = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_reverseGeocodeCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        print('MapboxService: Returning cached reverse geocode result');
        return _reverseGeocodeCache[cacheKey];
      }
    }
    
    try {
      // Add country restriction to Philippines
      final url = '$_baseUrl/geocoding/v5/mapbox.places/$longitude,$latitude.json?access_token=$_accessToken&limit=1&country=PH';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          final result = features.first['place_name'] as String;
          
          // Cache the result
          _reverseGeocodeCache[cacheKey] = result;
          _cacheTimestamps[cacheKey] = DateTime.now();
          
          return result;
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }
    return null;
  }

  /// Get autocomplete suggestions for an address (Philippines only) - ENHANCED: Improved search algorithm
  static Future<List<MapboxGeocodeSuggestion>> getAddressSuggestions(String query) async {
    if (query.length < 2) return [];
    
    // IMPROVED: Clean and normalize the query
    final cleanedQuery = _cleanSearchQuery(query);
    if (cleanedQuery.isEmpty) return [];
    
    // OPTIMIZATION: Check cache first to avoid API calls
    final cacheKey = cleanedQuery.toLowerCase().trim();
    if (_searchCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        print('MapboxService: Returning cached results for "$query"');
        return _searchCache[cacheKey]!;
      } else {
        // Remove expired cache entry
        _searchCache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
      }
    }
    
    print('MapboxService: Searching for "$query" using DELIVERY-GRADE Mapbox Geocoding API');
    
    try {
      final encodedQuery = Uri.encodeComponent(cleanedQuery);  // IMPROVED: Use cleaned query
      
      // ENHANCED SEARCH: Use Mapbox Geocoding API with DELIVERY-GRADE precision parameters
      final url = '$_baseUrl/geocoding/v5/mapbox.places/$encodedQuery.json?'
          'access_token=$_accessToken'
          '&limit=10'  // DELIVERY: More results for better options
          '&country=PH'
          '&proximity=$metroManilaLng,$metroManilaLat'
          '&types=address,poi'  // DELIVERY: Focus on exact addresses and POIs
          '&bbox=116.9283,4.5693,126.6043,21.1210'  // Philippines bounding box
          '&autocomplete=true'  // Enable autocomplete for partial matches
          '&fuzzyMatch=true'  // Enable fuzzy matching for typos
          '&language=en'  // Ensure English results
          '&worldview=us'  // Consistent worldview
          '&routing=true'  // DELIVERY: Include routing-optimized data
          '&permanent=true';  // DELIVERY: Get permanent location identifiers
      
      final response = await http.get(Uri.parse(url));
      
      print('MapboxService: Geocoding API response: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('MapboxService: Geocoding API error: ${response.statusCode}');
        return [];
      }
      
      final data = json.decode(response.body);
      final features = data['features'] as List? ?? [];
      
      print('MapboxService: Found ${features.length} features');
      
      List<MapboxGeocodeSuggestion> suggestions = [];
      Set<String> seenAddresses = {}; // IMPROVED: Prevent duplicate results
      
      for (var feature in features) {
        try {
          final coordinates = feature['geometry']['coordinates'] as List;
          final placeName = feature['place_name'] as String;
          final featureType = feature['place_type'] as List? ?? [];
          final relevance = feature['relevance'] as double? ?? 0.0;
          
          // IMPROVED: Skip low relevance results (below 0.4)
          if (relevance < 0.4) continue;
          
          // IMPROVED: Skip duplicate addresses
          if (seenAddresses.contains(placeName.toLowerCase())) continue;
          seenAddresses.add(placeName.toLowerCase());
          
          // IMPROVED: Calculate distance from Metro Manila for ranking
          final lat = coordinates[1].toDouble();
          final lng = coordinates[0].toDouble();
          final distanceFromManila = _calculateDistance(metroManilaLat, metroManilaLng, lat, lng);
          
          suggestions.add(MapboxGeocodeSuggestion(
            displayName: placeName,
            latitude: lat,
            longitude: lng,
            relevance: relevance,
            distanceFromCenter: distanceFromManila,
            types: featureType.cast<String>(),
          ));
        } catch (e) {
          print('MapboxService: Error parsing feature: $e');
          continue;
        }
      }
      
      // IMPROVED: Sort results by relevance and distance
      suggestions.sort((a, b) {
        // First, prioritize by relevance (higher is better)
        final relevanceDiff = (b.relevance ?? 0.0).compareTo(a.relevance ?? 0.0);
        if (relevanceDiff != 0) return relevanceDiff;
        
        // Then by distance from Manila (closer is better)
        return (a.distanceFromCenter ?? double.infinity)
            .compareTo(b.distanceFromCenter ?? double.infinity);
      });
      
      // OPTIMIZATION: Cache the results to avoid future API calls
      _cacheResults(cacheKey, suggestions);
      
      print('MapboxService: Returning ${suggestions.length} results (cached for future use)');
      return suggestions;
      
    } catch (e) {
      print('MapboxService: Search error: $e');
      return [];
    }
  }

  /// Cache management helper
  static void _cacheResults(String key, List<MapboxGeocodeSuggestion> results) {
    // Limit cache size to prevent memory issues
    if (_searchCache.length >= _cacheMaxSize) {
      final oldestKey = _cacheTimestamps.keys.first;
      _searchCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
    
    _searchCache[key] = results;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// IMPROVED: Calculate distance between two coordinates using Haversine formula
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLng = (lng2 - lng1) * (math.pi / 180);
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180)) * math.cos(lat2 * (math.pi / 180)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c; // Distance in kilometers
  }

  /// IMPROVED: Clean and normalize search query for better results
  static String _cleanSearchQuery(String query) {
    // Remove extra whitespace and special characters
    String cleaned = query.trim()
        .replaceAll(RegExp(r'\s+'), ' ')  // Multiple spaces to single space
        .replaceAll(RegExp(r'[^\w\s,.-]'), '');  // Remove special chars except common ones
    
    // Common abbreviations and corrections for Philippines
    cleaned = cleaned
        .replaceAllMapped(RegExp(r'\bst\b', caseSensitive: false), (match) => 'Street')
        .replaceAllMapped(RegExp(r'\bave\b', caseSensitive: false), (match) => 'Avenue')
        .replaceAllMapped(RegExp(r'\bblvd\b', caseSensitive: false), (match) => 'Boulevard')
        .replaceAllMapped(RegExp(r'\brd\b', caseSensitive: false), (match) => 'Road')
        .replaceAllMapped(RegExp(r'\bbrgy\b', caseSensitive: false), (match) => 'Barangay')
        .replaceAllMapped(RegExp(r'\bcity\b', caseSensitive: false), (match) => 'City');
    
    return cleaned;
  }

  /// Get exact address details for delivery (with precise coordinates and address components)
  static Future<MapboxDeliveryAddress?> getExactDeliveryAddress(double latitude, double longitude) async {
    try {
      // Use precise reverse geocoding with delivery-specific parameters
      final url = '$_baseUrl/geocoding/v5/mapbox.places/$longitude,$latitude.json?'
          'access_token=$_accessToken'
          '&limit=1'
          '&country=PH'
          '&types=address,poi'  // Focus on addresses and POIs
          '&routing=true'  // Include routing data for delivery optimization
          '&permanent=true';  // Get permanent identifiers
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        if (features.isNotEmpty) {
          final feature = features.first;
          final coordinates = feature['geometry']['coordinates'] as List;
          final placeName = feature['place_name'] as String;
          final context = feature['context'] as List? ?? [];
          
          // Extract detailed address components for delivery
          String? houseNumber;
          String? street;
          String? barangay;
          String? city;
          String? province;
          String? postalCode;
          
          // Parse address components from context
          for (var contextItem in context) {
            final id = contextItem['id'] as String;
            final text = contextItem['text'] as String;
            
            if (id.startsWith('postcode')) {
              postalCode = text;
            } else if (id.startsWith('place')) {
              city = text;
            } else if (id.startsWith('locality')) {
              barangay = text;
            } else if (id.startsWith('region')) {
              province = text;
            }
          }
          
          // Try to extract street and house number from the place name
          final addressParts = placeName.split(',');
          if (addressParts.isNotEmpty) {
            final firstPart = addressParts.first.trim();
            // Simple heuristic to separate house number from street
            final parts = firstPart.split(' ');
            if (parts.length > 1 && RegExp(r'^\d+').hasMatch(parts.first)) {
              houseNumber = parts.first;
              street = parts.skip(1).join(' ');
            } else {
              street = firstPart;
            }
          }
          
          return MapboxDeliveryAddress(
            fullAddress: placeName,
            latitude: coordinates[1].toDouble(),
            longitude: coordinates[0].toDouble(),
            houseNumber: houseNumber,
            street: street,
            barangay: barangay,
            city: city,
            province: province,
            postalCode: postalCode,
          );
        }
      }
    } catch (e) {
      print('Exact delivery address error: $e');
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
  final double? relevance; // IMPROVED: Search relevance score
  final double? distanceFromCenter; // IMPROVED: Distance from Metro Manila
  final List<String>? types; // IMPROVED: Feature types (poi, address, etc.)

  MapboxGeocodeSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.relevance,
    this.distanceFromCenter,
    this.types,
  });
}

/// Enhanced delivery address model with detailed components for precise delivery
class MapboxDeliveryAddress {
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String? houseNumber;
  final String? street;
  final String? barangay;
  final String? city;
  final String? province;
  final String? postalCode;

  MapboxDeliveryAddress({
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.street,
    this.barangay,
    this.city,
    this.province,
    this.postalCode,
  });

  /// Get formatted address for delivery labels
  String get deliveryLabel {
    List<String> parts = [];
    
    if (houseNumber != null && street != null) {
      parts.add('$houseNumber $street');
    } else if (street != null) {
      parts.add(street!);
    }
    
    if (barangay != null) parts.add(barangay!);
    if (city != null) parts.add(city!);
    
    return parts.join(', ');
  }

  /// Check if address has sufficient detail for delivery
  bool get isDeliverable {
    return street != null && city != null;
  }
}