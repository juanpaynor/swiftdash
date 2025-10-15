import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../models/vehicle_type.dart';
import '../models/saved_address.dart';
import '../widgets/shared_delivery_map.dart';
import '../widgets/address_input_field.dart';
import '../widgets/save_address_dialog.dart';
import '../widgets/multi_stop_selector.dart';
import '../widgets/schedule_pickup_widget.dart';
import '../services/hybrid_address_service.dart'; // UPDATED: Use hybrid service
import '../services/saved_address_service.dart';
import '../constants/app_theme.dart';
import '../utils/back_button_handler.dart';

class LocationSelectionScreen extends StatefulWidget {
  final VehicleType selectedVehicleType;
  
  const LocationSelectionScreen({
    super.key,
    required this.selectedVehicleType,
  });

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final GlobalKey<State<SharedDeliveryMap>> _mapKey = GlobalKey<State<SharedDeliveryMap>>();
  
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

  // Multi-stop delivery support
  bool _isMultiStopMode = false;
  List<Map<String, dynamic>> _additionalStops = []; // List of dropoff stops
  final int _maxStops = 10; // Maximum 10 stops (1 pickup + 9 dropoffs)

  // Scheduled delivery support
  bool _isScheduled = false;
  DateTime? _scheduledPickupTime;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
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
    // For single-stop: need both pickup and delivery
    if (!_isMultiStopMode) {
      return _pickupLatitude != null && 
          _pickupLongitude != null &&
          _deliveryLatitude != null && 
          _deliveryLongitude != null;
    }
    
