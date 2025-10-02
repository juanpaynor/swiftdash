import 'package:flutter/material.dart';

class VehicleType {
  final String id;
  final String name;
  final String? description;
  final double maxWeightKg;
  final double basePrice;
  final double pricePerKm;
  final String? iconUrl;
  final bool isActive;

  VehicleType({
    required this.id,
    required this.name,
    this.description,
    required this.maxWeightKg,
    required this.basePrice,
    required this.pricePerKm,
    this.iconUrl,
    required this.isActive,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      maxWeightKg: (json['max_weight_kg'] as num).toDouble(),
      basePrice: (json['base_price'] as num).toDouble(),
      pricePerKm: (json['price_per_km'] as num).toDouble(),
      iconUrl: json['icon_url'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'max_weight_kg': maxWeightKg,
      'base_price': basePrice,
      'price_per_km': pricePerKm,
      'icon_url': iconUrl,
      'is_active': isActive,
    };
  }

  // Calculate price for a given distance (including 12% VAT)
  double calculatePrice(double distanceKm) {
    final subtotal = basePrice + (pricePerKm * distanceKm);
    const vatRate = 0.12; // 12% VAT for Philippines
    final vat = subtotal * vatRate;
    return subtotal + vat;
  }

  // Calculate price without VAT
  double calculatePriceBeforeVAT(double distanceKm) {
    return basePrice + (pricePerKm * distanceKm);
  }

  // Calculate VAT amount
  double calculateVAT(double distanceKm) {
    final subtotal = calculatePriceBeforeVAT(distanceKm);
    const vatRate = 0.12;
    return subtotal * vatRate;
  }

  // Get icon based on vehicle type
  IconData get icon {
    switch (name.toLowerCase()) {
      case 'motorcycle':
        return Icons.motorcycle;
      case 'car':
        return Icons.directions_car;
      case 'van':
        return Icons.local_shipping;
      case 'truck':
        return Icons.fire_truck; // or Icons.local_shipping if unavailable
      default:
        return Icons.delivery_dining;
    }
  }
}