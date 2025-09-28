import 'package:flutter/material.dart';

class Delivery {
  final String id;
  final String customerId;
  final String? driverId;
  final String vehicleTypeId;
  
  // Pickup Details
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupContactName;
  final String pickupContactPhone;
  final String? pickupInstructions;

  // Delivery Details
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String deliveryContactName;
  final String deliveryContactPhone;
  final String? deliveryInstructions;

  // Package Info
  final String packageDescription;
  final double? packageWeight;
  final double? packageValue;

  // Pricing
  final double? distanceKm;
  final int? estimatedDuration;
  final double totalPrice;

  // Status
  final String status;

  // Ratings
  final int? customerRating;
  final int? driverRating;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  Delivery({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.vehicleTypeId,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupContactName,
    required this.pickupContactPhone,
    this.pickupInstructions,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.deliveryContactName,
    required this.deliveryContactPhone,
    this.deliveryInstructions,
    required this.packageDescription,
    this.packageWeight,
    this.packageValue,
    this.distanceKm,
    this.estimatedDuration,
    required this.totalPrice,
    required this.status,
    this.customerRating,
    this.driverRating,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      driverId: json['driver_id'] as String?,
      vehicleTypeId: json['vehicle_type_id'] as String,
      pickupAddress: json['pickup_address'] as String,
      pickupLatitude: (json['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num).toDouble(),
      pickupContactName: json['pickup_contact_name'] as String,
      pickupContactPhone: json['pickup_contact_phone'] as String,
      pickupInstructions: json['pickup_instructions'] as String?,
      deliveryAddress: json['delivery_address'] as String,
      deliveryLatitude: (json['delivery_latitude'] as num).toDouble(),
      deliveryLongitude: (json['delivery_longitude'] as num).toDouble(),
      deliveryContactName: json['delivery_contact_name'] as String,
      deliveryContactPhone: json['delivery_contact_phone'] as String,
      deliveryInstructions: json['delivery_instructions'] as String?,
      packageDescription: json['package_description'] as String,
      packageWeight: json['package_weight'] != null ? 
          (json['package_weight'] as num).toDouble() : null,
      packageValue: json['package_value'] != null ? 
          (json['package_value'] as num).toDouble() : null,
      distanceKm: json['distance_km'] != null ? 
          (json['distance_km'] as num).toDouble() : null,
      estimatedDuration: json['estimated_duration'] as int?,
      totalPrice: (json['total_price'] as num).toDouble(),
      status: json['status'] as String,
      customerRating: json['customer_rating'] as int?,
      driverRating: json['driver_rating'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null ? 
          DateTime.parse(json['completed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'driver_id': driverId,
      'vehicle_type_id': vehicleTypeId,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'pickup_contact_name': pickupContactName,
      'pickup_contact_phone': pickupContactPhone,
      'pickup_instructions': pickupInstructions,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'delivery_contact_name': deliveryContactName,
      'delivery_contact_phone': deliveryContactPhone,
      'delivery_instructions': deliveryInstructions,
      'package_description': packageDescription,
      'package_weight': packageWeight,
      'package_value': packageValue,
      'distance_km': distanceKm,
      'estimated_duration': estimatedDuration,
      'total_price': totalPrice,
      'status': status,
      'customer_rating': customerRating,
      'driver_rating': driverRating,
    };
  }

  // Helper method to get a human-readable status
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'driver_assigned':
        return 'Driver Assigned';
      case 'pickup_arrived':
        return 'Driver at Pickup';
      case 'package_collected':
        return 'Package Collected';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'failed':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  // Helper method to get status color
  Color getStatusColor() {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'driver_assigned':
        return Colors.blue;
      case 'pickup_arrived':
        return Colors.cyan;
      case 'package_collected':
        return Colors.indigo;
      case 'in_transit':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'failed':
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  // Helper to check if delivery is active
  bool get isActive {
    return ['pending', 'driver_assigned', 'pickup_arrived', 
            'package_collected', 'in_transit'].contains(status);
  }

  // Copy with method for updates
  Delivery copyWith({
    String? id,
    String? customerId,
    String? driverId,
    String? vehicleTypeId,
    String? pickupAddress,
    double? pickupLatitude,
    double? pickupLongitude,
    String? pickupContactName,
    String? pickupContactPhone,
    String? pickupInstructions,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryContactName,
    String? deliveryContactPhone,
    String? deliveryInstructions,
    String? packageDescription,
    double? packageWeight,
    double? packageValue,
    double? distanceKm,
    int? estimatedDuration,
    double? totalPrice,
    String? status,
    int? customerRating,
    int? driverRating,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return Delivery(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      pickupContactName: pickupContactName ?? this.pickupContactName,
      pickupContactPhone: pickupContactPhone ?? this.pickupContactPhone,
      pickupInstructions: pickupInstructions ?? this.pickupInstructions,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      deliveryContactName: deliveryContactName ?? this.deliveryContactName,
      deliveryContactPhone: deliveryContactPhone ?? this.deliveryContactPhone,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      packageDescription: packageDescription ?? this.packageDescription,
      packageWeight: packageWeight ?? this.packageWeight,
      packageValue: packageValue ?? this.packageValue,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      customerRating: customerRating ?? this.customerRating,
      driverRating: driverRating ?? this.driverRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}