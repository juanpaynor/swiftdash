import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../config/env.dart';

class GooglePlacesService {
  // SECURE: API key loaded from environment variables
  static String get _apiKey => Env.googlePlacesApiKey;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  
  // Philippines center coordinates for proximity bias
  static const double philippinesLat = 14.5995;
  static const double philippinesLng = 121.0244;
  
  // OPTIMIZATION: Cache to reduce API calls and costs
  static final Map<String, List<GooglePlacesSuggestion>> _searchCache = {};
  static final Map<String, GooglePlaceDetails?> _detailsCache = {};
  static const int _cacheMaxSize = 100;
  static const Duration _cacheExpiry = Duration(hours: 24);
  static final Map<String, DateTime> _cacheTimestamps = {};

  /// Get autocomplete suggestions using Google Places Autocomplete API
  /// Cost: $2.83 per 1000 requests
  static Future<List<GooglePlacesSuggestion>> getAutocompleteSuggestions(String query) async {
    if (query.length < 2) return [];
    
    // Clean and normalize the query
    final cleanedQuery = _cleanSearchQuery(query);
    if (cleanedQuery.isEmpty) return [];
    
    // Check cache first
    final cacheKey = cleanedQuery.toLowerCase().trim();
    if (_searchCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        print('GooglePlacesService: Returning cached autocomplete results for "$query"');
        return _searchCache[cacheKey]!;
      } else {
        _searchCache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
      }
    }
    
    print('GooglePlacesService: Searching for "$query" using Google Places Autocomplete API');
    
    try {
      final encodedQuery = Uri.encodeComponent(cleanedQuery);
      
      // Google Places Autocomplete API with improved parameters for Philippines
      final url = '$_baseUrl/place/autocomplete/json?'
          'input=$encodedQuery'
          '&key=$_apiKey'
          '&components=country:ph'  // Restrict to Philippines
          '&location=$philippinesLat,$philippinesLng'
          '&radius=100000'  // INCREASED: 100km radius for better coverage
          '&language=en'
          '&sessiontoken=${_generateSessionToken()}';  // Session token for billing optimization
      
      print('GooglePlacesService: Request URL: $url'); // DEBUG: Print URL for testing
      
      final response = await http.get(Uri.parse(url));
      
      print('GooglePlacesService: Autocomplete API response: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('GooglePlacesService: Autocomplete API error: ${response.statusCode}');
        return [];
      }
      
      final data = json.decode(response.body);
      final status = data['status'] as String?;
      final predictions = data['predictions'] as List? ?? [];
      
      print('GooglePlacesService: API Status: $status');
      print('GooglePlacesService: Found ${predictions.length} predictions');
      
      // Check for API errors
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        print('GooglePlacesService: API Error - Status: $status');
        if (data['error_message'] != null) {
          print('GooglePlacesService: Error Message: ${data['error_message']}');
        }
        return [];
      }
      
      if (predictions.isEmpty) {
        print('GooglePlacesService: No predictions found for "$query"');
        return [];
      }
      
      List<GooglePlacesSuggestion> suggestions = [];
      
      for (var prediction in predictions) {
        try {
          final placeId = prediction['place_id'] as String;
          final description = prediction['description'] as String;
          final types = (prediction['types'] as List?)?.cast<String>() ?? [];
          
          // Extract main text and secondary text for better display
          final structuredFormatting = prediction['structured_formatting'] as Map<String, dynamic>?;
          final mainText = structuredFormatting?['main_text'] as String? ?? description;
          final secondaryText = structuredFormatting?['secondary_text'] as String?;
          
          suggestions.add(GooglePlacesSuggestion(
            placeId: placeId,
            description: description,
            mainText: mainText,
            secondaryText: secondaryText,
            types: types,
          ));
        } catch (e) {
          print('GooglePlacesService: Error parsing prediction: $e');
          continue;
        }
      }
      
      // Cache the results
      _cacheResults(cacheKey, suggestions);
      
