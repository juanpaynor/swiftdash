/// Model for saved addresses (Home, Office, frequently used places)
class SavedAddress {
  final String id;
  final String userId;
  final String label; // "Home", "Office", "Warehouse A", etc.
  final String emoji; // 🏠, 🏢, 📦, etc.
  final String fullAddress;
  final double latitude;
  final double longitude;
  
  // Optional detailed address components
  final String? houseNumber;
  final String? street;
  final String? barangay;
  final String? city;
  final String? province;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  SavedAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.emoji,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.street,
    this.barangay,
    this.city,
    this.province,
    required this.createdAt,
    this.updatedAt,
  });

  // From JSON (database response)
  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String,
      emoji: json['emoji'] as String,
      fullAddress: json['full_address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      houseNumber: json['house_number'] as String?,
      street: json['street'] as String?,
      barangay: json['barangay'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  // To JSON (for database insert/update)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Display label with emoji
  String get displayName => '$emoji $label';
  
  // Short address for display
  String get shortAddress {
    if (street != null && barangay != null) {
      return '$street, $barangay';
    }
    // Fall back to first line of full address
    final parts = fullAddress.split(',');
    return parts.isNotEmpty ? parts.first.trim() : fullAddress;
  }

  // Copy with method for updates
  SavedAddress copyWith({
    String? id,
    String? userId,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      fullAddress: fullAddress ?? this.fullAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      houseNumber: houseNumber ?? this.houseNumber,
      street: street ?? this.street,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
