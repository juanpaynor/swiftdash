import '../services/google_places_service.dart';
import '../services/mapbox_service.dart';

/// Hybrid address service that combines Google Places (search) with Mapbox (mapping)
/// This provides the best search quality with cost-effective mapping
class HybridAddressService {
  static bool _useGooglePlaces = true; // Can be toggled based on configuration
  static bool _useMapboxFallback = false; // TURNED OFF: Disable Mapbox fallback for now
  static bool _hasTestedAPI = false; // Track if we've tested the API
  
  /// Get address suggestions using the best available service
  /// Priority: Google Places > Mapbox (fallback) - MAPBOX DISABLED
  static Future<List<UnifiedAddressSuggestion>> getAddressSuggestions(String query) async {
    // Test Google Places API on first call
    if (!_hasTestedAPI) {
      _hasTestedAPI = true;
      await GooglePlacesService.testGooglePlacesAPI();
    }
    
    if (_useGooglePlaces) {
      try {
        // Try Google Places first for superior search quality
        final googleSuggestions = await GooglePlacesService.getAutocompleteSuggestions(query);
        
        if (googleSuggestions.isNotEmpty) {
          print('HybridAddressService: Using Google Places results (${googleSuggestions.length} suggestions)');
          return googleSuggestions.map((suggestion) => UnifiedAddressSuggestion.fromGoogle(suggestion)).toList();
        } else {
          print('HybridAddressService: Google Places returned no results for "$query"');
        }
      } catch (e) {
        print('HybridAddressService: Google Places failed: $e');
      }
    }
    
    // MAPBOX FALLBACK DISABLED - Return empty if Google fails
    if (_useMapboxFallback) {
      try {
        final mapboxSuggestions = await MapboxService.getAddressSuggestions(query);
        print('HybridAddressService: Using Mapbox results (${mapboxSuggestions.length} suggestions)');
        return mapboxSuggestions.map((suggestion) => UnifiedAddressSuggestion.fromMapbox(suggestion)).toList();
      } catch (e) {
        print('HybridAddressService: Both services failed: $e');
      }
    } else {
      print('HybridAddressService: Mapbox fallback is disabled');
    }
    
    return [];
  }

  /// Get exact address details when user selects a suggestion
  static Future<UnifiedDeliveryAddress?> getExactDeliveryAddress(UnifiedAddressSuggestion suggestion) async {
    if (suggestion.isGooglePlace) {
      // Use Google Place Details for precise address information
      try {
        final placeDetails = await GooglePlacesService.getPlaceDetails(suggestion.placeId!);
        if (placeDetails != null) {
          print('HybridAddressService: Got Google Place details for delivery');
          return UnifiedDeliveryAddress.fromGoogle(placeDetails);
        }
      } catch (e) {
        print('HybridAddressService: Google Place Details failed: $e');
      }
    }
    
    // Fallback to Mapbox reverse geocoding
    try {
      final mapboxAddress = await MapboxService.getExactDeliveryAddress(
        suggestion.latitude,
        suggestion.longitude,
      );
      if (mapboxAddress != null) {
        print('HybridAddressService: Got Mapbox delivery address details');
        return UnifiedDeliveryAddress.fromMapbox(mapboxAddress);
      }
    } catch (e) {
      print('HybridAddressService: Mapbox reverse geocoding failed: $e');
    }
    
    return null;
  }

  /// Toggle between Google Places and Mapbox for search
  static void setUseGooglePlaces(bool useGoogle) {
    _useGooglePlaces = useGoogle;
    print('HybridAddressService: Search provider set to ${useGoogle ? "Google Places" : "Mapbox"}');
  }

  /// Enable/disable Mapbox fallback
  static void setUseMapboxFallback(bool useMapbox) {
    _useMapboxFallback = useMapbox;
    print('HybridAddressService: Mapbox fallback ${useMapbox ? "enabled" : "disabled"}');
  }

  /// Check current search provider
  static bool get isUsingGooglePlaces => _useGooglePlaces;
  
  /// Check if Mapbox fallback is enabled
  static bool get isUsingMapboxFallback => _useMapboxFallback;
}

/// Unified address suggestion that works with both Google Places and Mapbox
class UnifiedAddressSuggestion {
  final String displayName;
  final String? mainText;
  final String? secondaryText;
  final double latitude;
  final double longitude;
  final String? placeId; // Google Places ID (null for Mapbox)
  final List<String> types;
  final bool isGooglePlace;
  final String sourceService;

  UnifiedAddressSuggestion({
    required this.displayName,
    this.mainText,
    this.secondaryText,
    required this.latitude,
    required this.longitude,
    this.placeId,
    required this.types,
    required this.isGooglePlace,
    required this.sourceService,
  });

  /// Create from Google Places suggestion
  factory UnifiedAddressSuggestion.fromGoogle(GooglePlacesSuggestion suggestion) {
    return UnifiedAddressSuggestion(
      displayName: suggestion.description,
      mainText: suggestion.mainText,
      secondaryText: suggestion.secondaryText,
      latitude: 0.0, // Will be populated when getting place details
      longitude: 0.0,
      placeId: suggestion.placeId,
      types: suggestion.types,
      isGooglePlace: true,
      sourceService: 'Google Places',
    );
  }