      print('GooglePlacesService: Returning ${suggestions.length} suggestions (cached for future use)');
      return suggestions;
      
    } catch (e) {
      print('GooglePlacesService: Autocomplete search error: $e');
      return [];
    }
  }

  /// Get detailed place information using Google Place Details API
  /// Cost: $17 per 1000 requests (only called when user selects a place)
  static Future<GooglePlaceDetails?> getPlaceDetails(String placeId) async {
    // Check cache first
    if (_detailsCache.containsKey(placeId)) {
      final timestamp = _cacheTimestamps[placeId];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        print('GooglePlacesService: Returning cached place details for $placeId');
        return _detailsCache[placeId];
      } else {
        _detailsCache.remove(placeId);
        _cacheTimestamps.remove(placeId);
      }
    }
    
    print('GooglePlacesService: Getting place details for $placeId using Google Place Details API');
    
    try {
      // Google Place Details API with comprehensive field selection
      final url = '$_baseUrl/place/details/json?'
          'place_id=$placeId'
          '&key=$_apiKey'
          '&fields=place_id,name,formatted_address,geometry,address_components,types,business_status,rating,user_ratings_total'
          '&language=en'
          '&sessiontoken=${_generateSessionToken()}';  // Session token for billing optimization
      
      final response = await http.get(Uri.parse(url));
      
      print('GooglePlacesService: Place Details API response: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('GooglePlacesService: Place Details API error: ${response.statusCode}');
        return null;
      }
      
      final data = json.decode(response.body);
      final result = data['result'] as Map<String, dynamic>?;
      
      if (result == null) {
        print('GooglePlacesService: No place details found');
        return null;
      }
      
      // Extract location coordinates
      final geometry = result['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = location?['lat'] as double?;
      final lng = location?['lng'] as double?;
      
      if (lat == null || lng == null) {
        print('GooglePlacesService: No coordinates found in place details');
        return null;
      }
      
      // Extract address components for delivery-grade addressing
      final addressComponents = result['address_components'] as List? ?? [];
      String? houseNumber;
      String? street;
      String? barangay;
      String? city;
      String? province;
      String? postalCode;
      
      for (var component in addressComponents) {
        final types = (component['types'] as List?)?.cast<String>() ?? [];
        final longName = component['long_name'] as String?;
        
        if (types.contains('street_number')) {
          houseNumber = longName;
        } else if (types.contains('route')) {
          street = longName;
        } else if (types.contains('sublocality_level_1') || types.contains('neighborhood')) {
          barangay = longName;
        } else if (types.contains('locality') || types.contains('administrative_area_level_2')) {
          city = longName;
        } else if (types.contains('administrative_area_level_1')) {
          province = longName;
        } else if (types.contains('postal_code')) {
          postalCode = longName;
        }
      }
      
      final placeDetails = GooglePlaceDetails(
        placeId: result['place_id'] as String,
        name: result['name'] as String?,
        formattedAddress: result['formatted_address'] as String,
        latitude: lat,
        longitude: lng,
        houseNumber: houseNumber,
        street: street,
        barangay: barangay,
        city: city,
        province: province,
        postalCode: postalCode,
        types: (result['types'] as List?)?.cast<String>() ?? [],
        rating: result['rating'] as double?,
        userRatingsTotal: result['user_ratings_total'] as int?,
      );
      
      // Cache the result
      _detailsCache[placeId] = placeDetails;
      _cacheTimestamps[placeId] = DateTime.now();
      
      print('GooglePlacesService: Place details retrieved and cached');
      return placeDetails;
      
    } catch (e) {
      print('GooglePlacesService: Place details error: $e');
      return null;
    }
  }

  /// Test method to check Google Places API configuration
  static Future<void> testGooglePlacesAPI() async {
    print('=== TESTING GOOGLE PLACES API ===');
    
    try {
      // Test with a simple, well-known place without restrictions
      final testUrl = '$_baseUrl/place/autocomplete/json?'
          'input=Manila'
          '&key=$_apiKey'
          '&language=en';
      
      print('Test URL: $testUrl');
      
      final response = await http.get(Uri.parse(testUrl));
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];
        print('API Status: $status');
        
        if (status == 'REQUEST_DENIED') {
          print('❌ API KEY ISSUE: ${data['error_message']}');
          print('Check:');
          print('1. API key is correct: AIzaSyANfwae0FJo4S8AG74T72n9XoB95y60mQ8');
          print('2. Places API (New) is enabled in Google Cloud Console');
          print('3. Billing is enabled');
          print('4. API key has no IP restrictions');
        } else if (status == 'OK') {
          final predictions = data['predictions'] as List? ?? [];
          print('✅ Google Places API is working! Found ${predictions.length} results');
        } else {
          print('⚠️ API Status: $status');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Test failed: $e');
    }
    
    print('=== END TEST ===');
  }

  /// Generate session token for billing optimization
  static String _generateSessionToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    return String.fromCharCodes(Iterable.generate(
      36, (_) => chars.codeUnitAt(random.nextInt(chars.length))
    ));
  }

  /// Clean and normalize search query for better results (less restrictive)
  static String _cleanSearchQuery(String query) {
    // Basic cleanup - keep more characters for place names
    String cleaned = query.trim()
        .replaceAll(RegExp(r'\s+'), ' ');  // Multiple spaces to single space
    
    // Don't over-filter - many place names have special characters
    // Just ensure it's not empty after basic cleanup
    return cleaned.isEmpty ? query.trim() : cleaned;
  }

  /// Cache management helper
  static void _cacheResults(String key, List<GooglePlacesSuggestion> results) {
    if (_searchCache.length >= _cacheMaxSize) {
      final oldestKey = _cacheTimestamps.keys.first;
      _searchCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
    
    _searchCache[key] = results;
    _cacheTimestamps[key] = DateTime.now();
  }
}

