import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../models/vehicle_type.dart';
import '../widgets/shared_delivery_map.dart';
import '../widgets/address_input_field.dart';
import '../services/hybrid_address_service.dart'; // UPDATED: Use hybrid service
import '../constants/app_theme.dart';

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

  bool get _canContinue => 
      _pickupLatitude != null && 
      _pickupLongitude != null &&
      _deliveryLatitude != null && 
      _deliveryLongitude != null;

  bool get _hasDeliveryGradeAddresses =>
      _pickupDeliveryAddress?.isDeliverable == true &&
      _deliveryDeliveryAddress?.isDeliverable == true;

  void _continueToSummary() {
    if (!_canContinue) {
      // This shouldn't happen since button is disabled, but just in case
      return;
    }
    
    HapticFeedback.lightImpact();
    
    // Pass all the data to the summary screen
    final locationData = {
      'vehicleType': widget.selectedVehicleType,
      'pickupAddress': _pickupAddressController.text,
      'pickupLat': _pickupLatitude!,
      'pickupLng': _pickupLongitude!,
      'deliveryAddress': _deliveryAddressController.text,
      'deliveryLat': _deliveryLatitude!,
      'deliveryLng': _deliveryLongitude!,
    };
    
    context.push('/order-summary', extra: locationData);
  }

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
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
            minChildSize: 0.01,    // Minimum 1% - TRULY minimal to show map behind
            maxChildSize: 0.6,     // Maximum 60% when expanded
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
                        
                        AddressInputField(
                          label: 'Pickup Location',
                          hintText: 'Enter pickup address or tap on map',
                          initialAddress: _pickupAddressController.text,
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
                        
                        const SizedBox(height: 12),
                        
                        AddressInputField(
                          label: 'Delivery Location',
                          hintText: 'Enter delivery address or tap on map',
                          initialAddress: _deliveryAddressController.text,
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
                        
                        // Continue button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canContinue ? _continueToSummary : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
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
                        
                        const SizedBox(height: 40), // Extra space for scrolling
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Floating "My Location" button (bottom right)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.4, // Above the bottom sheet
            right: 20,
            child: FloatingActionButton(
              heroTag: "my_location", // Prevent hero tag conflicts
              onPressed: _focusOnMyLocation,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryBlue,
              elevation: 8,
              child: const Icon(Icons.my_location, size: 24),
            ),
          ),
        ],
      ),
    );
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
}