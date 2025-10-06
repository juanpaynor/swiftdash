/// Payment system enums for SwiftDash delivery app
/// Defines who pays and how they pay

/// Who is responsible for paying the delivery fee
enum PaymentBy {
  sender,    // "I'll pay" - Sender pays
  recipient, // "Recipient pays" - Recipient pays on delivery
}

/// Available payment methods
enum PaymentMethod {
  creditCard,  // Credit/Debit cards via Maya SDK
  mayaWallet,  // Maya wallet via Maya SDK
  cash,        // Cash payment (no SDK needed)
}

/// Payment processing status
enum PaymentStatus {
  pending,     // Payment not yet attempted
  processing,  // Payment in progress (Maya SDK active)
  paid,        // Payment completed successfully
  failed,      // Payment failed
  cashPending, // Waiting for cash collection by driver
}

/// Extensions for better usability
extension PaymentByExtension on PaymentBy {
  String get displayName {
    switch (this) {
      case PaymentBy.sender:
        return "I'll pay";
      case PaymentBy.recipient:
        return "Recipient pays";
    }
  }

  String get description {
    switch (this) {
      case PaymentBy.sender:
        return "Pay now or when driver arrives";
      case PaymentBy.recipient:
        return "Recipient pays when package is delivered";
    }
  }
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.creditCard:
        return "Credit/Debit Card";
      case PaymentMethod.mayaWallet:
        return "Maya Wallet";
      case PaymentMethod.cash:
        return "Cash";
    }
  }

  String get description {
    switch (this) {
      case PaymentMethod.creditCard:
        return "Visa, Mastercard, JCB";
      case PaymentMethod.mayaWallet:
        return "Pay with Maya account balance";
      case PaymentMethod.cash:
        return "Pay with cash";
    }
  }

  /// Whether this payment method requires Maya SDK
  bool get requiresMayaSDK {
    return this == PaymentMethod.creditCard || this == PaymentMethod.mayaWallet;
  }

  /// Whether this is a digital payment method
  bool get isDigital {
    return requiresMayaSDK;
  }

  /// Icon data for UI display
  String get iconAsset {
    switch (this) {
      case PaymentMethod.creditCard:
        return 'assets/icons/credit_card.png';
      case PaymentMethod.mayaWallet:
        return 'assets/icons/maya_wallet.png';
      case PaymentMethod.cash:
        return 'assets/icons/cash.png';
    }
  }
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return "Pending";
      case PaymentStatus.processing:
        return "Processing";
      case PaymentStatus.paid:
        return "Paid";
      case PaymentStatus.failed:
        return "Failed";
      case PaymentStatus.cashPending:
        return "Cash Pending";
    }
  }

  bool get isCompleted {
    return this == PaymentStatus.paid;
  }

  bool get isInProgress {
    return this == PaymentStatus.processing;
  }

  bool get requiresAction {
    return this == PaymentStatus.pending || this == PaymentStatus.failed;
  }
}