import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_address.dart';

/// Service for managing saved addresses (Home, Office, frequently used places)
class SavedAddressService {
  static final _supabase = Supabase.instance.client;

  /// Get all saved addresses for the current user
  /// Returns list sorted by creation date (newest first)
  static Future<List<SavedAddress>> getSavedAddresses() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('saved_addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SavedAddress.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error fetching saved addresses: $e');
      rethrow;
    }
  }

  /// Save a new address
  static Future<SavedAddress> saveAddress({
    required String label,
    required String emoji,
    required String fullAddress,
    required double latitude,
    required double longitude,
    String? houseNumber,
    String? street,
    String? barangay,
    String? city,
    String? province,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final data = {
        'user_id': userId,
        'label': label,
        'emoji': emoji,
        'full_address': fullAddress,
        'latitude': latitude,
        'longitude': longitude,
        'house_number': houseNumber,
        'street': street,
        'barangay': barangay,
        'city': city,
        'province': province,
      };

      final response = await _supabase
          .from('saved_addresses')
          .insert(data)
          .select()
          .single();

      print('✅ Address saved: $label ($emoji)');
      return SavedAddress.fromJson(response);
    } catch (e) {
      print('❌ Error saving address: $e');
      rethrow;
    }
  }

  /// Update an existing saved address
  static Future<SavedAddress> updateAddress({
    required String id,
    String? label,
    String? emoji,
    String? fullAddress,
    double? latitude,
    double? longitude,
    String? houseNumber,
    String? street,
    String? barangay,
    String? city,
    String? province,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final data = <String, dynamic>{};
      if (label != null) data['label'] = label;
      if (emoji != null) data['emoji'] = emoji;
      if (fullAddress != null) data['full_address'] = fullAddress;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (houseNumber != null) data['house_number'] = houseNumber;
      if (street != null) data['street'] = street;
      if (barangay != null) data['barangay'] = barangay;
      if (city != null) data['city'] = city;
      if (province != null) data['province'] = province;

      final response = await _supabase
          .from('saved_addresses')
          .update(data)
          .eq('id', id)
          .eq('user_id', userId)
          .select()
          .single();

      print('✅ Address updated: $id');
      return SavedAddress.fromJson(response);
    } catch (e) {
      print('❌ Error updating address: $e');
      rethrow;
    }
  }

  /// Delete a saved address
  static Future<void> deleteAddress(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('saved_addresses')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      print('✅ Address deleted: $id');
    } catch (e) {
      print('❌ Error deleting address: $e');
      rethrow;
    }
  }

  /// Check if a label already exists for the current user
  static Future<bool> labelExists(String label) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final response = await _supabase
          .from('saved_addresses')
          .select('id')
          .eq('user_id', userId)
          .eq('label', label)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Error checking label existence: $e');
      return false;
    }
  }

  /// Search saved addresses by query (matches label or address)
  static Future<List<SavedAddress>> searchSavedAddresses(String query) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      if (query.isEmpty) {
        return await getSavedAddresses();
      }

      final response = await _supabase
          .from('saved_addresses')
          .select()
          .eq('user_id', userId)
          .or('label.ilike.%$query%,full_address.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SavedAddress.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error searching saved addresses: $e');
      return [];
    }
  }

  /// Get a specific saved address by ID
  static Future<SavedAddress?> getAddressById(String id) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }

      final response = await _supabase
          .from('saved_addresses')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      
      return SavedAddress.fromJson(response);
    } catch (e) {
      print('❌ Error fetching address by ID: $e');
      return null;
    }
  }

  /// Predefined emoji options for address labels
  static const List<String> commonEmojis = [
    '🏠', // Home
    '🏢', // Office
    '📦', // Warehouse/Storage
    '🏪', // Store/Shop
    '🏥', // Hospital/Clinic
    '🏫', // School
    '⛪', // Church
    '🏋️', // Gym
    '🍴', // Restaurant
    '☕', // Cafe
    '🏨', // Hotel
    '✈️', // Airport
    '🚉', // Station
    '🏦', // Bank
    '📍', // General Pin
    '⭐', // Favorite
    '💼', // Business
    '👨‍👩‍👧‍👦', // Family
    '👫', // Friends
    '🎯', // Target/Goal
  ];

  /// Get suggested label based on address components
  static String suggestLabel(String address) {
    final lowerAddress = address.toLowerCase();
    
    if (lowerAddress.contains('home') || lowerAddress.contains('house')) {
      return 'Home';
    } else if (lowerAddress.contains('office') || lowerAddress.contains('work')) {
      return 'Office';
    } else if (lowerAddress.contains('warehouse') || lowerAddress.contains('storage')) {
      return 'Warehouse';
    } else if (lowerAddress.contains('store') || lowerAddress.contains('shop')) {
      return 'Store';
    } else if (lowerAddress.contains('hospital') || lowerAddress.contains('clinic')) {
      return 'Hospital';
    } else if (lowerAddress.contains('school') || lowerAddress.contains('university')) {
      return 'School';
    } else {
      return 'Saved Place';
    }
  }

  /// Get suggested emoji based on label
  static String suggestEmoji(String label) {
    final lowerLabel = label.toLowerCase();
    
    if (lowerLabel.contains('home') || lowerLabel.contains('house')) {
      return '🏠';
    } else if (lowerLabel.contains('office') || lowerLabel.contains('work')) {
      return '🏢';
    } else if (lowerLabel.contains('warehouse') || lowerLabel.contains('storage')) {
      return '📦';
    } else if (lowerLabel.contains('store') || lowerLabel.contains('shop')) {
      return '🏪';
    } else if (lowerLabel.contains('hospital') || lowerLabel.contains('clinic')) {
      return '🏥';
    } else if (lowerLabel.contains('school') || lowerLabel.contains('university')) {
      return '🏫';
    } else if (lowerLabel.contains('church') || lowerLabel.contains('chapel')) {
      return '⛪';
    } else if (lowerLabel.contains('gym') || lowerLabel.contains('fitness')) {
      return '🏋️';
    } else if (lowerLabel.contains('restaurant') || lowerLabel.contains('food')) {
      return '🍴';
    } else if (lowerLabel.contains('cafe') || lowerLabel.contains('coffee')) {
      return '☕';
    } else {
      return '📍';
    }
  }
}
