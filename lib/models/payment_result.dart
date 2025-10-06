import 'payment_enums.dart';

/// Result of a payment transaction
/// Contains success/failure status and transaction details
class PaymentResult {
  /// Whether the payment was successful
  final bool isSuccess;
  
  /// Current payment status
  final PaymentStatus status;
  
  /// Maya checkout ID (for digital payments)
  final String? checkoutId;
  
  /// Maya payment ID (for completed payments)
  final String? paymentId;
  
  /// Associated delivery ID
  final String? deliveryId;
  
  /// Transaction amount
  final double? amount;
  
  /// Payment method used
  final PaymentMethod? method;
  
  /// Maya payment method details (card, wallet, etc.)
  final String? mayaPaymentMethod;
  
  /// Error message if payment failed
  final String? errorMessage;
  
  /// Error code for debugging
  final String? errorCode;
  
  /// Transaction timestamp
  final DateTime timestamp;
  
  /// Additional transaction data from Maya
  final Map<String, dynamic>? transactionData;

  PaymentResult._({
    required this.isSuccess,
    required this.status,
    this.checkoutId,
    this.paymentId,
    this.deliveryId,
    this.amount,
    this.method,
    this.mayaPaymentMethod,
    this.errorMessage,
    this.errorCode,
    required this.timestamp,
    this.transactionData,
  });

  /// Success result for digital payments
  factory PaymentResult.success({
    required String checkoutId,
    String? paymentId,
    required String deliveryId,
    required double amount,
    required PaymentMethod method,
    String? mayaPaymentMethod,
    Map<String, dynamic>? transactionData,
  }) {
    return PaymentResult._(
      isSuccess: true,
      status: PaymentStatus.paid,
      checkoutId: checkoutId,
      paymentId: paymentId,
      deliveryId: deliveryId,
      amount: amount,
      method: method,
      mayaPaymentMethod: mayaPaymentMethod,
      timestamp: DateTime.now(),
      transactionData: transactionData,
    );
  }

  /// Success result for cash payments
  factory PaymentResult.cashSuccess({
    required String deliveryId,
    required double amount,
  }) {
    return PaymentResult._(
      isSuccess: true,
      status: PaymentStatus.cashPending,
      deliveryId: deliveryId,
      amount: amount,
      method: PaymentMethod.cash,
      timestamp: DateTime.now(),
    );
  }

  /// Failed payment result
  factory PaymentResult.failure({
    required String errorMessage,
    String? checkoutId,
    String? deliveryId,
    double? amount,
    PaymentMethod? method,
    String? errorCode,
    Map<String, dynamic>? transactionData,
  }) {
    return PaymentResult._(
      isSuccess: false,
      status: PaymentStatus.failed,
      checkoutId: checkoutId,
      deliveryId: deliveryId,
      amount: amount,
      method: method,
      errorMessage: errorMessage,
      errorCode: errorCode,
      timestamp: DateTime.now(),
      transactionData: transactionData,
    );
  }

  /// Cancelled payment result
  factory PaymentResult.cancelled({
    String? checkoutId,
    String? deliveryId,
    double? amount,
    PaymentMethod? method,
  }) {
    return PaymentResult._(
      isSuccess: false,
      status: PaymentStatus.pending,
      checkoutId: checkoutId,
      deliveryId: deliveryId,
      amount: amount,
      method: method,
      errorMessage: "Payment was cancelled by user",
      timestamp: DateTime.now(),
    );
  }

  /// Processing payment result
  factory PaymentResult.processing({
    required String checkoutId,
    required String deliveryId,
    required double amount,
    required PaymentMethod method,
  }) {
    return PaymentResult._(
      isSuccess: false,
      status: PaymentStatus.processing,
      checkoutId: checkoutId,
      deliveryId: deliveryId,
      amount: amount,
      method: method,
      timestamp: DateTime.now(),
    );
  }

  /// Create from JSON (platform channel response)
  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    final isSuccess = json['isSuccess'] as bool? ?? false;
    final statusString = json['status'] as String?;
    final status = statusString != null 
        ? PaymentStatus.values.firstWhere(
            (e) => e.name == statusString,
            orElse: () => PaymentStatus.pending,
          )
        : PaymentStatus.pending;

    return PaymentResult._(
      isSuccess: isSuccess,
      status: status,
      checkoutId: json['checkoutId'] as String?,
      paymentId: json['paymentId'] as String?,
      deliveryId: json['deliveryId'] as String?,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      method: json['method'] != null 
          ? PaymentMethod.values.firstWhere((e) => e.name == json['method'])
          : null,
      mayaPaymentMethod: json['mayaPaymentMethod'] as String?,
      errorMessage: json['errorMessage'] as String?,
      errorCode: json['errorCode'] as String?,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      transactionData: json['transactionData'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'isSuccess': isSuccess,
      'status': status.name,
      'checkoutId': checkoutId,
      'paymentId': paymentId,
      'deliveryId': deliveryId,
      'amount': amount,
      'method': method?.name,
      'mayaPaymentMethod': mayaPaymentMethod,
      'errorMessage': errorMessage,
      'errorCode': errorCode,
      'timestamp': timestamp.toIso8601String(),
      'transactionData': transactionData,
    };
  }

  /// User-friendly status message
  String get statusMessage {
    if (isSuccess) {
      switch (method) {
        case PaymentMethod.cash:
          return "Cash payment scheduled - driver will collect";
        case PaymentMethod.creditCard:
        case PaymentMethod.mayaWallet:
          return "Payment successful - ${method!.displayName}";
        default:
          return "Payment completed successfully";
      }
    } else {
      switch (status) {
        case PaymentStatus.processing:
          return "Payment is being processed...";
        case PaymentStatus.failed:
          return errorMessage ?? "Payment failed";
        case PaymentStatus.pending:
          return "Payment was cancelled";
        default:
          return "Payment status unknown";
      }
    }
  }

  /// Whether this result requires user action
  bool get requiresAction {
    return !isSuccess && status == PaymentStatus.pending;
  }

  /// Whether this payment can be retried
  bool get canRetry {
    return !isSuccess && status == PaymentStatus.failed;
  }

  @override
  String toString() {
    return 'PaymentResult(isSuccess: $isSuccess, status: $status, checkoutId: $checkoutId, deliveryId: $deliveryId, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentResult &&
        other.isSuccess == isSuccess &&
        other.status == status &&
        other.checkoutId == checkoutId &&
        other.deliveryId == deliveryId;
  }

  @override
  int get hashCode {
    return Object.hash(isSuccess, status, checkoutId, deliveryId);
  }
}