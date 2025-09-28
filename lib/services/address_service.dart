import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/address.dart';

class AddressService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all addresses for a user
  static Future<List<Address>> getUserAddresses(String userId) async {
    final response = await _supabase
        .from('addresses')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false);

    return (response as List)
        .map((addr) => Address.fromJson(addr))
        .toList();
  }

  // Create a new address
  static Future<Address> createAddress(Map<String, dynamic> addressData) async {
    final response = await _supabase
        .from('addresses')
        .insert(addressData)
        .select()
        .single();

    return Address.fromJson(response);
  }

  // Update an address
  static Future<Address> updateAddress(String addressId, Map<String, dynamic> addressData) async {
    final response = await _supabase
        .from('addresses')
        .update(addressData)
        .eq('id', addressId)
        .select()
        .single();

    return Address.fromJson(response);
  }

  // Delete an address
  static Future<void> deleteAddress(String addressId) async {
    await _supabase
        .from('addresses')
        .delete()
        .eq('id', addressId);
  }

  // Set default address
  static Future<void> setDefaultAddress(String userId, String addressId) async {
    // First, remove default from all addresses
    await _supabase
        .from('addresses')
        .update({'is_default': false})
        .eq('user_id', userId);

    // Then set the selected address as default
    await _supabase
        .from('addresses')
        .update({'is_default': true})
        .eq('id', addressId);
  }

  // Get default address
  static Future<Address?> getDefaultAddress(String userId) async {
    final response = await _supabase
        .from('addresses')
        .select()
        .eq('user_id', userId)
        .eq('is_default', true)
        .maybeSingle();

    return response != null ? Address.fromJson(response) : null;
  }
}