/// Google Places autocomplete suggestion model
class GooglePlacesSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String? secondaryText;
  final List<String> types;

  GooglePlacesSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    this.secondaryText,
    required this.types,
  });

  /// Get appropriate icon for the place type
  String get iconType {
    if (types.contains('establishment')) return 'business';
    if (types.contains('route')) return 'road';
    if (types.contains('intersection')) return 'intersection';
    if (types.contains('political')) return 'location';
    return 'place';
  }
}

/// Google Place details model with delivery-grade information
class GooglePlaceDetails {
  final String placeId;
  final String? name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? houseNumber;
  final String? street;
  final String? barangay;
  final String? city;
  final String? province;
  final String? postalCode;
  final List<String> types;
  final double? rating;
  final int? userRatingsTotal;

  GooglePlaceDetails({
    required this.placeId,
    this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.street,
    this.barangay,
    this.city,
    this.province,
    this.postalCode,
    required this.types,
    this.rating,
    this.userRatingsTotal,
  });

  /// Get formatted address for delivery labels
  String get deliveryLabel {
    List<String> parts = [];
    
    if (name != null && name!.isNotEmpty && !formattedAddress.toLowerCase().startsWith(name!.toLowerCase())) {
      parts.add(name!);
    }
    
    if (houseNumber != null && street != null) {
      parts.add('$houseNumber $street');
    } else if (street != null) {
      parts.add(street!);
    }
    
    if (barangay != null) parts.add(barangay!);
    if (city != null) parts.add(city!);
    
    return parts.isNotEmpty ? parts.join(', ') : formattedAddress;
  }

  /// Check if address has sufficient detail for delivery
  bool get isDeliverable {
    // For businesses, name and city are sufficient
    if (name != null && city != null) return true;
    
    // For addresses, need street and city
    return street != null && city != null;
  }

  /// Check if this is a business/establishment
  bool get isBusiness {
    return name != null && types.contains('establishment');
  }
}