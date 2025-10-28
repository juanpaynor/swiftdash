import 'package:flutter/material.dart';

class VehicleType {
  final String id;
  final String name;
  final String? description;
  final double maxWeightKg;
  final double basePrice;
  final double pricePerKm;
  final double? additionalStopCharge; // Charge for each additional stop in multi-stop delivery
  final String? iconUrl;
  final bool isActive;

  VehicleType({
    required this.id,
    required this.name,
    this.description,
    required this.maxWeightKg,
    required this.basePrice,
    required this.pricePerKm,
    this.additionalStopCharge,
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
      additionalStopCharge: json['additional_stop_charge'] != null
          ? (json['additional_stop_charge'] as num).toDouble()
          : null,
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
      'additional_stop_charge': additionalStopCharge,
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
    final vehicleName = name.toLowerCase();
    
    // Motorcycle/Bike delivery
    if (vehicleName.contains('motorcycle') || 
        vehicleName.contains('bike') || 
        vehicleName.contains('motor')) {
      return Icons.two_wheeler; // Motorcycle icon
    }
    
    // Car/Sedan
    if (vehicleName.contains('car') || 
        vehicleName.contains('sedan')) {
      return Icons.directions_car; // Car icon
    }
    
    // SUV/Large Car
    if (vehicleName.contains('suv')) {
      return Icons.airport_shuttle; // SUV/larger vehicle icon
    }
    
    // Van/Mini Van
    if (vehicleName.contains('van') || 
        vehicleName.contains('mini')) {
      return Icons.local_shipping; // Van icon
    }
    
    // Pickup Truck
    if (vehicleName.contains('pickup')) {
      return Icons.rv_hookup; // Pickup truck icon
    }
    
    // Truck/Large Vehicle/Box Truck
    if (vehicleName.contains('truck') || 
        vehicleName.contains('lorry') ||
        vehicleName.contains('box') || 
        vehicleName.contains('cargo') ||
        vehicleName.contains('large')) {
      return Icons.fire_truck; // Large truck icon
    }
    
    // Default delivery icon
    return Icons.delivery_dining;
  }

  // Get color scheme based on vehicle type
  Color get primaryColor {
    final vehicleName = name.toLowerCase();
    
    // Motorcycle - Orange (fast, agile)
    if (vehicleName.contains('motorcycle') || 
        vehicleName.contains('bike') || 
        vehicleName.contains('motor')) {
      return const Color(0xFFFF6B35);
    }
    
    // Car/Sedan - Blue (standard)
    if (vehicleName.contains('car') || 
        vehicleName.contains('sedan') || 
        vehicleName.contains('vehicle')) {
      return const Color(0xFF2196F3);
    }
    
    // SUV - Purple (premium)
    if (vehicleName.contains('suv') || 
        vehicleName.contains('large')) {
      return const Color(0xFF9C27B0);
    }
    
    // Pickup - Green (utility)
    if (vehicleName.contains('pickup')) {
      return const Color(0xFF4CAF50);
    }
    
    // Van - Teal (spacious)
    if (vehicleName.contains('van') || 
        vehicleName.contains('mini')) {
      return const Color(0xFF009688);
    }
    
    // Truck - Red (heavy duty)
    if (vehicleName.contains('truck') || 
        vehicleName.contains('lorry') ||
        vehicleName.contains('box') || 
        vehicleName.contains('cargo')) {
      return const Color(0xFFE53935);
    }
    
    // Default - Gray
    return const Color(0xFF757575);
  }

  // Get lighter version of the primary color for backgrounds
  Color get lightColor {
    return primaryColor.withOpacity(0.1);
  }
}