    // For multi-stop: need pickup and at least one additional stop
    return _pickupLatitude != null && 
        _pickupLongitude != null &&
        _additionalStops.isNotEmpty;
  }

  int get _totalStopCount {
    if (!_isMultiStopMode) return 0;
    return 1 + _additionalStops.length; // 1 pickup + dropoffs
  }

  bool get _canAddMoreStops {
    return _isMultiStopMode && _totalStopCount < _maxStops;
  }

  bool get _hasDeliveryGradeAddresses =>
      _pickupDeliveryAddress?.isDeliverable == true &&
      _deliveryDeliveryAddress?.isDeliverable == true;

  void _continueToSummary() {
    if (!_canContinue) {
      // This shouldn't happen since button is disabled, but just in case
      return;
    }
    
    HapticFeedback.lightImpact();
    
    // Prepare location data based on mode
    final Map<String, dynamic> locationData = {
      'vehicleType': widget.selectedVehicleType,
      'pickupAddress': _pickupAddressController.text,
      'pickupLat': _pickupLatitude!,
      'pickupLng': _pickupLongitude!,
      'isMultiStop': _isMultiStopMode,
      'isScheduled': _isScheduled,
      'scheduledPickupTime': _scheduledPickupTime?.toIso8601String(),
    };
    
    if (_isMultiStopMode) {
      // Multi-stop mode: pass all stops
      locationData['stops'] = _additionalStops;
      locationData['totalStops'] = _totalStopCount;
    } else {
      // Single-stop mode: pass single delivery location
      locationData['deliveryAddress'] = _deliveryAddressController.text;
      locationData['deliveryLat'] = _deliveryLatitude!;
      locationData['deliveryLng'] = _deliveryLongitude!;
    }
    
    // Navigate to contacts screen instead of order summary
    context.push('/delivery-contacts', extra: {
      'selectedVehicleType': widget.selectedVehicleType,
      'locationData': locationData,
    });
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
          backgroundColor: AppTheme.primaryBlue,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SmartBackHandler(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
      body: Stack(
        children: [
          // MAP AS BACKGROUND (FULL SCREEN)
          Positioned.fill(
            child: SharedDeliveryMap(
              key: _mapKey,
              onLocationSelected: (address, lat, lng, isPickup) {
                setState(() {
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
              },
              initialPickupAddress: _pickupAddressController.text,
              initialDeliveryAddress: _deliveryAddressController.text,
              pickupLatitude: _pickupLatitude,
              pickupLongitude: _pickupLongitude,
              deliveryLatitude: _deliveryLatitude,
              deliveryLongitude: _deliveryLongitude,
              isMultiStop: _isMultiStopMode,
              additionalStops: _additionalStops,
            ),
          ),
          
          // TOP BAR (floating over map)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95), // Slight transparency for glass effect
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () {
                      // Try to pop first, if that fails, go to vehicle selection
                      if (Navigator.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go('/create-delivery');
                      }
                    },
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Select Locations',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Vehicle: ${widget.selectedVehicleType.name}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40), // Space for symmetry
                ],
              ),
            ),
          ),
          
          // BOTTOM SHEET (20-30% of screen, swipeable)
          DraggableScrollableSheet(
            initialChildSize: 0.3, // 30% of screen initially
            minChildSize: 0.02,    // Minimum 1% - TRULY minimal to show map behind
            maxChildSize: 0.5,     // Maximum 60% when expanded
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
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
                        const SizedBox(height: 20),
                        
                        // Selected vehicle summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.selectedVehicleType.icon,
                                color: AppTheme.primaryBlue,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.selectedVehicleType.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Base: ₱${widget.selectedVehicleType.basePrice.toStringAsFixed(0)} + ₱${widget.selectedVehicleType.pricePerKm.toStringAsFixed(0)}/km',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Location inputs
                        Text(
                          'Where to?',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Saved addresses section
                        if (_savedAddresses.isNotEmpty) ...[
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
                          const SizedBox(height: 20),
                        ],
                        
                        // Pickup address input
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Pickup Location',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (_pickupLatitude != null && _pickupLongitude != null)
                              TextButton.icon(
                                onPressed: _savePickupAddress,
                                icon: const Icon(Icons.bookmark_add, size: 16),
                                label: Text(
                                  'Save',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        AddressInputField(
                          label: '',
                          hintText: 'Enter pickup address or tap on map',
                          initialAddress: _pickupAddressController.text,
                          savedAddresses: _savedAddresses,
                          onSavedAddressSelected: _useSavedAddressForPickup,
                          onLocationSelected: (address, lat, lng) {
                            setState(() {
                              _pickupAddressController.text = address;
                              _pickupLatitude = lat;
                              _pickupLongitude = lng;
                            });
                          },
                          // NEW: Enhanced delivery address callback for precise pickup location
                          onDeliveryAddressSelected: (deliveryAddress) {
                            setState(() {
                              _pickupDeliveryAddress = deliveryAddress;
                              _pickupAddressController.text = deliveryAddress.deliveryLabel;
                              _pickupLatitude = deliveryAddress.latitude;
                              _pickupLongitude = deliveryAddress.longitude;
                            });
                            print('HYBRID Pickup Address: ${deliveryAddress.deliveryLabel}');
                            print('- Source: ${deliveryAddress.sourceService}');
                            print('- Business: ${deliveryAddress.name ?? "N/A"}');
                            print('- House Number: ${deliveryAddress.houseNumber ?? "N/A"}');
                            print('- Street: ${deliveryAddress.street ?? "N/A"}');
                            print('- Barangay: ${deliveryAddress.barangay ?? "N/A"}');
                            print('- City: ${deliveryAddress.city ?? "N/A"}');
                            print('- Quality Score: ${deliveryAddress.qualityScore}/100');
                            print('- Deliverable: ${deliveryAddress.isDeliverable}');
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Delivery address input (ALWAYS SHOWN for clarity)
                        if (!_isMultiStopMode) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Delivery Location',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (_deliveryLatitude != null && _deliveryLongitude != null)
                                TextButton.icon(
                                  onPressed: _saveDeliveryAddress,
                                  icon: const Icon(Icons.bookmark_add, size: 16),
                                  label: Text(
                                    'Save',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primaryBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          AddressInputField(
                            label: '',
                            hintText: 'Enter delivery address or tap on map',
                            initialAddress: _deliveryAddressController.text,
                            savedAddresses: _savedAddresses,
                            onSavedAddressSelected: _useSavedAddressForDelivery,
                            onLocationSelected: (address, lat, lng) {
                              setState(() {
                                _deliveryAddressController.text = address;
                                _deliveryLatitude = lat;
                                _deliveryLongitude = lng;
                              });
                            },
                            // NEW: Enhanced delivery address callback for precise delivery location
                            onDeliveryAddressSelected: (deliveryAddress) {
                              setState(() {
                                _deliveryDeliveryAddress = deliveryAddress;
                                _deliveryAddressController.text = deliveryAddress.deliveryLabel;
                                _deliveryLatitude = deliveryAddress.latitude;
                                _deliveryLongitude = deliveryAddress.longitude;
                              });
                              print('HYBRID Delivery Address: ${deliveryAddress.deliveryLabel}');
                              print('- Source: ${deliveryAddress.sourceService}');
                              print('- Business: ${deliveryAddress.name ?? "N/A"}');
                              print('- House Number: ${deliveryAddress.houseNumber ?? "N/A"}');
                              print('- Street: ${deliveryAddress.street ?? "N/A"}');
                              print('- Barangay: ${deliveryAddress.barangay ?? "N/A"}');
                              print('- City: ${deliveryAddress.city ?? "N/A"}');
                              print('- Quality Score: ${deliveryAddress.qualityScore}/100');
                              print('- Deliverable: ${deliveryAddress.isDeliverable}');
                            },
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Multi-Stop Toggle and List
                        MultiStopSelector(
                          isMultiStop: _isMultiStopMode,
                          onChanged: _toggleMultiStopMode,
                          currentStopCount: _additionalStops.length,
                          maxStops: _maxStops,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Multi-stop stops list
                        if (_isMultiStopMode) ...[
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
                          if (widget.selectedVehicleType.additionalStopCharge != null &&
                              _additionalStops.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            MultiStopPricingInfo(
                              additionalStopCharge: widget.selectedVehicleType.additionalStopCharge!,
                              additionalStops: _additionalStops.length,
                            ),
                          ],
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Schedule Pickup Toggle
                        SchedulePickupWidget(
                          isScheduled: _isScheduled,
                          scheduledTime: _scheduledPickupTime,
                          onScheduleToggled: (enabled) {
                            setState(() {
                              _isScheduled = enabled;
                            });
                          },
                          onScheduledTimeChanged: (time) {
                            setState(() {
                              _scheduledPickupTime = time;
                            });
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Address quality indicator
                        if (_canContinue) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _hasDeliveryGradeAddresses 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _hasDeliveryGradeAddresses 
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _hasDeliveryGradeAddresses 
                                      ? Icons.verified
                                      : Icons.search,
                                  color: _hasDeliveryGradeAddresses 
                                      ? Colors.green
                                      : Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _hasDeliveryGradeAddresses 
                                            ? 'High Quality Addresses ✓'
                                            : 'Enhanced Address Search',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _hasDeliveryGradeAddresses 
                                              ? Colors.green
                                              : Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        _hasDeliveryGradeAddresses 
                                            ? 'Delivery-ready addresses with precise details'
                                            : 'Using Google Places for enhanced search quality',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: _hasDeliveryGradeAddresses 
                                              ? Colors.green.shade700
                                              : Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Helper text
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.infoLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: AppTheme.infoColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Tap on the map to quickly select pickup and delivery locations',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppTheme.infoColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Continue button 🌊 NEON GRADIENT BUTTON
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
                              onPressed: _canContinue ? _continueToSummary : null,
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
                                    ? 'Continue'
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
          
          // Floating "My Location" button (top right, fixed position)
          Positioned(
            top: MediaQuery.of(context).padding.top + 90, // Below top banner
            right: 20,
            child: FloatingActionButton.small(
              heroTag: "my_location", // Prevent hero tag conflicts
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