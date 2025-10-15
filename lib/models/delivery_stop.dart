/// Model for individual stops in a multi-stop delivery
class DeliveryStop {
  final String? id; // Nullable until saved to database
  final String deliveryId;
  final int stopNumber; // 1, 2, 3, etc. - order of stops
  final String stopType; // 'pickup' or 'dropoff'
  
  // Address details
  final String address;
  final double latitude;
  final double longitude;
  
  // Optional detailed address components
  final String? houseNumber;
  final String? street;
  final String? barangay;
  final String? city;
  final String? province;
  
  // Stop-specific details
  final String? recipientName;
  final String? recipientPhone;
  final String? deliveryNotes;
  
  // Status tracking
  final String status; // 'pending', 'arrived', 'completed', 'failed'
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  
  // Proof of delivery
  final String? proofPhotoUrl;
  final String? signatureUrl;
  final String? completionNotes;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;

  DeliveryStop({
    required this.id,
    required this.deliveryId,
    required this.stopNumber,
    required this.stopType,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.street,
    this.barangay,
    this.city,
    this.province,
    this.recipientName,
    this.recipientPhone,
    this.deliveryNotes,
    required this.status,
    this.arrivedAt,
    this.completedAt,
    this.proofPhotoUrl,
    this.signatureUrl,
    this.completionNotes,
    required this.createdAt,
    this.updatedAt,
  });

  // Copy with method for updates
  DeliveryStop copyWith({
    String? id,
    String? deliveryId,
    int? stopNumber,
    String? stopType,
    String? address,
    double? latitude,
    double? longitude,
    String? houseNumber,
    String? street,
    String? barangay,
    String? city,
    String? province,
    String? recipientName,
    String? recipientPhone,
    String? deliveryNotes,
    String? status,
    DateTime? arrivedAt,
    DateTime? completedAt,
    String? proofPhotoUrl,
    String? signatureUrl,
    String? completionNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryStop(
      id: id ?? this.id,
      deliveryId: deliveryId ?? this.deliveryId,
      stopNumber: stopNumber ?? this.stopNumber,
      stopType: stopType ?? this.stopType,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      houseNumber: houseNumber ?? this.houseNumber,
      street: street ?? this.street,
      barangay: barangay ?? this.barangay,
      city: city ?? this.city,
      province: province ?? this.province,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      status: status ?? this.status,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completedAt: completedAt ?? this.completedAt,
      proofPhotoUrl: proofPhotoUrl ?? this.proofPhotoUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      completionNotes: completionNotes ?? this.completionNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // To JSON (for database insert/update)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_id': deliveryId,
      'stop_number': stopNumber,
      'stop_type': stopType,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'house_number': houseNumber,
      'street': street,
      'barangay': barangay,
      'city': city,
      'province': province,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'delivery_notes': deliveryNotes,
      'status': status,
      'arrived_at': arrivedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'proof_photo_url': proofPhotoUrl,
      'signature_url': signatureUrl,
      'completion_notes': completionNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // For creating a new stop (before saving to database)
  Map<String, dynamic> toCreateJson() {
    return {
      'delivery_id': deliveryId,
      'stop_number': stopNumber,
      'stop_type': stopType,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'house_number': houseNumber,
      'street': street,
      'barangay': barangay,
      'city': city,
      'province': province,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'delivery_notes': deliveryNotes,
      'status': status,
    };
  }

  // From JSON (for database read)
  factory DeliveryStop.fromJson(Map<String, dynamic> json) {
    return DeliveryStop(
      id: json['id'] as String?,
      deliveryId: json['delivery_id'] as String,
      stopNumber: json['stop_number'] as int,
      stopType: json['stop_type'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      houseNumber: json['house_number'] as String?,
      street: json['street'] as String?,
      barangay: json['barangay'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      deliveryNotes: json['delivery_notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      proofPhotoUrl: json['proof_photo_url'] as String?,
      signatureUrl: json['signature_url'] as String?,
      completionNotes: json['completion_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Helper getters for stop type
  bool get isPickup => stopType == 'pickup';
  bool get isDropoff => stopType == 'dropoff';
  
  // Status helpers
  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  
  // Display helpers
  String get displayIcon {
    if (isPickup) return '📦';
    return '🏁';
  }
  
  String get displayTitle {
    if (isPickup) return 'Pickup';
    return 'Stop $stopNumber';
  }
  
  String get statusDisplayText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
  
  // Short address for display
  String get shortAddress {
    if (street != null && barangay != null) {
      return '$street, $barangay';
    }
    return address;
  }
}