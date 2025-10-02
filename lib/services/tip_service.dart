import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env.dart';
import 'auth_service.dart';

class TipService {
  static const String _baseUrl = 'https://zytykkjqfexvyevvulfi.supabase.co/functions/v1';

  /// Add tip to a completed delivery
  static Future<Map<String, dynamic>> addTip({
    required String deliveryId,
    required double tipAmount,
  }) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final url = Uri.parse('$_baseUrl/add_tip');
      final accessToken = AuthService.accessToken;
      
      if (accessToken == null) {
        throw Exception('No valid session found');
      }
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'apikey': Env.supabaseAnonKey,
      };

      final body = json.encode({
        'deliveryId': deliveryId,
        'tipAmount': tipAmount,
        'customerId': user.id,
      });

      print('TipService: Adding tip of ₱$tipAmount to delivery $deliveryId');
      
      final response = await http.post(url, headers: headers, body: body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('TipService: Tip added successfully');
        return {
          'success': true,
          'message': data['message'] ?? 'Tip added successfully',
          'driverName': data['driverName'] ?? 'Driver',
        };
      } else {
        throw Exception(data['error'] ?? 'Failed to add tip');
      }
    } catch (e) {
      print('TipService error: $e');
      throw Exception('Failed to add tip: $e');
    }
  }

  /// Get suggested tip amounts based on delivery total
  static List<double> getSuggestedTipAmounts(double deliveryTotal) {
    // Standard tip amounts in PHP
    final standardTips = [20.0, 50.0, 100.0, 150.0];
    
    // Percentage-based tips (10%, 15%, 20% of delivery total)
    final percentageTips = [
      deliveryTotal * 0.10,
      deliveryTotal * 0.15,
      deliveryTotal * 0.20,
    ];

    // Combine and round to nearest 5 PHP
    final allTips = [...standardTips, ...percentageTips]
        .map((tip) => (tip / 5).round() * 5.0)
        .where((tip) => tip >= 10.0 && tip <= 500.0) // Reasonable range
        .toSet()
        .toList();

    allTips.sort();
    
    // Return top 4 suggestions
    return allTips.take(4).toList();
  }

  /// Format tip amount for display
  static String formatTipAmount(double amount) {
    return '₱${amount.toStringAsFixed(0)}';
  }

  /// Check if delivery is eligible for tipping
  static bool canAddTip(String deliveryStatus) {
    return deliveryStatus == 'delivered';
  }
}