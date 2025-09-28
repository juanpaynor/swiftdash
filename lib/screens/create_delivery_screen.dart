import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../models/vehicle_type.dart';
import '../widgets/map_address_picker.dart';
import '../widgets/mapbox_address_picker_facade.dart';
import '../config/env.dart';
import '../widgets/modern_widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/delivery_service.dart';
import '../constants/app_theme.dart';

class CreateDeliveryScreen extends StatefulWidget {
  const CreateDeliveryScreen({super.key});

  @override
  State<CreateDeliveryScreen> createState() => _CreateDeliveryScreenState();
}

class _CreateDeliveryScreenState extends State<CreateDeliveryScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  List<VehicleType> _vehicleTypes = [];
  bool _isLoading = true;
  VehicleType? _selectedVehicleType;
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late AnimationController _stepAnimationController;

  // Form controllers
  final _pickupAddressController = TextEditingController();
  final _pickupContactNameController = TextEditingController();
  final _pickupContactPhoneController = TextEditingController();
  final _pickupInstructionsController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _deliveryContactNameController = TextEditingController();
  final _deliveryContactPhoneController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  final _packageDescriptionController = TextEditingController();
  final _packageWeightController = TextEditingController();
  final _packageValueController = TextEditingController();

  // Location coordinates
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  double? _distance;
  double? _price;

  LatLng? get _pickupLocation => _pickupLatitude != null && _pickupLongitude != null 
      ? LatLng(_pickupLatitude!, _pickupLongitude!)
      : null;

  LatLng? get _deliveryLocation => _deliveryLatitude != null && _deliveryLongitude != null
      ? LatLng(_deliveryLatitude!, _deliveryLongitude!)
      : null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.animationMedium,
      vsync: this,
    );
    _stepAnimationController = AnimationController(
      duration: AppTheme.animationSlow,
      vsync: this,
    );
    _loadVehicleTypes();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stepAnimationController.dispose();
    _pickupAddressController.dispose();
    _pickupContactNameController.dispose();
    _pickupContactPhoneController.dispose();
    _pickupInstructionsController.dispose();
    _deliveryAddressController.dispose();
    _deliveryContactNameController.dispose();
    _deliveryContactPhoneController.dispose();
    _deliveryInstructionsController.dispose();
    _packageDescriptionController.dispose();
    _packageWeightController.dispose();
    _packageValueController.dispose();
    super.dispose();
  }

  void _updatePrice() {
    if (_selectedVehicleType != null && _distance != null) {
      setState(() {
        _price = _selectedVehicleType!.calculatePrice(_distance!);
      });
    }
  }

  Future<void> _loadVehicleTypes() async {
    try {
      final response = await Supabase.instance.client
          .from('vehicle_types')
          .select()
          .eq('is_active', true)
          .order('base_price');

      setState(() {
        _vehicleTypes = (response as List)
            .map((type) => VehicleType.fromJson(type))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error loading vehicle types: $e',
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createDelivery() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedVehicleType == null) {
      ModernToast.error(
        context: context,
        message: 'Please select a vehicle type',
      );
      return;
    }

    if (_pickupLocation == null || _deliveryLocation == null) {
      ModernToast.error(
        context: context,
        message: 'Please select both pickup and delivery locations',
      );
      return;
    }

    if (_distance == null || _price == null) {
      ModernToast.error(
        context: context,
        message: 'Unable to calculate delivery distance and price',
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final delivery = await DeliveryService.bookDeliveryViaFunction(
        vehicleTypeId: _selectedVehicleType!.id,
        pickupAddress: _pickupAddressController.text,
        pickupLat: _pickupLatitude!,
        pickupLng: _pickupLongitude!,
        pickupContactName: _pickupContactNameController.text,
        pickupContactPhone: _pickupContactPhoneController.text,
        pickupInstructions: _pickupInstructionsController.text.isNotEmpty
            ? _pickupInstructionsController.text
            : null,
        dropoffAddress: _deliveryAddressController.text,
        dropoffLat: _deliveryLatitude!,
        dropoffLng: _deliveryLongitude!,
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
        // Navigate to matching screen with the delivery ID
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _maybeRequestQuote() async {
    if (_selectedVehicleType == null || _pickupLocation == null || _deliveryLocation == null) return;
    try {
      final data = await DeliveryService.getQuote(
        vehicleTypeId: _selectedVehicleType!.id,
        pickupLat: _pickupLatitude!,
        pickupLng: _pickupLongitude!,
        dropoffLat: _deliveryLatitude!,
        dropoffLng: _deliveryLongitude!,
        weightKg: double.tryParse(_packageWeightController.text),
      );
      setState(() {
        _distance = (data['distanceKm'] as num?)?.toDouble();
        _price = (data['total'] as num?)?.toDouble();
      });
    } catch (_) {
      _updatePrice();
    }
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _stepAnimationController.forward();
    } else {
      _createDelivery();
    }
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _stepAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _vehicleTypes.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                ),
                SizedBox(height: AppTheme.spacing20),
                Text(
                  'Loading vehicle types...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowLight,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppTheme.textPrimary,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              try {
                context.pop();
              } catch (e) {
                context.go('/home');
              }
            },
          ),
        ),
        title: Text(
          'Create Delivery',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Column(
          children: [
            // Step Indicator
            _buildStepIndicator(),
            
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.spacing20),
                child: Form(
                  key: _formKey,
                  child: _buildCurrentStep(),
                ),
              ),
            ),
            
            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacing20),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing24,
        vertical: AppTheme.spacing16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? AppTheme.primaryBlue 
                        : AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          )
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : AppTheme.textTertiary,
                            ),
                          ),
                  ),
                ),
                if (index < 3) ...[
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isCompleted 
                            ? AppTheme.primaryBlue 
                            : AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    ).animate().slideY(begin: -0.2).fadeIn();
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildVehicleSelection();
      case 1:
        return _buildPickupDetails();
      case 2:
        return _buildDeliveryDetails();
      case 3:
        return _buildPackageDetails();
      default:
        return Container();
    }
  }

  Widget _buildVehicleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Vehicle',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the perfect vehicle for your delivery needs',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        
        ..._vehicleTypes.asMap().entries.map((entry) {
          final index = entry.key;
          final type = entry.value;
          return ModernVehicleCard(
            vehicleType: type,
            isSelected: _selectedVehicleType?.id == type.id,
            onSelect: () {
              setState(() => _selectedVehicleType = type);
              _updatePrice();
              _maybeRequestQuote();
              HapticFeedback.selectionClick();
            },
          ).animate(delay: (100 * index).milliseconds).slideX(begin: 0.2).fadeIn();
        }),
        
        if (_price != null && _distance != null) ...[
          const SizedBox(height: AppTheme.spacing24),
          _buildPriceCard(),
        ],
      ],
    );
  }

  Widget _buildPickupDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pickup Details',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Where should we pick up your package?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        
        (Env.mapProvider == 'mapbox'
            ? MapboxAddressPicker(
                label: 'Pickup Address',
                initialAddress: _pickupAddressController.text,
                isPickup: true,
                otherLocation: _deliveryLocation,
                onLocationSelected: (address, lat, lng, distance, otherLocation) {
                  setState(() {
                    _pickupAddressController.text = address;
                    _pickupLatitude = lat;
                    _pickupLongitude = lng;
                    if (distance != null) {
                      _distance = distance;
                      _updatePrice();
                    }
                  });
                  _maybeRequestQuote();
                },
              )
            : MapAddressPicker(
          label: 'Pickup Address',
          initialAddress: _pickupAddressController.text,
          isPickup: true,
          otherLocation: _deliveryLocation,
          onLocationSelected: (address, lat, lng, distance, otherLocation) {
            setState(() {
              _pickupAddressController.text = address;
              _pickupLatitude = lat;
              _pickupLongitude = lng;
              if (distance != null) {
                _distance = distance;
                _updatePrice();
              }
            });
            _maybeRequestQuote();
          },
        )).animate().slideY(begin: 0.2).fadeIn(),
        
        const SizedBox(height: AppTheme.spacing20),
        
        ModernTextField(
          label: 'Contact Name',
          hintText: 'Who will hand over the package?',
          controller: _pickupContactNameController,
          prefixIcon: Icons.person_outline,
          validator: (v) => v?.isEmpty ?? true ? 'Contact name is required' : null,
        ).animate(delay: 100.milliseconds).slideX(begin: -0.2).fadeIn(),
        
        const SizedBox(height: AppTheme.spacing16),
        
        ModernTextField(
          label: 'Contact Phone',
          hintText: '+1 (555) 123-4567',
          controller: _pickupContactPhoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) => v?.isEmpty ?? true ? 'Phone number is required' : null,
        ).animate(delay: 150.milliseconds).slideX(begin: 0.2).fadeIn(),
        
        const SizedBox(height: AppTheme.spacing16),
        
        ModernTextField(
          label: 'Special Instructions (Optional)',
          hintText: 'Building access, floor, etc.',
          controller: _pickupInstructionsController,
          prefixIcon: Icons.note_outlined,
          maxLines: 3,
        ).animate(delay: 200.milliseconds).slideY(begin: 0.2).fadeIn(),
      ],
    );
  }

  Widget _buildDeliveryDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Details',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Where should we deliver your package?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        
        (Env.mapProvider == 'mapbox'
            ? MapboxAddressPicker(
                label: 'Delivery Address',
                initialAddress: _deliveryAddressController.text,
                isPickup: false,
                otherLocation: _pickupLocation,
                onLocationSelected: (address, lat, lng, distance, otherLocation) {
                  setState(() {
                    _deliveryAddressController.text = address;
                    _deliveryLatitude = lat;
                    _deliveryLongitude = lng;
                    if (distance != null) {
                      _distance = distance;
                      _updatePrice();
                    }
                  });
                  _maybeRequestQuote();
                },
              )
            : MapAddressPicker(
          label: 'Delivery Address',
          initialAddress: _deliveryAddressController.text,
          isPickup: false,
          otherLocation: _pickupLocation,
          onLocationSelected: (address, lat, lng, distance, otherLocation) {
            setState(() {
              _deliveryAddressController.text = address;
              _deliveryLatitude = lat;
              _deliveryLongitude = lng;
              if (distance != null) {
                _distance = distance;
                _updatePrice();
              }
            });
            _maybeRequestQuote();
          },
        )).animate().slideY(begin: 0.2).fadeIn(),
        
        const SizedBox(height: AppTheme.spacing20),
        
        ModernTextField(
          label: 'Contact Name',
          hintText: 'Who will receive the package?',
          controller: _deliveryContactNameController,
          prefixIcon: Icons.person_outline,
          validator: (v) => v?.isEmpty ?? true ? 'Contact name is required' : null,
        ).animate(delay: 100.milliseconds).slideX(begin: -0.2).fadeIn(),
        
        const SizedBox(height: AppTheme.spacing16),
        
        ModernTextField(
          label: 'Contact Phone',
          hintText: '+1 (555) 123-4567',
          controller: _deliveryContactPhoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) => v?.isEmpty ?? true ? 'Phone number is required' : null,
        ).animate(delay: 150.milliseconds).slideX(begin: 0.2).fadeIn(),
        
        const SizedBox(height: AppTheme.spacing16),
        
        ModernTextField(
          label: 'Special Instructions (Optional)',
          hintText: 'Building access, floor, etc.',
          controller: _deliveryInstructionsController,
          prefixIcon: Icons.note_outlined,
          maxLines: 3,
        ).animate(delay: 200.milliseconds).slideY(begin: 0.2).fadeIn(),
      ],
    );
  }

  Widget _buildPackageDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Package Information',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us about what you\'re sending',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        
        ModernTextField(
          label: 'Package Description',
          hintText: 'What are you sending?',
          controller: _packageDescriptionController,
          prefixIcon: Icons.inventory_2_outlined,
          validator: (v) => v?.isEmpty ?? true ? 'Package description is required' : null,
        ).animate().slideX(begin: -0.2).fadeIn(),
        
        const SizedBox(height: AppTheme.spacing16),
        
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
                  if (_selectedVehicleType != null && weight > _selectedVehicleType!.maxWeightKg) {
                    return 'Exceeds vehicle capacity (${_selectedVehicleType!.maxWeightKg}kg)';
                  }
                  return null;
                },
              ).animate(delay: 50.milliseconds).slideX(begin: -0.2).fadeIn(),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: ModernTextField(
                label: 'Value (\$ - Optional)',
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
              ).animate(delay: 100.milliseconds).slideX(begin: 0.2).fadeIn(),
            ),
          ],
        ),
        
        if (_price != null && _distance != null) ...[
          const SizedBox(height: AppTheme.spacing24),
          _buildPriceCard(),
        ],
      ],
    );
  }

  Widget _buildPriceCard() {
    return ModernCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Quote',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Distance: ${_distance!.toStringAsFixed(1)} km',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          const Divider(color: AppTheme.dividerColor),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Base Price',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'Distance Fee',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${_selectedVehicleType!.basePrice.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '\$${(_price! - _selectedVehicleType!.basePrice).toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          const Divider(color: AppTheme.dividerColor),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Price',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '\$${_price!.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.95, 0.95)).fadeIn();
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.spacing20,
        right: AppTheme.spacing20,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacing16,
        top: AppTheme.spacing16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowMedium,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: ModernButton(
                  text: 'Previous',
                  onPressed: _previousStep,
                  isSecondary: true,
                  icon: Icons.arrow_back_rounded,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
            ],
            Expanded(
              flex: _currentStep == 0 ? 1 : 2,
              child: ModernButton(
                text: _currentStep == 3 ? 'Create Delivery' : 'Continue',
                onPressed: _nextStep,
                isLoading: _isLoading,
                icon: _currentStep == 3 ? Icons.send_rounded : Icons.arrow_forward_rounded,
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1.0);
  }
}

class ModernVehicleCard extends StatelessWidget {
  final VehicleType vehicleType;
  final bool isSelected;
  final VoidCallback onSelect;

  const ModernVehicleCard({
    super.key,
    required this.vehicleType,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.dividerColor.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected 
            ? [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ] 
            : [
                BoxShadow(
                  color: AppTheme.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryBlue.withOpacity(0.1) 
                        : AppTheme.dividerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radius16),
                  ),
                  child: Icon(
                    vehicleType.icon,
                    size: 32,
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            vehicleType.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                borderRadius: BorderRadius.circular(AppTheme.radius8),
                              ),
                              child: Text(
                                'Selected',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (vehicleType.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          vehicleType.description!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.infoLight,
                              borderRadius: BorderRadius.circular(AppTheme.radius8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.fitness_center,
                                  size: 12,
                                  color: AppTheme.infoColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Max ${vehicleType.maxWeightKg}kg',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.infoColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${vehicleType.basePrice.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '+\$${vehicleType.pricePerKm.toStringAsFixed(2)}/km',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}