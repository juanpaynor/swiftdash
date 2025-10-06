import 'payment_enums.dart';

/// Configuration for a payment transaction
/// Contains all data needed to process a payment
class PaymentConfig {
  /// Who is paying for the delivery
  final PaymentBy paidBy;
  
  /// How the payment will be processed
  final PaymentMethod method;
  
  /// Total amount to be paid
  final double amount;
  
  /// Associated delivery ID
  final String deliveryId;
  
  /// Customer information for Maya SDK
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  
  /// Payment description for Maya
  final String description;
  
  /// Unique reference number for this transaction
  final String referenceNumber;
  
  /// Additional metadata
  final Map<String, dynamic>? metadata;

  PaymentConfig({
    required this.paidBy,
    required this.method,
    required this.amount,
    required this.deliveryId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    required this.description,
    required this.referenceNumber,
    this.metadata,
  });

  /// Factory constructor to create from delivery data
  factory PaymentConfig.fromDeliveryData({
    required PaymentBy paidBy,
    required PaymentMethod method,
    required double amount,
    required String deliveryId,
    required String contactName,
    required String contactPhone,
    String? customerEmail,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return PaymentConfig(
      paidBy: paidBy,
      method: method,
      amount: amount,
      deliveryId: deliveryId,
      customerName: contactName,
      customerEmail: customerEmail,
      customerPhone: contactPhone,
      description: 'SwiftDash Delivery Service',
      referenceNumber: 'SWIFTDASH_${deliveryId}_${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'deliveryId': deliveryId,
        'paidBy': paidBy.name,
        'paymentMethod': method.name,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalMetadata,
      },
    );
  }

  /// Whether this payment requires Maya SDK processing
  bool get requiresMayaSDK => method.requiresMayaSDK;
  
  /// Whether this is a digital payment
  bool get isDigitalPayment => method.isDigital;
  
  /// Whether this is a cash payment
  bool get isCashPayment => method == PaymentMethod.cash;
  
  /// Payment timing description for UI
  String get paymentTiming {
    if (isCashPayment) {
      switch (paidBy) {
        case PaymentBy.sender:
          return "Pay driver at pickup";
        case PaymentBy.recipient:
          return "Pay driver at delivery";
      }
    } else {
      return "Pay now with ${method.displayName}";
    }
  }
  
  /// Convert to JSON for platform channel communication
  Map<String, dynamic> toJson() {
    return {
      'paidBy': paidBy.name,
      'method': method.name,
      'amount': amount,
      'deliveryId': deliveryId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'description': description,
      'referenceNumber': referenceNumber,
      'metadata': metadata,
    };
  }
  
  /// Create from JSON (for platform channel responses)
  factory PaymentConfig.fromJson(Map<String, dynamic> json) {
    return PaymentConfig(
      paidBy: PaymentBy.values.firstWhere((e) => e.name == json['paidBy']),
      method: PaymentMethod.values.firstWhere((e) => e.name == json['method']),
      amount: (json['amount'] as num).toDouble(),
      deliveryId: json['deliveryId'] as String,
      customerName: json['customerName'] as String?,
      customerEmail: json['customerEmail'] as String?,
      customerPhone: json['customerPhone'] as String?,
      description: json['description'] as String,
      referenceNumber: json['referenceNumber'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Create a copy with updated values
  PaymentConfig copyWith({
    PaymentBy? paidBy,
    PaymentMethod? method,
    double? amount,
    String? deliveryId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? description,
    String? referenceNumber,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentConfig(
      paidBy: paidBy ?? this.paidBy,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      deliveryId: deliveryId ?? this.deliveryId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      description: description ?? this.description,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'PaymentConfig(paidBy: $paidBy, method: $method, amount: \$${amount.toStringAsFixed(2)}, deliveryId: $deliveryId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentConfig &&
        other.paidBy == paidBy &&
        other.method == method &&
        other.amount == amount &&
        other.deliveryId == deliveryId &&
        other.referenceNumber == referenceNumber;
  }

  @override
  int get hashCode {
    return Object.hash(paidBy, method, amount, deliveryId, referenceNumber);
  }
}