  /// Create from Mapbox suggestion
  factory UnifiedAddressSuggestion.fromMapbox(MapboxGeocodeSuggestion suggestion) {
    return UnifiedAddressSuggestion(
      displayName: suggestion.displayName,
      mainText: suggestion.displayName.split(',').first.trim(),
      secondaryText: suggestion.displayName.split(',').skip(1).join(',').trim(),
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      placeId: null,
      types: suggestion.types ?? [],
      isGooglePlace: false,
      sourceService: 'Mapbox',
    );
  }

  /// Get appropriate icon for UI display
  String get iconType {
    if (isGooglePlace) {
      if (types.contains('establishment')) return 'business';
      if (types.contains('route')) return 'road';
      if (types.contains('intersection')) return 'intersection';
      return 'place';
    } else {
      if (types.contains('poi')) return 'business';
      if (types.contains('address')) return 'home';
      return 'place';
    }
  }
}

/// Unified delivery address that works with both Google Places and Mapbox
class UnifiedDeliveryAddress {
  final String fullAddress;
  final String? name; // Business name (Google Places)
  final double latitude;
  final double longitude;
  final String? houseNumber;
  final String? street;
  final String? barangay;
  final String? city;
  final String? province;
  final String? postalCode;
  final List<String> types;
  final bool isFromGoogle;
  final String sourceService;
  final double? rating; // Google Places rating
  final int? userRatingsTotal; // Google Places review count

  UnifiedDeliveryAddress({
    required this.fullAddress,
    this.name,
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.street,
    this.barangay,
    this.city,
    this.province,
    this.postalCode,
    required this.types,
    required this.isFromGoogle,
    required this.sourceService,
    this.rating,
    this.userRatingsTotal,
  });

  /// Create from Google Place Details
  factory UnifiedDeliveryAddress.fromGoogle(GooglePlaceDetails details) {
    return UnifiedDeliveryAddress(
      fullAddress: details.formattedAddress,
      name: details.name,
      latitude: details.latitude,
      longitude: details.longitude,
      houseNumber: details.houseNumber,
      street: details.street,
      barangay: details.barangay,
      city: details.city,
      province: details.province,
      postalCode: details.postalCode,
      types: details.types,
      isFromGoogle: true,
      sourceService: 'Google Places',
      rating: details.rating,
      userRatingsTotal: details.userRatingsTotal,
    );
  }

  /// Create from Mapbox delivery address
  factory UnifiedDeliveryAddress.fromMapbox(MapboxDeliveryAddress address) {
    return UnifiedDeliveryAddress(
      fullAddress: address.fullAddress,
      name: null,
      latitude: address.latitude,
      longitude: address.longitude,
      houseNumber: address.houseNumber,
      street: address.street,
      barangay: address.barangay,
      city: address.city,
      province: address.province,
      postalCode: address.postalCode,
      types: [], // Mapbox doesn't provide detailed types
      isFromGoogle: false,
      sourceService: 'Mapbox',
      rating: null,
      userRatingsTotal: null,
    );
  }

  /// Get formatted address for delivery labels
  String get deliveryLabel {
    List<String> parts = [];
    
    // Include business name if available (Google Places)
    if (name != null && name!.isNotEmpty) {
      parts.add(name!);
    }
    
    if (houseNumber != null && street != null) {
      parts.add('$houseNumber $street');
    } else if (street != null) {
      parts.add(street!);
    }
    
    if (barangay != null) parts.add(barangay!);
    if (city != null) parts.add(city!);
    
    return parts.isNotEmpty ? parts.join(', ') : fullAddress;
  }

  /// Check if address has sufficient detail for delivery
  bool get isDeliverable {
    // Google Places businesses are generally deliverable if they have a city
    if (isFromGoogle && name != null && city != null) return true;
    
    // For addresses, need street and city
    return street != null && city != null;
  }

  /// Check if this is a business/establishment
  bool get isBusiness {
    return name != null && (types.contains('establishment') || isFromGoogle);
  }

  /// Get address quality score (0-100)
  int get qualityScore {
    int score = 0;
    
    // Base score for having coordinates
    score += 20;
    
    // Business information (Google Places bonus)
    if (name != null) score += 15;
    if (rating != null) score += 5;
    
    // Address components
    if (houseNumber != null) score += 15;
    if (street != null) score += 20;
    if (barangay != null) score += 10;
    if (city != null) score += 10;
    if (province != null) score += 5;
    
    // Google Places bonus for superior data quality
    if (isFromGoogle) score += 10;
    
    return score.clamp(0, 100);
  }

  /// Get quality description for UI
  String get qualityDescription {
    final score = qualityScore;
    if (score >= 90) return 'Excellent - Perfect for delivery';
    if (score >= 75) return 'Very Good - Delivery ready';
    if (score >= 60) return 'Good - Suitable for delivery';
    if (score >= 45) return 'Fair - May need clarification';
    return 'Basic - Consider getting more details';
  }
}