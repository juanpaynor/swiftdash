import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle_type.dart';
import '../models/saved_address.dart';
import '../models/delivery.dart';
import '../widgets/shared_delivery_map.dart';
import '../widgets/address_input_field.dart';
import '../widgets/save_address_dialog.dart';
import '../widgets/multi_stop_selector.dart';
import '../widgets/app_drawer.dart';
import '../widgets/modals/address_input_modal.dart';
import '../widgets/modals/contact_details_modal.dart';
import '../widgets/modals/payment_method_modal.dart';
import '../services/hybrid_address_service.dart'; // UPDATED: Use hybrid service
import '../services/saved_address_service.dart';
import '../services/mapbox_matrix_service.dart';
import '../services/delivery_service.dart';
import '../services/directions_service.dart';
import '../constants/app_theme.dart';
import '../utils/back_button_handler.dart';
import 'dart:async';

class LocationSelectionScreen extends StatefulWidget {
  final VehicleType? selectedVehicleType;
  
  const LocationSelectionScreen({
    super.key,
    this.selectedVehicleType,
  });

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final GlobalKey<State<SharedDeliveryMap>> _mapKey = GlobalKey<State<SharedDeliveryMap>>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Controllers for address inputs
  final _pickupAddressController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  
  // Location coordinates
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  
  // NEW: Enhanced delivery address objects for precise delivery information
  UnifiedDeliveryAddress? _pickupDeliveryAddress;
  UnifiedDeliveryAddress? _deliveryDeliveryAddress;

  // Saved addresses
  List<SavedAddress> _savedAddresses = [];

  // Vehicle selection
  VehicleType? _selectedVehicle;
  List<VehicleType> _availableVehicles = [];
  bool _isLoadingVehicles = true;

  // Multi-stop delivery support
  bool _isMultiStopMode = false;
  List<Map<String, dynamic>> _additionalStops = []; // List of dropoff stops
  final int _maxStops = 10; // Maximum 10 stops (1 pickup + 9 dropoffs)

  // Scheduled delivery support
  bool _isScheduled = false;
  DateTime? _scheduledPickupTime;

  // Contact details (Angkas flow) - matches DeliveryContactsScreen format
  String? _senderName;
  String? _senderPhone;
  String? _senderInstructions;
  String? _receiverName;
  String? _receiverPhone;
  String? _receiverInstructions;

  // Package details
  String _packageDescription = 'Package delivery';
  double? _packageWeightKg;
  double? _packageValue;

  // Payment details
  String _paymentBy = 'sender'; // 'sender' or 'recipient'
  String _paymentMethod = 'cash'; // 'cash' or 'maya'
  
  // Tip amount (Angkas flow)
  double _tipAmount = 0.0;

  // Traffic-aware routing (Matrix API)
  TrafficAwareRoute? _trafficRoute;
  bool _isLoadingRoute = false;
  Timer? _routeDebounceTimer;

  // Server-side pricing quote
  Map<String, dynamic>? _currentQuote;
  bool _isLoadingQuote = false;
  String? _quoteId;

  @override
  void initState() {
    super.initState();
    _selectedVehicle = widget.selectedVehicleType;
    _loadVehicleTypes();
    _loadSavedAddresses();
  }

