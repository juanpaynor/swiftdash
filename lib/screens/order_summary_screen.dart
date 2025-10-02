import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../models/vehicle_type.dart';
import '../services/delivery_service.dart';
import '../services/directions_service.dart';
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

  Future<void> _bookDelivery() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_distance == null || _price == null) {
      ModernToast.error(
        context: context,
        message: 'Unable to calculate delivery price. Please try again.',
      );
      return;
    }

    setState(() => _isBooking = true);
    HapticFeedback.mediumImpact();

    try {
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
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        // Clear the navigation stack and go to matching screen
        context.go('/matching/${delivery.id}');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error creating delivery: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
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

  Widget _buildBookButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_distance != null && _price != null && !_isBooking) ? _bookDelivery : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
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
              _price != null 
                  ? 'Book Delivery - ₱${_price!.toStringAsFixed(2)}'
                  : 'Calculating price...',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
      ),
    );
  }
}