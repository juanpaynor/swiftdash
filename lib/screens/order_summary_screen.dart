import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../models/vehicle_type.dart';
import '../models/delivery.dart';
import '../models/payment_enums.dart';
import '../models/payment_config.dart';
import '../models/payment_result.dart';
import '../services/delivery_service.dart';
import '../services/directions_service.dart';
import '../services/payment_service.dart';
import '../services/multi_stop_service.dart';
import '../widgets/modern_widgets.dart';
import '../widgets/schedule_pickup_widget.dart';
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
  Map<String, dynamic>? _priceBreakdown; // For multi-stop pricing details
  
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

  // Multi-stop service
  final _multiStopService = MultiStopService();

  // Extract data from nested structure
  Map<String, dynamic> get locationData => widget.orderData['locationData'] as Map<String, dynamic>? ?? widget.orderData;
  Map<String, dynamic>? get contactData => widget.orderData['contactData'] as Map<String, dynamic>?;
  
  VehicleType get vehicleType => widget.orderData['selectedVehicleType'] as VehicleType? ?? locationData['vehicleType'] as VehicleType;
  String get pickupAddress => locationData['pickupAddress'] as String;
  double get pickupLat => locationData['pickupLat'] as double;
  double get pickupLng => locationData['pickupLng'] as double;
  
  // Multi-stop support
  bool get isMultiStop => locationData['isMultiStop'] as bool? ?? false;
  List<Map<String, dynamic>> get stops => 
      (locationData['stops'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  
  // Scheduled delivery support
  bool get isScheduled => locationData['isScheduled'] as bool? ?? false;
  DateTime? get scheduledPickupTime => locationData['scheduledPickupTime'] != null
      ? DateTime.parse(locationData['scheduledPickupTime'] as String)
      : null;
  
  // Single-stop getters (only used when not multi-stop)
  String get deliveryAddress => locationData['deliveryAddress'] as String? ?? '';
  double get deliveryLat => locationData['deliveryLat'] as double? ?? 0.0;
  double get deliveryLng => locationData['deliveryLng'] as double? ?? 0.0;
  
  // Contact data getters
  String get pickupContactName => contactData?['pickupContact']?['name'] ?? _pickupContactNameController.text;
  String get pickupContactPhone => contactData?['pickupContact']?['phone'] ?? _pickupContactPhoneController.text;
  String get pickupInstructions => contactData?['pickupContact']?['instructions'] ?? '';
  String get deliveryContactName => contactData?['deliveryContact']?['name'] ?? _deliveryContactNameController.text;
  String get deliveryContactPhone => contactData?['deliveryContact']?['phone'] ?? _deliveryContactPhoneController.text;
  String get deliveryInstructions => contactData?['deliveryContact']?['instructions'] ?? '';
  List<Map<String, String>>? get stopsContacts => contactData?['additional_stops'] as List<Map<String, String>>?;

  @override
  void initState() {
    super.initState();
    _prefillContactData();
    _calculatePriceAndDistance();
  }
  
  void _prefillContactData() {
    // Pre-fill contact fields if data came from contacts screen
    if (contactData != null) {
      final pickupContact = contactData!['pickupContact'] as Map<String, dynamic>?;
      final deliveryContact = contactData!['deliveryContact'] as Map<String, dynamic>?;
      
      if (pickupContact != null) {
        _pickupContactNameController.text = pickupContact['name'] ?? '';
        _pickupContactPhoneController.text = pickupContact['phone'] ?? '';
        _pickupInstructionsController.text = pickupContact['instructions'] ?? '';
      }
      
      if (deliveryContact != null) {
        _deliveryContactNameController.text = deliveryContact['name'] ?? '';
        _deliveryContactPhoneController.text = deliveryContact['phone'] ?? '';
        _deliveryInstructionsController.text = deliveryContact['instructions'] ?? '';
      }
    }
  }

  // Check if contact data was already collected
  bool get _hasContactData => contactData != null && 
    contactData!['pickupContact'] != null && 
    contactData!['deliveryContact'] != null &&
    contactData!['pickupContact']['name'] != null &&
    contactData!['pickupContact']['phone'] != null &&
    contactData!['deliveryContact']['name'] != null &&
    contactData!['deliveryContact']['phone'] != null;

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
    if (isMultiStop) {
      await _calculateMultiStopPrice();
    } else {
      await _calculateSingleStopPrice();
    }
  }

  Future<void> _calculateSingleStopPrice() async {
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

  Future<void> _calculateMultiStopPrice() async {
    try {
      // Prepare dropoff locations for optimization
      final dropoffLocations = stops.map((stop) => {
        'lat': stop['latitude'] as double,
        'lng': stop['longitude'] as double,
      }).toList();

      // Validate all coordinates before optimization
      print('🔍 VALIDATING COORDINATES:');
      print('  Pickup: ($pickupLat, $pickupLng)');
      for (int i = 0; i < dropoffLocations.length; i++) {
        final lat = dropoffLocations[i]['lat']!;
        final lng = dropoffLocations[i]['lng']!;
        print('  Stop ${i + 1}: ($lat, $lng)');
        
        // Check for invalid coordinates
        if (lat == 0.0 && lng == 0.0) {
          throw Exception('Stop ${i + 1} has invalid coordinates (0.0, 0.0)');
        }
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
          throw Exception('Stop ${i + 1} has out-of-range coordinates');
        }
      }

      // Optimize route
      final optimizationResult = await _multiStopService.optimizeRoute(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLocations: dropoffLocations,
      );

      print('🔍 MAPBOX OPTIMIZATION RESULT:');
      print('  Success: ${optimizationResult['success']}');
      print('  Raw distance: ${optimizationResult['distance']}');
      print('  Raw distance type: ${optimizationResult['distance']?.runtimeType}');

      double distanceKm = 0.0;
      if (optimizationResult['success'] == true) {
        // Distance from Mapbox is in meters
        final rawDistance = optimizationResult['distance'] as num;
        distanceKm = rawDistance / 1000;
        
        print('  Distance in KM (after /1000): $distanceKm');
        
        // Sanity check: Manila area deliveries shouldn't exceed 500 km
        if (distanceKm > 500) {
          print('⚠️ WARNING: Suspicious distance: $distanceKm km');
          print('⚠️ This might be a unit conversion error!');
        }
      } else {
        // Fallback: calculate simple sum of distances
        print('  Using fallback distance calculation...');
        distanceKm = await _calculateTotalDistanceFallback();
        print('  Fallback distance: $distanceKm km');
      }

      // Calculate price with multi-stop charges
      final priceResult = await _multiStopService.calculateMultiStopPrice(
        vehicleTypeId: vehicleType.id,
        distanceKm: distanceKm,
        numberOfDropoffs: stops.length,
      );

      print('💰 PRICE CALCULATION RESULT:');
      print('  Vehicle: ${vehicleType.name}');
      print('  Distance: $distanceKm km');
      print('  Number of dropoffs: ${stops.length}');
      print('  Success: ${priceResult['success']}');
      print('  Total Price: ${priceResult['totalPrice']}');
      if (priceResult['breakdown'] != null) {
        print('  Breakdown:');
        print('    Base: ${priceResult['breakdown']['base']}');
        print('    Distance: ${priceResult['breakdown']['distance']}');
        print('    Additional Stops: ${priceResult['breakdown']['additionalStopsTotal']}');
      }

      if (priceResult['success'] == true) {
        setState(() {
          _distance = distanceKm;
          _price = priceResult['totalPrice'];
          _priceBreakdown = priceResult['breakdown'];
          _isLoading = false;
        });
      } else {
        throw Exception('Price calculation failed');
      }
    } catch (e) {
      print('Multi-stop price calculation error: $e');
      if (mounted) {
        String errorMessage = 'Unable to calculate multi-stop delivery price. Please try again.';
        
        // Provide more specific error messages
        if (e.toString().contains('invalid coordinates')) {
          errorMessage = 'One or more delivery locations are invalid. Please check all addresses.';
        } else if (e.toString().contains('Mapbox')) {
          errorMessage = 'Unable to calculate route. Please check your internet connection.';
        }
        
        ModernToast.error(
          context: context,
          message: errorMessage,
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<double> _calculateTotalDistanceFallback() async {
    double total = 0.0;
    
    print('🔄 FALLBACK DISTANCE CALCULATION:');
    
    // Distance from pickup to first stop
    if (stops.isNotEmpty) {
      final firstStop = stops.first;
      final firstStopLat = firstStop['latitude'] as double;
      final firstStopLng = firstStop['longitude'] as double;
      
      // Validate coordinates
      if (firstStopLat == 0.0 && firstStopLng == 0.0) {
        print('  ⚠️ First stop has invalid coordinates (0.0, 0.0)!');
        throw Exception('Invalid coordinates detected in stops');
      }
      
      print('  Pickup ($pickupLat, $pickupLng) → Stop 1 ($firstStopLat, $firstStopLng)');
      final segment1Distance = await DirectionsService.getDistance(
        startLat: pickupLat,
        startLng: pickupLng,
        endLat: firstStopLat,
        endLng: firstStopLng,
      );
      print('    Distance: $segment1Distance km');
      total += segment1Distance;
    }
    
    // Distance between stops
    for (int i = 0; i < stops.length - 1; i++) {
      final currentStop = stops[i];
      final nextStop = stops[i + 1];
      
      final currentLat = currentStop['latitude'] as double;
      final currentLng = currentStop['longitude'] as double;
      final nextLat = nextStop['latitude'] as double;
      final nextLng = nextStop['longitude'] as double;
      
      // Validate coordinates
      if ((currentLat == 0.0 && currentLng == 0.0) || (nextLat == 0.0 && nextLng == 0.0)) {
        print('  ⚠️ Stop ${i + 1} or ${i + 2} has invalid coordinates!');
        throw Exception('Invalid coordinates detected in stops');
      }
      
      print('  Stop ${i + 1} ($currentLat, $currentLng) → Stop ${i + 2} ($nextLat, $nextLng)');
      final segmentDistance = await DirectionsService.getDistance(
        startLat: currentLat,
        startLng: currentLng,
        endLat: nextLat,
        endLng: nextLng,
      );
      print('    Distance: $segmentDistance km');
      total += segmentDistance;
    }
    
    print('  ═══════════════════════');
    print('  TOTAL FALLBACK DISTANCE: $total km');
    
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              'Order Summary',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Step 3 of 3',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        // Add progress indicator
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: LinearProgressIndicator(
              value: 1.0, // Step 3 of 3
              backgroundColor: AppTheme.dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              minHeight: 3,
            ),
          ),
        ),
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
                    
                    // Scheduled Pickup Info
                    if (isScheduled && scheduledPickupTime != null) ...[
                      SchedulePickupInfo(scheduledTime: scheduledPickupTime!),
                      const SizedBox(height: 20),
                    ],
                    
                    // Price Breakdown
                    _buildPriceBreakdownCard(),
                    const SizedBox(height: 24),
                    
                    // Contact Information - only show if not collected in previous screen
                    if (!_hasContactData) ...[
                      _buildContactSection(),
                      const SizedBox(height: 24),
                    ] else ...[
                      _buildContactSummaryCard(),
                      const SizedBox(height: 24),
                    ],
                    
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  vehicleType.icon,
                  color: AppTheme.primaryBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicleType.name,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Max ${vehicleType.maxWeightKg}kg capacity',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_distance != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_distance!.toStringAsFixed(1)} km',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ ${(_distance! * 2.5 + 10).round()} mins', // Rough ETA calculation
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          
          // Route visualization with connecting line
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 40,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.successColor,
                              AppTheme.errorColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.errorColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.successColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.my_location,
                                    size: 16,
                                    color: AppTheme.successColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pickup Location',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                pickupAddress,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Single delivery location or multi-stop list
                        if (!isMultiStop) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.errorColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: AppTheme.errorColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delivery Location',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  deliveryAddress,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Multi-stop display
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryBlue.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.route,
                                      size: 16,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Multi-Stop Delivery',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${stops.length} stops',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...stops.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final stop = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppTheme.primaryBlue,
                                          child: Text(
                                            '${index + 1}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            stop['address'] as String,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
          
          // Multi-stop or single-stop pricing
          if (isMultiStop && _priceBreakdown != null) ...[
            _buildPriceRow('Base Fee', '₱${_priceBreakdown!['base'].toStringAsFixed(2)}'),
            _buildPriceRow(
              'Distance Fee (${_priceBreakdown!['distanceKm'].toStringAsFixed(1)} km × ₱${_priceBreakdown!['pricePerKm'].toStringAsFixed(0)})',
              '₱${_priceBreakdown!['distance'].toStringAsFixed(2)}',
            ),
            if (_priceBreakdown!['additionalStops'] > 0)
              _buildPriceRow(
                'Additional Stops (${_priceBreakdown!['additionalStops']} × ₱${_priceBreakdown!['additionalStopCharge'].toStringAsFixed(0)})',
                '₱${_priceBreakdown!['additionalStopsTotal'].toStringAsFixed(2)}',
                highlight: true,
              ),
            _buildPriceRow('VAT (12%)', '₱${(_price! * 0.12 / 1.12).toStringAsFixed(2)}'),
          ] else
            ..._buildSingleStopPricing(),
          
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

  List<Widget> _buildSingleStopPricing() {
    final subtotal = vehicleType.calculatePriceBeforeVAT(_distance!);
    final vat = vehicleType.calculateVAT(_distance!);
    final distanceFee = subtotal - vehicleType.basePrice;
    
    return [
      _buildPriceRow('Base Fee', '₱${vehicleType.basePrice.toStringAsFixed(2)}'),
      _buildPriceRow('Distance Fee (${_distance!.toStringAsFixed(1)} km)', '₱${distanceFee.toStringAsFixed(2)}'),
      _buildPriceRow('VAT (12%)', '₱${vat.toStringAsFixed(2)}'),
    ];
  }

  Widget _buildPriceRow(String label, String amount, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: highlight ? AppTheme.primaryBlue : AppTheme.textSecondary,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: highlight ? AppTheme.primaryBlue : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSummaryCard() {
    final pickupContact = contactData?['pickupContact'] as Map<String, dynamic>?;
    final deliveryContact = contactData?['deliveryContact'] as Map<String, dynamic>?;
    final stopsContacts = contactData?['additional_stops'] as List?;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                Icons.contacts,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Contact Information',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Pickup Contact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.upload_outlined, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Pickup Contact',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      pickupContact?['name'] ?? 'No name provided',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      pickupContact?['phone'] ?? 'No phone provided',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (pickupContact?['instructions'] != null && pickupContact!['instructions'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pickupContact['instructions'],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Delivery Contact
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.download_outlined, size: 16, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Delivery Contact',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      deliveryContact?['name'] ?? 'No name provided',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      deliveryContact?['phone'] ?? 'No phone provided',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (deliveryContact?['instructions'] != null && deliveryContact!['instructions'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deliveryContact['instructions'],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Additional stops contacts for multi-stop
          if (isMultiStop && stopsContacts != null && stopsContacts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...stopsContacts.asMap().entries.map((entry) {
              final index = entry.key;
              final contact = entry.value as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stop ${index + 2}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${contact['name']} • ${contact['phone']}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          const SizedBox(height: 12),
          
          // Edit button
          TextButton.icon(
            onPressed: () {
              // Go back to contacts screen to edit
              context.pop();
            },
            icon: Icon(Icons.edit, size: 16, color: AppTheme.primaryBlue),
            label: Text(
              'Edit Contacts',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.contacts_rounded,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Contact Information',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        
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
          hintText: '+63 9XX XXX XXXX',
          controller: _pickupContactPhoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Phone number is required';
            // Basic Philippine number validation
            final cleanNumber = v!.replaceAll(RegExp(r'[^\d+]'), '');
            if (!cleanNumber.startsWith('+63') && !cleanNumber.startsWith('09')) {
              return 'Please enter a valid Philippine number';
            }
            if (cleanNumber.length < 11) return 'Phone number too short';
            return null;
          },
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
          hintText: '+63 9XX XXX XXXX',
          controller: _deliveryContactPhoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) {
            if (v?.isEmpty ?? true) return 'Phone number is required';
            // Basic Philippine number validation
            final cleanNumber = v!.replaceAll(RegExp(r'[^\d+]'), '');
            if (!cleanNumber.startsWith('+63') && !cleanNumber.startsWith('09')) {
              return 'Please enter a valid Philippine number';
            }
            if (cleanNumber.length < 11) return 'Phone number too short';
            return null;
          },
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
      ),
    );
  }

  Widget _buildPackageSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: AppTheme.infoColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Package Details',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Package size guidelines
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.infoColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.infoColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.infoColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Max weight: ${vehicleType.maxWeightKg}kg • Please ensure package is properly secured',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
        
        ModernTextField(
          label: 'Package Description',
          hintText: 'e.g., Documents, Food, Electronics',
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
      ),
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
    final buttonColor = isDigitalPayment ? AppTheme.primaryBlue : AppTheme.successColor;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: buttonColor.withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_distance != null && _price != null && !_isBooking) ? _handleBookDelivery : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: _isBooking 
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Processing...',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDigitalPayment ? Icons.payment : Icons.local_shipping,
                    size: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    buttonText,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
    // Race condition protection - prevent multiple simultaneous booking attempts
    if (_isBooking) {
      debugPrint('⚠️ Booking already in progress, ignoring duplicate request');
      return;
    }
    
    setState(() => _isBooking = true);
    
    try {
      // Only validate form if contact data wasn't collected in previous screen
      if (!_hasContactData && !_formKey.currentState!.validate()) {
        ModernToast.error(
          context: context,
          message: 'Please fill in all required fields',
        );
        setState(() => _isBooking = false);
        return;
      }
      
      // Validate that we have contact information (either from form or previous screen)
      if (!_hasContactData && 
          (_pickupContactNameController.text.trim().isEmpty || 
           _pickupContactPhoneController.text.trim().isEmpty ||
           _deliveryContactNameController.text.trim().isEmpty ||
           _deliveryContactPhoneController.text.trim().isEmpty)) {
        ModernToast.error(
          context: context,
          message: 'Please provide all contact information',
        );
        setState(() => _isBooking = false);
        return;
      }

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
            // Show payment failure dialog with retry options
            final action = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.errorColor, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Payment Failed',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paymentResult?.statusMessage ?? 'An error occurred during payment processing',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'What would you like to do?',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'change'),
                    child: Text(
                      'Change Method',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
            
            // Handle user choice
            if (action == 'retry') {
              // Retry same payment method
              HapticFeedback.lightImpact();
              return _handleBookDelivery();
            } else if (action == 'change') {
              // User can change payment method (stay on screen)
              HapticFeedback.lightImpact();
              ModernToast.info(
                context: context,
                message: 'Please select a different payment method',
              );
            }
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
      late Delivery delivery;
      
      // Get contact names/phones from either contactData or text controllers
      final pickupName = contactData?['pickupContact']?['name'] ?? _pickupContactNameController.text;
      final pickupPhone = contactData?['pickupContact']?['phone'] ?? _pickupContactPhoneController.text;
      
      // Use different methods for single-stop vs multi-stop deliveries
      if (isMultiStop && stops.isNotEmpty) {
        // Build dropoff stops with contact info
        final List<Map<String, dynamic>> enrichedStops = [];
        for (int i = 0; i < stops.length; i++) {
          final stop = Map<String, dynamic>.from(stops[i]);
          
          // Add contact info from contactData
          if (contactData != null) {
            final stopsContactsList = contactData!['additional_stops'] as List?;
            if (stopsContactsList != null && i < stopsContactsList.length) {
              final contactInfo = stopsContactsList[i] as Map<String, dynamic>;
              stop['contactName'] = contactInfo['name'];
              stop['contactPhone'] = contactInfo['phone'];
            }
          }
          
          enrichedStops.add(stop);
        }
        
        // Multi-stop delivery
        delivery = await DeliveryService.createMultiStopDelivery(
          vehicleTypeId: vehicleType.id,
          pickupAddress: pickupAddress,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          pickupContactName: pickupName,
          pickupContactPhone: pickupPhone,
          pickupInstructions: _pickupInstructionsController.text.isNotEmpty
              ? _pickupInstructionsController.text
              : null,
          dropoffStops: enrichedStops,
          packageDescription: _packageDescriptionController.text,
          packageWeightKg: double.tryParse(_packageWeightController.text),
          packageValue: double.tryParse(_packageValueController.text),
          totalPrice: _price ?? 0.0,
          // Scheduling
          isScheduled: isScheduled,
          scheduledPickupTime: scheduledPickupTime,
          // Payment information
          paymentBy: _selectedPaymentBy.name,
          paymentMethod: _selectedPaymentMethod.name,
          paymentStatus: paymentResult.status.name,
          mayaCheckoutId: paymentResult.checkoutId,
          mayaPaymentId: paymentResult.paymentId,
          paymentReference: paymentResult.paymentId ?? paymentResult.checkoutId,
          paymentMetadata: paymentResult.transactionData,
        );
      } else {
        // Get delivery contact from contactData or text controller
        final deliveryName = contactData?['deliveryContact']?['name'] ?? _deliveryContactNameController.text;
        final deliveryPhone = contactData?['deliveryContact']?['phone'] ?? _deliveryContactPhoneController.text;
        
        // Single-stop delivery - use existing function
        delivery = await DeliveryService.bookDeliveryViaFunction(
          vehicleTypeId: vehicleType.id,
          pickupAddress: pickupAddress,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          pickupContactName: pickupName,
          pickupContactPhone: pickupPhone,
          pickupInstructions: _pickupInstructionsController.text.isNotEmpty
              ? _pickupInstructionsController.text
              : null,
          dropoffAddress: deliveryAddress,
          dropoffLat: deliveryLat,
          dropoffLng: deliveryLng,
          dropoffContactName: deliveryName,
          dropoffContactPhone: deliveryPhone,
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
      }
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        
        // Show success message based on payment type
        final message = isMultiStop 
            ? 'Multi-stop delivery booked! Finding driver...'
            : 'Delivery booked! Finding driver...';
            
        if (paymentResult.isSuccess && _selectedPaymentMethod.isDigital) {
          ModernToast.success(
            context: context,
            message: 'Payment successful! $message',
          );
        } else if (_selectedPaymentMethod == PaymentMethod.cash) {
          ModernToast.success(
            context: context,
            message: message,
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