  Future<void> _loadVehicleTypes() async {
    try {
      final response = await Supabase.instance.client
          .from('vehicle_types')
          .select()
          .eq('is_active', true)
          .order('base_price', ascending: true); // Explicitly ascending: Motorcycle → Truck

      List<VehicleType> types = (response as List)
          .map((type) => VehicleType.fromJson(type))
          .toList();
      
      setState(() {
        _availableVehicles = types; // Cheapest first: Motorcycle → Sedan → SUV → Truck
        _isLoadingVehicles = false;
        
        // If no vehicle was pre-selected, select the first one (cheapest = Motorcycle)
        if (_selectedVehicle == null && types.isNotEmpty) {
          _selectedVehicle = types.first;
        }
      });
    } catch (e) {
      setState(() => _isLoadingVehicles = false);
      // Silently fail - user can still proceed with the initial vehicle type
    }
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final addresses = await SavedAddressService.getSavedAddresses();
      setState(() {
        _savedAddresses = addresses;
      });
    } catch (e) {
      print('Error loading saved addresses: $e');
    }
  }

  bool get _canContinue {
    // Must have vehicle selected
    if (_selectedVehicle == null) {
      debugPrint('❌ Cannot continue: No vehicle selected');
      return false;
    }
    
    // For single-stop: need both pickup and delivery
    if (!_isMultiStopMode) {
      final canContinue = _pickupLatitude != null && 
          _pickupLongitude != null &&
          _deliveryLatitude != null && 
          _deliveryLongitude != null;
      
      if (!canContinue) {
        debugPrint('❌ Cannot continue: Missing locations');
        debugPrint('   - Pickup: ${_pickupLatitude != null && _pickupLongitude != null ? "✓" : "✗"}');
        debugPrint('   - Delivery: ${_deliveryLatitude != null && _deliveryLongitude != null ? "✓" : "✗"}');
      } else {
        debugPrint('✅ Can continue: All requirements met');
      }
      
      return canContinue;
    }
    
    // For multi-stop: need pickup and at least one additional stop
    final canContinue = _pickupLatitude != null && 
        _pickupLongitude != null &&
        _additionalStops.isNotEmpty;
        
    if (!canContinue) {
      debugPrint('❌ Cannot continue (multi-stop): Missing requirements');
      debugPrint('   - Pickup: ${_pickupLatitude != null && _pickupLongitude != null ? "✓" : "✗"}');
      debugPrint('   - Additional stops: ${_additionalStops.isNotEmpty ? "✓ (${_additionalStops.length})" : "✗"}');
    } else {
      debugPrint('✅ Can continue (multi-stop): All requirements met');
    }
    
    return canContinue;
  }

  int get _totalStopCount {
    if (!_isMultiStopMode) return 0;
    return 1 + _additionalStops.length; // 1 pickup + dropoffs
  }

  bool get _canAddMoreStops {
    // Allow adding stops as long as we're under the limit
    // Multi-stop mode will be enabled automatically when first stop is added
    return _totalStopCount < _maxStops;
  }

  bool get _hasDeliveryGradeAddresses =>
      _pickupDeliveryAddress?.isDeliverable == true &&
      _deliveryDeliveryAddress?.isDeliverable == true;

  // NEW ANGKAS FLOW: Collect contact details then book directly
  Future<void> _bookNowWithModals() async {
    if (!_canContinue) return;
    
    HapticFeedback.lightImpact();

    // ONLY show payment method modal (contact details already captured during address selection)
    final paymentResult = await showPaymentMethodModal(
      context: context,
      initialMethod: _paymentMethod,
      initialPaymentBy: _paymentBy,
    );

    if (paymentResult == null) return; // User cancelled

    setState(() {
      _paymentMethod = paymentResult['paymentMethod'] ?? 'cash';
      _paymentBy = paymentResult['paymentBy'] ?? 'sender';
      _packageDescription = paymentResult['packageDescription'] ?? 'Package delivery';
      _packageWeightKg = paymentResult['packageWeightKg'];
      _packageValue = paymentResult['packageValue'];
      _tipAmount = paymentResult['tipAmount'] ?? 0.0;
    });

    // Book directly (skip OrderSummaryScreen)
    await _createBooking();
  }

  // Create booking and navigate directly to matching screen
  Future<void> _createBooking() async {
    try {
      // Use server quote price (already calculated)
      final totalPrice = _currentQuote != null 
        ? _currentQuote!['total'] as double
        : _selectedVehicle!.calculatePrice(_trafficRoute!.distanceKm);

      debugPrint('💰 Creating booking with price: ₱$totalPrice (Quote ID: $_quoteId)');

      Delivery delivery;

      if (_isMultiStopMode && _additionalStops.isNotEmpty) {
        // Multi-stop delivery
        delivery = await DeliveryService.createMultiStopDelivery(
          vehicleTypeId: _selectedVehicle!.id,
          pickupAddress: _pickupAddressController.text,
          pickupLat: _pickupLatitude!,
          pickupLng: _pickupLongitude!,
          pickupContactName: _senderName!,
          pickupContactPhone: _senderPhone!,
          pickupInstructions: _senderInstructions,
          dropoffStops: _additionalStops,
          packageDescription: _packageDescription,
          packageWeightKg: _packageWeightKg,
          packageValue: _packageValue,
          totalPrice: totalPrice,
          isScheduled: _isScheduled,
          scheduledPickupTime: _scheduledPickupTime,
          paymentBy: _paymentBy,
          paymentMethod: _paymentMethod,
          paymentStatus: _paymentMethod == 'cash' ? 'pending' : 'pending',
        );
      } else {
        // Single-stop delivery
        delivery = await DeliveryService.bookDeliveryViaFunction(
          vehicleTypeId: _selectedVehicle!.id,
          pickupAddress: _pickupAddressController.text,
          pickupLat: _pickupLatitude!,
          pickupLng: _pickupLongitude!,
          pickupContactName: _senderName!,
          pickupContactPhone: _senderPhone!,
          pickupInstructions: _senderInstructions,
          dropoffAddress: _deliveryAddressController.text,
          dropoffLat: _deliveryLatitude!,
          dropoffLng: _deliveryLongitude!,
          dropoffContactName: _receiverName!,
          dropoffContactPhone: _receiverPhone!,
          dropoffInstructions: _receiverInstructions,
          packageDescription: _packageDescription,
          packageWeightKg: _packageWeightKg,
          packageValue: _packageValue,
          paymentBy: _paymentBy,
          paymentMethod: _paymentMethod,
          paymentStatus: _paymentMethod == 'cash' ? 'pending' : 'pending',
        );
      }

      // Navigate directly to matching screen
      if (mounted) {
        HapticFeedback.heavyImpact();
        context.go('/matching/${delivery.id}');
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating delivery: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Save current pickup address
  Future<void> _savePickupAddress() async {
    if (_pickupLatitude == null || _pickupLongitude == null) return;

    final result = await showDialog<SavedAddress>(
      context: context,
      builder: (context) => SaveAddressDialog(
        address: _pickupAddressController.text,
        latitude: _pickupLatitude!,
        longitude: _pickupLongitude!,
        houseNumber: _pickupDeliveryAddress?.houseNumber,
        street: _pickupDeliveryAddress?.street,
        barangay: _pickupDeliveryAddress?.barangay,
        city: _pickupDeliveryAddress?.city,
        province: _pickupDeliveryAddress?.province,
      ),
    );

    if (result != null) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.displayName} saved!'),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadSavedAddresses(); // Refresh list
    }
  }

  // Save current delivery address
  Future<void> _saveDeliveryAddress() async {
    if (_deliveryLatitude == null || _deliveryLongitude == null) return;

    final result = await showDialog<SavedAddress>(
      context: context,
      builder: (context) => SaveAddressDialog(
        address: _deliveryAddressController.text,
        latitude: _deliveryLatitude!,
        longitude: _deliveryLongitude!,
        houseNumber: _deliveryDeliveryAddress?.houseNumber,
        street: _deliveryDeliveryAddress?.street,
        barangay: _deliveryDeliveryAddress?.barangay,
        city: _deliveryDeliveryAddress?.city,
        province: _deliveryDeliveryAddress?.province,
      ),
    );

    if (result != null) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.displayName} saved!'),
          backgroundColor: const Color.fromARGB(255, 14, 168, 230),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadSavedAddresses(); // Refresh list
    }
  }

  // Use a saved address for pickup
  void _useSavedAddressForPickup(SavedAddress address) {
    HapticFeedback.selectionClick();
    setState(() {
      _pickupAddressController.text = address.fullAddress;
      _pickupLatitude = address.latitude;
      _pickupLongitude = address.longitude;
      
      // Create a UnifiedDeliveryAddress from saved address
      _pickupDeliveryAddress = UnifiedDeliveryAddress(
        fullAddress: address.fullAddress,
        latitude: address.latitude,
        longitude: address.longitude,
        houseNumber: address.houseNumber,
        street: address.street,
        barangay: address.barangay,
        city: address.city,
        province: address.province,
        sourceService: 'saved',
        types: [],
        isFromGoogle: false,
      );
    });
  }

  // Use a saved address for delivery
  void _useSavedAddressForDelivery(SavedAddress address) {
    HapticFeedback.selectionClick();
    setState(() {
      _deliveryAddressController.text = address.fullAddress;
      _deliveryLatitude = address.latitude;
      _deliveryLongitude = address.longitude;
      
      // Create a UnifiedDeliveryAddress from saved address
      _deliveryDeliveryAddress = UnifiedDeliveryAddress(
        fullAddress: address.fullAddress,
        latitude: address.latitude,
        longitude: address.longitude,
        houseNumber: address.houseNumber,
        street: address.street,
        barangay: address.barangay,
        city: address.city,
        province: address.province,
        sourceService: 'saved',
        types: [],
        isFromGoogle: false,
      );
    });
  }

  // Toggle multi-stop mode
  void _toggleMultiStopMode(bool enabled) {
    HapticFeedback.selectionClick();
    setState(() {
      _isMultiStopMode = enabled;
      
      if (enabled) {
        // Convert current delivery to first stop if available
        if (_deliveryLatitude != null && _deliveryLongitude != null) {
          _additionalStops.add({
            'address': _deliveryAddressController.text,
            'latitude': _deliveryLatitude,
            'longitude': _deliveryLongitude,
            'deliveryAddress': _deliveryDeliveryAddress,
          });
          // Clear single delivery fields
          _deliveryAddressController.clear();
          _deliveryLatitude = null;
          _deliveryLongitude = null;
          _deliveryDeliveryAddress = null;
        }
      } else {
        // Convert first stop back to single delivery if available
        if (_additionalStops.isNotEmpty) {
          final firstStop = _additionalStops.first;
          _deliveryAddressController.text = firstStop['address'];
          _deliveryLatitude = firstStop['latitude'];
          _deliveryLongitude = firstStop['longitude'];
          _deliveryDeliveryAddress = firstStop['deliveryAddress'];
        }
        _additionalStops.clear();
      }
    });
  }

  // Add a new dropoff stop
  void _addDropoffStop(String address, double lat, double lng, [UnifiedDeliveryAddress? deliveryAddress]) {
    // Enable multi-stop mode if not already enabled
    if (!_isMultiStopMode) {
      setState(() {
        _isMultiStopMode = true;
      });
    }
    
    if (!_canAddMoreStops) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum $_maxStops stops reached'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate coordinates before adding
    if (lat == 0.0 && lng == 0.0) {
      print('⚠️ WARNING: Attempting to add stop with invalid coordinates (0.0, 0.0)');
      print('  Address: $address');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid location. Please select a valid address.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      print('⚠️ WARNING: Attempting to add stop with out-of-range coordinates');
      print('  Address: $address, Lat: $lat, Lng: $lng');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid location coordinates. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print('✅ Adding stop with valid coordinates:');
    print('  Address: $address');
    print('  Coordinates: ($lat, $lng)');

    HapticFeedback.lightImpact();
    setState(() {
      // Create a new list to trigger widget rebuild detection
      _additionalStops = [
        ..._additionalStops,
        {
          'address': address,
          'latitude': lat,
          'longitude': lng,
          'deliveryAddress': deliveryAddress,
        },
      ];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stop ${_additionalStops.length} added'),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // IMPORTANT: Update map with new stops
    _updateMapForMultiStop();
  }

  // Remove a dropoff stop
  void _removeDropoffStop(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      // Create a new list to trigger widget rebuild detection
      _additionalStops = List.from(_additionalStops)..removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stop removed'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
    
    // IMPORTANT: Update map after removing stop
    _updateMapForMultiStop();
  }

  // Reorder dropoff stops
  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      // Create a new list to trigger widget rebuild detection
      final newList = List<Map<String, dynamic>>.from(_additionalStops);
      final item = newList.removeAt(oldIndex);
      newList.insert(newIndex, item);
      _additionalStops = newList;
    });
    
    // IMPORTANT: Update map after reordering stops
    _updateMapForMultiStop();
  }
  
  // Update map when multi-stop changes
  void _updateMapForMultiStop() {
    // Force map to rebuild by updating the widget tree
    // The SharedDeliveryMap will automatically update based on the new _additionalStops list
    setState(() {
      // setState triggers a rebuild, map will receive updated additionalStops
    });
  }

  // Use saved address as additional stop in multi-stop mode
  void _useSavedAddressAsStop(SavedAddress address) {
    final deliveryAddress = UnifiedDeliveryAddress(
      fullAddress: address.fullAddress,
      latitude: address.latitude,
      longitude: address.longitude,
      houseNumber: address.houseNumber,
      street: address.street,
      barangay: address.barangay,
      city: address.city,
      province: address.province,
      sourceService: 'saved',
      types: [],
      isFromGoogle: false,
    );
    
    _addDropoffStop(
      address.fullAddress,
      address.latitude,
      address.longitude,
      deliveryAddress,
    );
  }

  // Show dialog to add a new stop
  void _showAddStopDialog() {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Title
              Row(
                children: [
                  Icon(Icons.add_location_alt, color: AppTheme.primaryBlue, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add Delivery Stop',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Stop ${_additionalStops.length + 1} of $_maxStops',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Address input
              Expanded(
                child: AddressInputField(
                  label: 'Delivery Address',
                  hintText: 'Enter address or tap on map',
                  savedAddresses: _savedAddresses,
                  onSavedAddressSelected: (address) {
                    _useSavedAddressAsStop(address);
                    Navigator.pop(context);
                  },
                  // Only use delivery address callback for precise coordinates
                  onDeliveryAddressSelected: (deliveryAddress) {
                    print('📍 Add Stop Dialog - Delivery address selected:');
                    print('  Address: ${deliveryAddress.deliveryLabel}');
                    print('  Coordinates: (${deliveryAddress.latitude}, ${deliveryAddress.longitude})');
                    
                    _addDropoffStop(
                      deliveryAddress.deliveryLabel,
                      deliveryAddress.latitude,
                      deliveryAddress.longitude,
                      deliveryAddress,
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    _routeDebounceTimer?.cancel();
    super.dispose();
  }

  // Fetch traffic-aware route preview (Call #1)
  Future<void> _fetchRoutePreview() async {
    // Only fetch if we have both pickup and delivery coordinates
    if (_pickupLatitude == null || _pickupLongitude == null ||
        _deliveryLatitude == null || _deliveryLongitude == null) {
      setState(() {
        _trafficRoute = null;
      });
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      debugPrint('🚦 Fetching traffic route: pickup → delivery');
      
      final route = await MapboxMatrixService.getTrafficAwareRoute([
        [_pickupLongitude!, _pickupLatitude!],
        [_deliveryLongitude!, _deliveryLatitude!],
      ]);

      if (route != null && mounted) {
        setState(() {
          _trafficRoute = route;
          _isLoadingRoute = false;
        });

        debugPrint('✅ Route preview loaded: ${route.distanceKm.toStringAsFixed(1)}km, ${route.durationInTraffic}');
        debugPrint('📊 Traffic: ${route.hasHeavyTraffic ? "Heavy" : "Light"}');
        
        // Fetch server quote after route is loaded
        _fetchServerQuote();
      } else if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Route preview error: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  // Fetch server-side pricing quote
  Future<void> _fetchServerQuote() async {
    if (_pickupLatitude == null || _pickupLongitude == null ||
        _deliveryLatitude == null || _deliveryLongitude == null ||
        _selectedVehicle == null) {
      return;
    }

    setState(() => _isLoadingQuote = true);

    try {
      debugPrint('💰 Fetching server quote...');
      
      final quote = await DeliveryService.getQuote(
        vehicleTypeId: _selectedVehicle!.id,
        pickupLat: _pickupLatitude!,
        pickupLng: _pickupLongitude!,
        dropoffLat: _deliveryLatitude!,
        dropoffLng: _deliveryLongitude!,
        weightKg: _packageWeightKg,
      );

      if (mounted) {
        setState(() {
          _currentQuote = quote;
          _quoteId = quote['quoteId'];
          _isLoadingQuote = false;
        });

        debugPrint('✅ Server quote: ₱${quote['total']} (Quote ID: ${quote['quoteId']})');
        debugPrint('📊 Distance: ${quote['distanceKm']}km, Base: ₱${quote['base']}, Per km: ₱${quote['perKm']}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching quote: $e');
      if (mounted) {
        setState(() => _isLoadingQuote = false);
      }
    }
  }

  // Debounced route fetch (wait 2 seconds after user stops typing)
  void _debouncedRouteFetch() {
    _routeDebounceTimer?.cancel();
    _routeDebounceTimer = Timer(const Duration(seconds: 2), () {
      _fetchRoutePreview();
    });
  }

  // Build traffic dot indicator
  Widget _buildTrafficDot(Color color, double percentage) {
    if (percentage < 1) return const SizedBox.shrink();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // Build location tap button (Angkas style)
  Widget _buildLocationTapButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    String? contactName,
    String? contactPhone,
    required VoidCallback onTap,
  }) {
    final hasContact = contactName != null && contactPhone != null;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: address.contains('Tap to select')
                          ? AppTheme.textHint
                          : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasContact) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$contactName • $contactPhone',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SmartBackHandler(
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        extendBodyBehindAppBar: true,
        extendBody: true,
      body: Stack(
        children: [
          // MAP AS BACKGROUND (FULL SCREEN)
          Positioned.fill(
            child: SharedDeliveryMap(
              key: _mapKey, // Keep GlobalKey for method access
              onLocationSelected: (address, lat, lng, isPickup) async {
                // Update location state and clear old traffic data
                setState(() {
                  _trafficRoute = null; // Clear old traffic data when location changes
                  if (isPickup) {
                    _pickupAddressController.text = address;
                    _pickupLatitude = lat;
                    _pickupLongitude = lng;
                  } else {
                    _deliveryAddressController.text = address;
                    _deliveryLatitude = lat;
                    _deliveryLongitude = lng;
                  }
                });
                
                // Show contact details modal (same as address search flow)
                final contactResult = await showModalBottomSheet<Map<String, String?>>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ContactDetailsModal(
                    title: isPickup ? 'Sender Details' : 'Receiver Details',
                    initialName: isPickup ? _senderName : _receiverName,
                    initialPhone: isPickup ? _senderPhone : _receiverPhone,
                    initialNotes: isPickup ? _senderInstructions : _receiverInstructions,
                  ),
                );
                
                if (contactResult != null) {
                  setState(() {
                    if (isPickup) {
                      _senderName = contactResult['name'];
                      _senderPhone = contactResult['phone'];
                      _senderInstructions = contactResult['instructions'];
                    } else {
                      _receiverName = contactResult['name'];
                      _receiverPhone = contactResult['phone'];
                      _receiverInstructions = contactResult['instructions'];
                    }
                  });
                  debugPrint('✅ Contact details saved via map tap: ${contactResult['name']} - ${contactResult['phone']}');
                }
                
                // Fetch route preview with traffic data
                await _fetchRoutePreview();
              },
              initialPickupAddress: _pickupAddressController.text,
              initialDeliveryAddress: _deliveryAddressController.text,
              pickupLatitude: _pickupLatitude,
              pickupLongitude: _pickupLongitude,
              deliveryLatitude: _deliveryLatitude,
              deliveryLongitude: _deliveryLongitude,
              isMultiStop: _isMultiStopMode,
              additionalStops: _additionalStops,
              trafficSegments: _trafficRoute?.segments.map((segment) => {
                'coordinates': segment.coordinates,
                'congestion': segment.congestion.name,
                'distance': segment.distance,
                'duration': segment.duration,
              }).toList(),
            ),
          ),
          
          // BOTTOM SHEET - ANGKAS STYLE (15% collapsed, 80% expanded)
          DraggableScrollableSheet(
            initialChildSize: 0.30, // 15% collapsed - show pickup/delivery/button only
            minChildSize: 0.20,     // Minimum 15%
            maxChildSize: 0.90,     // Maximum 80% when expanded
            snap: true,            // Snap to specific sizes
            snapSizes: const [0.15, 0.80], // Either collapsed or expanded
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.dividerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // ===== CARD 1: VEHICLE SELECTION =====
                        Container(
                          padding: const EdgeInsets.all(16),
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
                              Text(
                                'Select Vehicle',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_isLoadingVehicles)
                                Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                  ),
                                )
                              else if (_availableVehicles.isNotEmpty)
                                SizedBox(
                                  height: 70,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _availableVehicles.length,
                                    itemBuilder: (context, index) {
                                      final vehicle = _availableVehicles[index];
                                      final isSelected = _selectedVehicle?.id == vehicle.id;
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedVehicle = vehicle;
                                          });
                                          HapticFeedback.lightImpact();
                                          // Fetch new quote with selected vehicle
                                          _fetchServerQuote();
                                        },
                                        child: Container(
                                          margin: EdgeInsets.only(
                                            right: index < _availableVehicles.length - 1 ? 12 : 0,
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            gradient: isSelected ? AppTheme.primaryGradient : null,
                                            color: isSelected ? null : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected ? Colors.transparent : AppTheme.borderColor,
                                              width: isSelected ? 0 : 1,
                                            ),
                                            boxShadow: isSelected ? [
                                              BoxShadow(
                                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ] : null,
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                vehicle.icon,
                                                color: isSelected ? Colors.white : AppTheme.primaryBlue,
                                                size: 28,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                vehicle.name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // ===== CARD 2: PICKUP & DELIVERY LOCATIONS =====
                        Container(
                          padding: const EdgeInsets.all(16),
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
                              Text(
                                'Locations',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Pickup Location Button
                              _buildLocationTapButton(
                                icon: Icons.radio_button_checked,
                                iconColor: AppTheme.primaryBlue,
                                label: 'Pickup Location',
                                address: _pickupAddressController.text.isEmpty
                                    ? 'Tap to select pickup address'
                                    : _pickupAddressController.text,
                                contactName: _senderName,
                                contactPhone: _senderPhone,
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  final result = await showDialog<UnifiedDeliveryAddress>(
                                    context: context,
                                    builder: (context) => AddressInputModal(
                                      title: 'Pickup Location',
                                      savedAddresses: _savedAddresses,
                                      initialAddress: _pickupAddressController.text.isEmpty ? null : _pickupAddressController.text,
                                    ),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      _pickupDeliveryAddress = result;
                                      _pickupAddressController.text = result.deliveryLabel;
                                      _pickupLatitude = result.latitude;
                                      _pickupLongitude = result.longitude;
                                      _trafficRoute = null; // Clear old traffic data
                                    });
                                    print('✅ Pickup address selected: ${result.deliveryLabel}');
                                    
                                    // IMPORTANT: Show contact details modal after address selection
                                    final contactResult = await showModalBottomSheet<Map<String, String?>>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => ContactDetailsModal(
                                        title: 'Sender Details',
                                        initialName: _senderName,
                                        initialPhone: _senderPhone,
                                        initialNotes: _senderInstructions,
                                      ),
                                    );
                                    
                                    if (contactResult != null) {
                                      setState(() {
                                        _senderName = contactResult['name'];
                                        _senderPhone = contactResult['phone'];
                                        _senderInstructions = contactResult['instructions'];
                                      });
                                      print('✅ Sender contact saved: $_senderName - $_senderPhone');
                                    }
                                    
                                    // Fetch route after selection
                                    _fetchRoutePreview();
                                  }
                                },
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Delivery Location Button (Always visible - first drop-off)
                              _buildLocationTapButton(
                                icon: Icons.location_on,
                                iconColor: AppTheme.errorColor,
                                label: 'Drop-off Location',
                                address: _deliveryAddressController.text.isEmpty
                                    ? 'Tap to select delivery address'
                                    : _deliveryAddressController.text,
                                contactName: _receiverName,
                                contactPhone: _receiverPhone,
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  final result = await showDialog<UnifiedDeliveryAddress>(
                                    context: context,
                                    builder: (context) => AddressInputModal(
                                      title: 'Drop-off Location',
                                      savedAddresses: _savedAddresses,
                                      initialAddress: _deliveryAddressController.text.isEmpty ? null : _deliveryAddressController.text,
                                    ),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      _deliveryDeliveryAddress = result;
                                      _deliveryAddressController.text = result.deliveryLabel;
                                      _deliveryLatitude = result.latitude;
                                      _deliveryLongitude = result.longitude;
                                      _trafficRoute = null; // Clear old traffic data
                                    });
                                    print('✅ Delivery address selected: ${result.deliveryLabel}');
                                    
                                    // IMPORTANT: Show contact details modal after address selection
                                    final contactResult = await showModalBottomSheet<Map<String, String?>>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => ContactDetailsModal(
                                        title: 'Receiver Details',
                                        initialName: _receiverName,
                                        initialPhone: _receiverPhone,
                                        initialNotes: _receiverInstructions,
                                      ),
                                    );
                                    
                                    if (contactResult != null) {
                                      setState(() {
                                        _receiverName = contactResult['name'];
                                        _receiverPhone = contactResult['phone'];
                                        _receiverInstructions = contactResult['instructions'];
                                      });
                                      print('✅ Receiver contact saved: $_receiverName - $_receiverPhone');
                                    }
                                    
                                    // Fetch route after selection
                                    _fetchRoutePreview();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        // Saved addresses (optional - outside cards)
                        if (_savedAddresses.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Saved Places',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push('/saved-addresses'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Manage',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Horizontal scrollable saved addresses
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _savedAddresses.length,
                              itemBuilder: (context, index) {
                                final address = _savedAddresses[index];
                                return _SavedAddressChip(
                                  address: address,
                                  onTap: () {
                                    // Show bottom sheet to choose pickup or delivery
                                    _showAddressTypeSelection(address);
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // ===== CARD 3: ADD STOP & MULTI-STOP =====
                        Container(
                          padding: const EdgeInsets.all(16),
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
                          child: GestureDetector(
                            onTap: _additionalStops.length < _maxStops ? () {
                              HapticFeedback.lightImpact();
                              // Enable multi-stop mode when adding first stop
                              if (!_isMultiStopMode) {
                                setState(() {
                                  _isMultiStopMode = true;
                                });
                              }
                              _showAddStopDialog();
                            } : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _additionalStops.length < _maxStops 
                                    ? AppTheme.primaryBlue.withOpacity(0.2)
                                    : AppTheme.textSecondary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: _additionalStops.length < _maxStops 
                                      ? AppTheme.primaryGradient
                                      : LinearGradient(
                                          colors: [
                                            AppTheme.textSecondary.withOpacity(0.3),
                                            AppTheme.textSecondary.withOpacity(0.3),
                                          ],
                                        ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Add Stop',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _additionalStops.length < _maxStops 
                                            ? AppTheme.textPrimary
                                            : AppTheme.textSecondary,
                                        ),
                                      ),
                                      if (_additionalStops.isNotEmpty)
                                        Text(
                                          '${_additionalStops.length} of $_maxStops stops',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (_additionalStops.length < _maxStops)
                                  Icon(
                                    Icons.chevron_right,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                              ],
                            ),
                            ),
                          ),
                        ),
                        
                        // Multi-stop stops list (if active)
                        if (_isMultiStopMode && _additionalStops.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
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
                              Expanded(
                                child: Text(
                                  'Delivery Stops',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${_additionalStops.length} of $_maxStops',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // List of stops with reorder
                          if (_additionalStops.isNotEmpty) ...[
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _additionalStops.length,
                              onReorder: _reorderStops,
                              itemBuilder: (context, index) {
                                final stop = _additionalStops[index];
                                return Container(
                                  key: ValueKey('stop_$index'),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Card(
                                    child: ListTile(
                                      leading: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.drag_handle, color: Colors.grey[400]),
                                          const SizedBox(width: 8),
                                          CircleAvatar(
                                            backgroundColor: AppTheme.primaryBlue,
                                            radius: 16,
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: Text(
                                        stop['address'],
                                        style: const TextStyle(fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () => _removeDropoffStop(index),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Add stop button (compact + button design)
                          if (_canAddMoreStops)
                            OutlinedButton.icon(
                              onPressed: _showAddStopDialog,
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              label: Text(
                                'Add Stop',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryBlue,
                                side: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          
                          // Pricing info
                          if (_selectedVehicle != null &&
                              _selectedVehicle!.additionalStopCharge != null &&
                              _additionalStops.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            MultiStopPricingInfo(
                              additionalStopCharge: _selectedVehicle!.additionalStopCharge!,
                              additionalStops: _additionalStops.length,
                            ),
                          ],
                              ],
                            ),
                          ),
                        ],
                        
                        // Traffic-aware route preview (always show when locations are set)
                        if (_pickupLatitude != null && _deliveryLatitude != null) ...[
                          const SizedBox(height: 12),
                          if (_isLoadingRoute)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryBlue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Calculating route with traffic...',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // ===== CARD 6: PRICING DISPLAY =====
                        if (_selectedVehicle != null && _trafficRoute != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryBlue.withOpacity(0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: AppTheme.primaryBlue.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedVehicle!.icon,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedVehicle!.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${_trafficRoute!.distanceKm.toStringAsFixed(1)} km',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _isLoadingQuote
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                      ),
                                    )
                                  : Text(
                                      _currentQuote != null
                                        ? '₱${_currentQuote!['total'].toStringAsFixed(2)}'
                                        : '₱${_selectedVehicle!.calculatePrice(_trafficRoute!.distanceKm).toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.info_outline,
                                  color: AppTheme.primaryBlue,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Book Now Button 🌊 NEON GRADIENT BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: _canContinue 
                                  ? AppTheme.primaryGradient // 🌊 Cyan to blue gradient
                                  : LinearGradient(
                                      colors: [
                                        Colors.grey.shade400,
                                        Colors.grey.shade500,
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _canContinue 
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00F0FF).withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: ElevatedButton(
                              onPressed: _canContinue ? _bookNowWithModals : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _canContinue 
                                    ? 'Book Now'
                                    : 'Select pickup and delivery locations',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40), // Extra space for scrolling
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Floating burger menu button (top left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: "burger_menu",
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryBlue,
              elevation: 8,
              child: const Icon(Icons.menu, size: 24),
            ),
          ),
          
          // Floating ETA pill (top center)
          if (_trafficRoute != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _trafficRoute!.durationInTraffic,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${_trafficRoute!.distanceKm.toStringAsFixed(1)} km',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Floating "My Location" button (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: "my_location",
              onPressed: _focusOnMyLocation,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryBlue,
              elevation: 8,
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),
        ],
      ),
    ));
  }

  // Focus map on user's current location
  void _focusOnMyLocation() async {
    final mapState = _mapKey.currentState as dynamic;
    if (mapState != null) {
      try {
        await mapState.focusOnUserLocation();
        HapticFeedback.lightImpact();
      } catch (e) {
        print('Error focusing on user location: $e');
        // Show a snackbar or toast to inform user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to get your location. Please check location permissions.',
                style: GoogleFonts.inter(fontSize: 14),
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }

  // Show bottom sheet to choose where to use saved address
  void _showAddressTypeSelection(SavedAddress address) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  address.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.label,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        address.shortAddress,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Use this address as:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on, color: Colors.green),
              ),
              title: Text(
                'Pickup Location',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _useSavedAddressForPickup(address);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flag, color: Colors.orange),
              ),
              title: Text(
                'Delivery Location',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _useSavedAddressForDelivery(address);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Saved address chip widget
class _SavedAddressChip extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback onTap;

  const _SavedAddressChip({
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              address.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 6),
            Text(
              address.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}