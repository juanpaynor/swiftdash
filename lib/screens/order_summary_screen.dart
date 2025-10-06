import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../models/vehicle_type.dart';
import '../models/payment_enums.dart';
import '../models/payment_config.dart';
import '../models/payment_result.dart';
import '../services/delivery_service.dart';
import '../services/directions_service.dart';
import '../services/payment_service.dart';
import '../widgets/modern_widgets.dart';
import '../constants/app_theme.dart';

class OrderSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  
  const OrderSummaryScreen({
    super.key,
    required this.orderData,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  bool _isLoading = true;
  bool _isBooking = false;
  double? _distance;
  double? _price;
  
  // Payment state
  PaymentBy _selectedPaymentBy = PaymentBy.sender;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.creditCard;
  
  // Form controllers for additional details
  final _formKey = GlobalKey<FormState>();
  final _pickupContactNameController = TextEditingController();
  final _pickupContactPhoneController = TextEditingController();
  final _pickupInstructionsController = TextEditingController();
  final _deliveryContactNameController = TextEditingController();
  final _deliveryContactPhoneController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  final _packageDescriptionController = TextEditingController();
  final _packageWeightController = TextEditingController();
  final _packageValueController = TextEditingController();

  VehicleType get vehicleType => widget.orderData['vehicleType'] as VehicleType;
  String get pickupAddress => widget.orderData['pickupAddress'] as String;
  String get deliveryAddress => widget.orderData['deliveryAddress'] as String;
  double get pickupLat => widget.orderData['pickupLat'] as double;
  double get pickupLng => widget.orderData['pickupLng'] as double;
  double get deliveryLat => widget.orderData['deliveryLat'] as double;
  double get deliveryLng => widget.orderData['deliveryLng'] as double;

  @override
  void initState() {
    super.initState();
    _calculatePriceAndDistance();
  }

  @override
  void dispose() {
    _pickupContactNameController.dispose();
    _pickupContactPhoneController.dispose();
    _pickupInstructionsController.dispose();
    _deliveryContactNameController.dispose();
    _deliveryContactPhoneController.dispose();
    _deliveryInstructionsController.dispose();
    _packageDescriptionController.dispose();
    _packageWeightController.dispose();
    _packageValueController.dispose();
    super.dispose();
  }

  Future<void> _calculatePriceAndDistance() async {
    try {
      // Try to get quote from server first
      final data = await DeliveryService.getQuote(
        vehicleTypeId: vehicleType.id,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: deliveryLat,
        dropoffLng: deliveryLng,
        weightKg: null, // We'll handle weight validation in the form
      );
      
      setState(() {
        _distance = (data['distanceKm'] as num?)?.toDouble();
        _price = (data['total'] as num?)?.toDouble();
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to client-side calculation
      try {
        final distance = await DirectionsService.getDistance(
          startLat: pickupLat,
          startLng: pickupLng,
          endLat: deliveryLat,
          endLng: deliveryLng,
        );
        
        setState(() {
          _distance = distance;
          _price = vehicleType.calculatePrice(distance);
          _isLoading = false;
        });
      } catch (fallbackError) {
        if (mounted) {
          ModernToast.error(
            context: context,
            message: 'Unable to calculate delivery price. Please try again.',
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Order Summary',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Route Summary
                    _buildRouteCard(),
                    const SizedBox(height: 20),
                    
                    // Price Breakdown
                    _buildPriceBreakdownCard(),
                    const SizedBox(height: 24),
                    
                    // Contact Information
                    _buildContactSection(),
                    const SizedBox(height: 24),
                    
                    // Package Details
                    _buildPackageSection(),
                    const SizedBox(height: 24),
                    
                    // Payment Section
                    _buildPaymentSection(),
                    const SizedBox(height: 40),
                    
                    // Book Delivery Button
                    _buildBookButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                vehicleType.icon,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  vehicleType.name,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_distance != null)
                Text(
                  '${_distance!.toStringAsFixed(1)} km',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Pickup location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                    Text(
                      pickupAddress,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Delivery location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    Text(
                      deliveryAddress,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard() {
    if (_distance == null || _price == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text('Calculating price...'),
        ),
      );
    }

    // Calculate breakdown
    final subtotal = vehicleType.calculatePriceBeforeVAT(_distance!);
    final vat = vehicleType.calculateVAT(_distance!);
    final distanceFee = subtotal - vehicleType.basePrice;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Breakdown',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildPriceRow('Base Fee', '₱${vehicleType.basePrice.toStringAsFixed(2)}'),
          _buildPriceRow('Distance Fee (${_distance!.toStringAsFixed(1)} km)', '₱${distanceFee.toStringAsFixed(2)}'),
          _buildPriceRow('VAT (12%)', '₱${vat.toStringAsFixed(2)}'),
          
          const Divider(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '₱${_price!.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contact Information',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        Text(
          'Pickup Contact',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        
        ModernTextField(
          label: 'Contact Name',
          hintText: 'Who will hand over the package?',
          controller: _pickupContactNameController,
          prefixIcon: Icons.person_outline,
          validator: (v) => v?.isEmpty ?? true ? 'Contact name is required' : null,
        ),
        const SizedBox(height: 12),
        
        ModernTextField(
          label: 'Contact Phone',
          hintText: '+639601234567',
          controller: _pickupContactPhoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) => v?.isEmpty ?? true ? 'Phone number is required' : null,
        ),
        const SizedBox(height: 12),
        
        ModernTextField(
          label: 'Special Instructions (Optional)',
          hintText: 'Building access, floor, etc.',
          controller: _pickupInstructionsController,
          prefixIcon: Icons.note_outlined,
          maxLines: 2,
        ),
        
        const SizedBox(height: 20),
        
        Text(
          'Delivery Contact',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        
        ModernTextField(
          label: 'Contact Name',
          hintText: 'Who will receive the package?',
          controller: _deliveryContactNameController,
          prefixIcon: Icons.person_outline,
          validator: (v) => v?.isEmpty ?? true ? 'Contact name is required' : null,
        ),
        const SizedBox(height: 12),
        
        ModernTextField(
          label: 'Contact Phone',
          hintText: '+639601234567',
          controller: _deliveryContactPhoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) => v?.isEmpty ?? true ? 'Phone number is required' : null,
        ),
        const SizedBox(height: 12),
        
        ModernTextField(
          label: 'Special Instructions (Optional)',
          hintText: 'Building access, floor, apartment number, etc.',
          controller: _deliveryInstructionsController,
          prefixIcon: Icons.note_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildPackageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Package Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        ModernTextField(
          label: 'Package Description',
          hintText: 'What are you sending?',
          controller: _packageDescriptionController,
          prefixIcon: Icons.inventory_2_outlined,
          validator: (v) => v?.isEmpty ?? true ? 'Package description is required' : null,
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: ModernTextField(
                label: 'Weight (kg)',
                hintText: '0.5',
                controller: _packageWeightController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.fitness_center_outlined,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Weight is required';
                  final weight = double.tryParse(v);
                  if (weight == null) return 'Invalid weight';
                  if (weight <= 0) return 'Weight must be greater than 0';
                  if (weight > vehicleType.maxWeightKg) {
                    return 'Exceeds vehicle capacity (${vehicleType.maxWeightKg}kg)';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ModernTextField(
                label: 'Value (₱ - Optional)',
                hintText: '100.00',
                controller: _packageValueController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money_outlined,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final value = double.tryParse(v);
                  if (value == null) return 'Invalid amount';
                  if (value < 0) return 'Value cannot be negative';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payment_rounded,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Method',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Who Pays Section
          _buildWhoPaysList(),
          const SizedBox(height: 20),

          // Payment Method Section
          _buildPaymentMethodsList(),
          const SizedBox(height: 16),

          // Payment Summary
          _buildPaymentSummary(),
        ],
      ),
    );
  }

  Widget _buildWhoPaysList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who pays for this delivery?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Sender pays option
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedPaymentBy = PaymentBy.sender;
              // Reset to digital payment when sender is selected
              if (_selectedPaymentMethod == PaymentMethod.cash && 
                  _selectedPaymentBy == PaymentBy.sender) {
                _selectedPaymentMethod = PaymentMethod.creditCard;
              }
            });
            HapticFeedback.selectionClick();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedPaymentBy == PaymentBy.sender 
                  ? AppTheme.primaryBlue.withOpacity(0.1)
                  : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPaymentBy == PaymentBy.sender
                    ? AppTheme.primaryBlue
                    : AppTheme.borderColor,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedPaymentBy == PaymentBy.sender
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _selectedPaymentBy == PaymentBy.sender
                      ? AppTheme.primaryBlue
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PaymentBy.sender.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PaymentBy.sender.description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Recipient pays option
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedPaymentBy = PaymentBy.recipient;
              // Force cash payment when recipient is selected
              _selectedPaymentMethod = PaymentMethod.cash;
            });
            HapticFeedback.selectionClick();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedPaymentBy == PaymentBy.recipient 
                  ? AppTheme.primaryBlue.withOpacity(0.1)
                  : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedPaymentBy == PaymentBy.recipient
                    ? AppTheme.primaryBlue
                    : AppTheme.borderColor,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedPaymentBy == PaymentBy.recipient
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _selectedPaymentBy == PaymentBy.recipient
                      ? AppTheme.primaryBlue
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PaymentBy.recipient.displayName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PaymentBy.recipient.description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How would you like to pay?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        
        // Get available payment methods based on who pays
        ...PaymentMethod.values.map((method) {
          final isAvailable = _isPaymentMethodAvailable(method);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPaymentMethodCard(method, isAvailable),
          );
        }).toList(),
      ],
    );
  }

  bool _isPaymentMethodAvailable(PaymentMethod method) {
    // Recipient can only pay with cash
    if (_selectedPaymentBy == PaymentBy.recipient) {
      return method == PaymentMethod.cash;
    }
    // Sender can pay with any method
    return true;
  }

  Widget _buildPaymentMethodCard(PaymentMethod method, bool isAvailable) {
    final isSelected = _selectedPaymentMethod == method && isAvailable;
    
    return GestureDetector(
      onTap: isAvailable ? () {
        setState(() {
          _selectedPaymentMethod = method;
        });
        HapticFeedback.selectionClick();
      } : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryBlue.withOpacity(0.1)
              : isAvailable 
                  ? AppTheme.surfaceColor
                  : AppTheme.surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : AppTheme.borderColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppTheme.primaryBlue
                  : isAvailable 
                      ? AppTheme.textSecondary
                      : AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            _buildPaymentMethodIcon(method, isAvailable),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isAvailable 
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPaymentMethodDescription(method),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isAvailable 
                          ? AppTheme.textSecondary
                          : AppTheme.textSecondary.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (!isAvailable)
              Icon(
                Icons.block,
                color: AppTheme.textSecondary.withOpacity(0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodIcon(PaymentMethod method, bool isAvailable) {
    final color = isAvailable ? AppTheme.primaryBlue : AppTheme.textSecondary.withOpacity(0.5);
    
    switch (method) {
      case PaymentMethod.creditCard:
        return Icon(Icons.credit_card, color: color, size: 24);
      case PaymentMethod.mayaWallet:
        return Icon(Icons.account_balance_wallet, color: color, size: 24);
      case PaymentMethod.cash:
        return Icon(Icons.payments, color: color, size: 24);
    }
  }

  String _getPaymentMethodDescription(PaymentMethod method) {
    if (_selectedPaymentBy == PaymentBy.recipient && method != PaymentMethod.cash) {
      return 'Only available for sender payments';
    }
    
    switch (method) {
      case PaymentMethod.creditCard:
        return method.description;
      case PaymentMethod.mayaWallet:
        return method.description;
      case PaymentMethod.cash:
        return _selectedPaymentBy == PaymentBy.sender 
            ? 'Pay driver at pickup'
            : 'Pay driver at delivery';
    }
  }

  Widget _buildPaymentSummary() {
    final config = _createPaymentConfig();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppTheme.primaryBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.paymentTiming,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_price != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ₱${_price!.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  PaymentConfig _createPaymentConfig() {
    return PaymentConfig.fromDeliveryData(
      paidBy: _selectedPaymentBy,
      method: _selectedPaymentMethod,
      amount: _price ?? 0.0,
      deliveryId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      contactName: _selectedPaymentBy == PaymentBy.sender 
          ? _pickupContactNameController.text
          : _deliveryContactNameController.text,
      contactPhone: _selectedPaymentBy == PaymentBy.sender 
          ? _pickupContactPhoneController.text
          : _deliveryContactPhoneController.text,
    );
  }

  Widget _buildBookButton() {
    final isDigitalPayment = _selectedPaymentMethod.isDigital;
    final buttonText = _getBookButtonText();
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_distance != null && _price != null && !_isBooking) ? _handleBookDelivery : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDigitalPayment ? AppTheme.primaryBlue : AppTheme.successColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isBooking 
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              buttonText,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
      ),
    );
  }

  String _getBookButtonText() {
    if (_price == null) return 'Calculating price...';
    
    final price = '₱${_price!.toStringAsFixed(2)}';
    
    switch (_selectedPaymentMethod) {
      case PaymentMethod.creditCard:
        return 'Pay $price with Card';
      case PaymentMethod.mayaWallet:
        return 'Pay $price with Maya';
      case PaymentMethod.cash:
        return _selectedPaymentBy == PaymentBy.sender
            ? 'Book Delivery - $price (Cash)'
            : 'Book Delivery - $price (COD)';
    }
  }

  Future<void> _handleBookDelivery() async {
    if (!_formKey.currentState!.validate()) {
      ModernToast.error(
        context: context,
        message: 'Please fill in all required fields',
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      // Create payment configuration
      final paymentConfig = PaymentConfig.fromDeliveryData(
        paidBy: _selectedPaymentBy,
        method: _selectedPaymentMethod,
        amount: _price!,
        deliveryId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        contactName: _selectedPaymentBy == PaymentBy.sender 
            ? _pickupContactNameController.text
            : _deliveryContactNameController.text,
        contactPhone: _selectedPaymentBy == PaymentBy.sender 
            ? _pickupContactPhoneController.text
            : _deliveryContactPhoneController.text,
        customerEmail: null, // Could get from auth user if available
      );

      PaymentResult? paymentResult;

      // Process payment if digital method
      if (_selectedPaymentMethod.isDigital) {
        paymentResult = await PaymentService.processPayment(paymentConfig);
        
        if (!paymentResult.isSuccess) {
          if (mounted) {
            ModernToast.error(
              context: context,
              message: paymentResult.statusMessage,
            );
          }
          return;
        }
      } else {
        // Cash payment - create success result
        paymentResult = PaymentResult.cashSuccess(
          deliveryId: paymentConfig.deliveryId,
          amount: paymentConfig.amount,
        );
      }

      // Create delivery with payment information
      await _createDeliveryWithPayment(paymentResult);

    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error processing payment: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _createDeliveryWithPayment(PaymentResult paymentResult) async {
    try {
      // Create delivery using existing service but with payment data
      final delivery = await DeliveryService.bookDeliveryViaFunction(
        vehicleTypeId: vehicleType.id,
        pickupAddress: pickupAddress,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupContactName: _pickupContactNameController.text,
        pickupContactPhone: _pickupContactPhoneController.text,
        pickupInstructions: _pickupInstructionsController.text.isNotEmpty
            ? _pickupInstructionsController.text
            : null,
        dropoffAddress: deliveryAddress,
        dropoffLat: deliveryLat,
        dropoffLng: deliveryLng,
        dropoffContactName: _deliveryContactNameController.text,
        dropoffContactPhone: _deliveryContactPhoneController.text,
        dropoffInstructions: _deliveryInstructionsController.text.isNotEmpty
            ? _deliveryInstructionsController.text
            : null,
        packageDescription: _packageDescriptionController.text,
        packageWeightKg: double.tryParse(_packageWeightController.text),
        packageValue: double.tryParse(_packageValueController.text),
        // Payment information
        paymentBy: _selectedPaymentBy.name,
        paymentMethod: _selectedPaymentMethod.name,
        paymentStatus: paymentResult.status.name,
        mayaCheckoutId: paymentResult.checkoutId,
        mayaPaymentId: paymentResult.paymentId,
        paymentReference: paymentResult.paymentId ?? paymentResult.checkoutId,
        paymentMetadata: paymentResult.transactionData,
      );

      // Update delivery with payment information (this would need to be added to DeliveryService)
      // For now, we'll proceed to matching screen
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        
        // Show success message based on payment type
        if (paymentResult.isSuccess && _selectedPaymentMethod.isDigital) {
          ModernToast.success(
            context: context,
            message: 'Payment successful! Finding driver...',
          );
        } else if (_selectedPaymentMethod == PaymentMethod.cash) {
          ModernToast.success(
            context: context,
            message: 'Delivery booked! Finding driver...',
          );
        }
        
        // Navigate to matching screen
        context.go('/matching/${delivery.id}');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error creating delivery: $e',
        );
      }
      rethrow;
    }
  }
}