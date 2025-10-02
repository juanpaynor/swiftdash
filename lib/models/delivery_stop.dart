class DeliveryStop {
  final String id;
  final String type; // 'pickup' or 'delivery'
  final String address;
  final double? latitude;
  final double? longitude;
  final String contactName;
  final String contactPhone;
  final String? instructions;
  final String? packageDescription; // Only for pickup stops
  final double? packageWeight; // Only for pickup stops
  final double? packageValue; // Only for pickup stops
  final bool isCompleted;

  DeliveryStop({
    required this.id,
    required this.type,
    required this.address,
    this.latitude,
    this.longitude,
    required this.contactName,
    required this.contactPhone,
    this.instructions,
    this.packageDescription,
    this.packageWeight,
    this.packageValue,
    this.isCompleted = false,
  });

  DeliveryStop copyWith({
    String? id,
    String? type,
    String? address,
    double? latitude,
    double? longitude,
    String? contactName,
    String? contactPhone,
    String? instructions,
    String? packageDescription,
    double? packageWeight,
    double? packageValue,
    bool? isCompleted,
  }) {
    return DeliveryStop(
      id: id ?? this.id,
      type: type ?? this.type,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      instructions: instructions ?? this.instructions,
      packageDescription: packageDescription ?? this.packageDescription,
      packageWeight: packageWeight ?? this.packageWeight,
      packageValue: packageValue ?? this.packageValue,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'instructions': instructions,
      'package_description': packageDescription,
      'package_weight': packageWeight,
      'package_value': packageValue,
      'is_completed': isCompleted,
    };
  }

  factory DeliveryStop.fromJson(Map<String, dynamic> json) {
    return DeliveryStop(
      id: json['id'],
      type: json['type'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      contactName: json['contact_name'],
      contactPhone: json['contact_phone'],
      instructions: json['instructions'],
      packageDescription: json['package_description'],
      packageWeight: json['package_weight']?.toDouble(),
      packageValue: json['package_value']?.toDouble(),
      isCompleted: json['is_completed'] ?? false,
    );
  }

  bool get isPickup => type == 'pickup';
  bool get isDelivery => type == 'delivery';
  bool get hasValidLocation => latitude != null && longitude != null;
  
  String get displayIcon => isPickup ? '📦' : '🏁';
  String get displayTitle => isPickup ? 'Pickup' : 'Delivery';
}