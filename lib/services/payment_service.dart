import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/payment_config.dart';
import '../models/payment_result.dart';
import '../models/payment_enums.dart';

/// Main payment service for SwiftDash delivery app
/// Handles both digital payments (via Maya SDK) and cash payments
class PaymentService {
  static const MethodChannel _platform = MethodChannel('swiftdash/payment');
  
  /// Maya API credentials
  static String? _publicKey;
  static bool _isSandbox = true;
  static bool _isInitialized = false;

  /// Initialize the payment service with Maya credentials
  /// This should be called once during app startup
  static Future<bool> initialize({
    required String publicKey,
    required bool isSandbox,
  }) async {
    try {
      _publicKey = publicKey;
      _isSandbox = isSandbox;
      
      if (kDebugMode) {
        debugPrint('PaymentService: Initializing with ${isSandbox ? 'SANDBOX' : 'PRODUCTION'} environment');
      }
      
      final result = await _platform.invokeMethod('initializePayment', {
        'publicKey': publicKey,
        'environment': isSandbox ? 'SANDBOX' : 'PRODUCTION',
        'logLevel': kDebugMode ? 'DEBUG' : 'ERROR',
      });
      
      _isInitialized = result['success'] ?? false;
      
      if (kDebugMode) {
        debugPrint('PaymentService: Initialization ${_isInitialized ? 'successful' : 'failed'}');
      }
      
      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PaymentService: Initialization error: $e');
      }
      return false;
    }
  }

  /// Process a payment based on the payment configuration
  /// Routes to appropriate payment method (digital or cash)
  static Future<PaymentResult> processPayment(PaymentConfig config) async {
    try {
      if (kDebugMode) {
        debugPrint('PaymentService: Processing payment - ${config.toString()}');
      }

      // Validate initialization for digital payments
      if (config.requiresMayaSDK && !_isInitialized) {
        return PaymentResult.failure(
          errorMessage: 'Payment service not initialized. Please restart the app.',
          errorCode: 'SERVICE_NOT_INITIALIZED',
          deliveryId: config.deliveryId,
          amount: config.amount,
          method: config.method,
        );
      }

      // Route to appropriate payment method
      switch (config.method) {
        case PaymentMethod.creditCard:
        case PaymentMethod.mayaWallet:
          return await _processDigitalPayment(config);
        case PaymentMethod.cash:
          return _processCashPayment(config);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PaymentService: Payment processing error: $e');
      }
      
      return PaymentResult.failure(
        errorMessage: 'Payment failed: ${e.toString()}',
        errorCode: 'PAYMENT_ERROR',
        deliveryId: config.deliveryId,
        amount: config.amount,
        method: config.method,
      );
    }
  }

  /// Process digital payments via Maya SDK
  static Future<PaymentResult> _processDigitalPayment(PaymentConfig config) async {
    try {
      if (kDebugMode) {
        debugPrint('PaymentService: Starting digital payment via Maya SDK');
      }

      // Create checkout request data for platform channel
      final checkoutData = {
        'amount': config.amount,
        'description': config.description,
        'referenceNumber': config.referenceNumber,
        'deliveryId': config.deliveryId,
        
        // Customer information
        'customerName': config.customerName,
        'customerEmail': config.customerEmail,
        'customerPhone': config.customerPhone,
        
        // Payment method preference
        'paymentMethod': config.method.name,
        
        // Metadata
        'metadata': config.metadata,
        
        // Redirect URLs (for web fallback)
        'successUrl': 'swiftdash://payment/success',
        'failureUrl': 'swiftdash://payment/failure',
        'cancelUrl': 'swiftdash://payment/cancel',
      };

      // Call platform channel to start Maya checkout
      final result = await _platform.invokeMethod('startCheckout', checkoutData);
      
      if (kDebugMode) {
        debugPrint('PaymentService: Maya SDK result: $result');
      }

      return PaymentResult.fromJson(result);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PaymentService: Digital payment error: $e');
      }
      
      return PaymentResult.failure(
        errorMessage: 'Digital payment failed: ${e.toString()}',
        errorCode: 'MAYA_SDK_ERROR',
        deliveryId: config.deliveryId,
        amount: config.amount,
        method: config.method,
      );
    }
  }

  /// Process cash payments (no SDK required)
  static PaymentResult _processCashPayment(PaymentConfig config) {
    if (kDebugMode) {
      debugPrint('PaymentService: Processing cash payment - no SDK required');
    }

    // Cash payments are always "successful" but pending collection
    return PaymentResult.cashSuccess(
      deliveryId: config.deliveryId,
      amount: config.amount,
    );
  }

  /// Check payment status for a specific checkout ID
  /// Useful for interrupted flows or payment verification
  static Future<PaymentResult> checkPaymentStatus(String checkoutId) async {
    try {
      if (!_isInitialized) {
        return PaymentResult.failure(
          errorMessage: 'Payment service not initialized',
          errorCode: 'SERVICE_NOT_INITIALIZED',
        );
      }

      if (kDebugMode) {
        debugPrint('PaymentService: Checking payment status for checkoutId: $checkoutId');
      }

      final result = await _platform.invokeMethod('checkPaymentStatus', {
        'checkoutId': checkoutId,
      });

      return PaymentResult.fromJson(result);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PaymentService: Status check error: $e');
      }
      
      return PaymentResult.failure(
        errorMessage: 'Failed to check payment status: ${e.toString()}',
        errorCode: 'STATUS_CHECK_ERROR',
      );
    }
  }

  /// Get available payment methods for the current configuration
  static List<PaymentMethod> getAvailablePaymentMethods() {
    // Always include cash
    final methods = [PaymentMethod.cash];
    
    // Add digital methods if Maya is initialized
    if (_isInitialized) {
      methods.addAll([
        PaymentMethod.creditCard,
        PaymentMethod.mayaWallet,
      ]);
    }
    
    if (kDebugMode) {
      debugPrint('PaymentService: Available payment methods: ${methods.map((m) => m.name).join(', ')}');
    }
    
    return methods;
  }

  /// Validate payment configuration before processing
  static PaymentValidationResult validatePaymentConfig(PaymentConfig config) {
    final errors = <String>[];

    // Basic validation
    if (config.amount <= 0) {
      errors.add('Payment amount must be greater than zero');
    }

    if (config.deliveryId.isEmpty) {
      errors.add('Delivery ID is required');
    }

    if (config.description.isEmpty) {
      errors.add('Payment description is required');
    }

    // Digital payment validation
    if (config.requiresMayaSDK) {
      if (!_isInitialized) {
        errors.add('Maya payment service is not initialized');
      }

      if (_publicKey == null || _publicKey!.isEmpty) {
        errors.add('Maya public key is required for digital payments');
      }

      // Optional but recommended customer info
      if (config.customerName == null || config.customerName!.isEmpty) {
        errors.add('Customer name is recommended for digital payments');
      }
    }

    return PaymentValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Get current service status
  static PaymentServiceStatus getServiceStatus() {
    return PaymentServiceStatus(
      isInitialized: _isInitialized,
      isSandbox: _isSandbox,
      hasPublicKey: _publicKey != null && _publicKey!.isNotEmpty,
      availablePaymentMethods: getAvailablePaymentMethods(),
    );
  }

  /// Reset/cleanup the payment service
  static Future<void> cleanup() async {
    try {
      if (_isInitialized) {
        await _platform.invokeMethod('cleanup');
      }
      
      _isInitialized = false;
      _publicKey = null;
      
      if (kDebugMode) {
        debugPrint('PaymentService: Cleanup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PaymentService: Cleanup error: $e');
      }
    }
  }

  /// Handle payment results from platform channel callbacks
  /// This method can be called from your main app to handle deep links
  static PaymentResult handlePaymentCallback(String url) {
    try {
      final uri = Uri.parse(url);
      
      if (uri.scheme == 'swiftdash' && uri.host == 'payment') {
        switch (uri.pathSegments.first) {
          case 'success':
            return PaymentResult.success(
              checkoutId: uri.queryParameters['checkoutId'] ?? '',
              paymentId: uri.queryParameters['paymentId'],
              deliveryId: uri.queryParameters['deliveryId'] ?? '',
              amount: double.tryParse(uri.queryParameters['amount'] ?? '0') ?? 0,
              method: PaymentMethod.values.firstWhere(
                (m) => m.name == uri.queryParameters['method'],
                orElse: () => PaymentMethod.creditCard,
              ),
            );
            
          case 'failure':
            return PaymentResult.failure(
              errorMessage: uri.queryParameters['error'] ?? 'Payment failed',
              checkoutId: uri.queryParameters['checkoutId'],
              deliveryId: uri.queryParameters['deliveryId'],
            );
            
          case 'cancel':
            return PaymentResult.cancelled(
              checkoutId: uri.queryParameters['checkoutId'],
              deliveryId: uri.queryParameters['deliveryId'],
            );
        }
      }
      
      return PaymentResult.failure(
        errorMessage: 'Invalid payment callback URL',
        errorCode: 'INVALID_CALLBACK',
      );
      
    } catch (e) {
      return PaymentResult.failure(
        errorMessage: 'Failed to parse payment callback: ${e.toString()}',
        errorCode: 'CALLBACK_PARSE_ERROR',
      );
    }
  }
}

/// Payment validation result
class PaymentValidationResult {
  final bool isValid;
  final List<String> errors;

  PaymentValidationResult({
    required this.isValid,
    required this.errors,
  });

  String get errorMessage => errors.join(', ');
}

/// Payment service status
class PaymentServiceStatus {
  final bool isInitialized;
  final bool isSandbox;
  final bool hasPublicKey;
  final List<PaymentMethod> availablePaymentMethods;

  PaymentServiceStatus({
    required this.isInitialized,
    required this.isSandbox,
    required this.hasPublicKey,
    required this.availablePaymentMethods,
  });

  @override
  String toString() {
    return 'PaymentServiceStatus(initialized: $isInitialized, sandbox: $isSandbox, methods: ${availablePaymentMethods.length})';
  }
}