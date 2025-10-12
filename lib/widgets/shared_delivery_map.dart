import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

import '../services/mapbox_service.dart';
import '../constants/app_theme.dart';

// Polyline phases for delivery tracking
enum PolylinePhase {
  none,           // No polyline needed (arrived, pending, etc.)
  driverToPickup, // Phase 1: Driver heading to pickup location
  pickupToDelivery, // Phase 2: Driver heading from pickup to delivery
  routePreview,   // Route preview: Pickup to delivery for location selection
}

class SharedDeliveryMap extends StatefulWidget {
  final Function(String address, double lat, double lng, bool isPickup)? onLocationSelected;
  final String? initialPickupAddress;
  final String? initialDeliveryAddress;
  
  // Real-time coordinate updates (Uber-style)
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  
  // Real-time driver tracking
  final double? driverLatitude;
  final double? driverLongitude;
  
  // Polyline phase management
  final String? deliveryStatus;
  final Function(double distanceKm, double estimatedMinutes)? onRouteCalculated;
  
  // Driver vehicle information for map display
  final String? driverVehicleType;

  const SharedDeliveryMap({
    super.key,
    this.onLocationSelected,
    this.initialPickupAddress,
    this.initialDeliveryAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.driverLatitude,
    this.driverLongitude,
    this.deliveryStatus,
    this.onRouteCalculated,
    this.driverVehicleType,
  });

  @override
  State<SharedDeliveryMap> createState() => _SharedDeliveryMapState();
}

class _SharedDeliveryMapState extends State<SharedDeliveryMap> with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  
  // Location states (using Mapbox Position for map coordinates)
  Position? _pickupLocation;
  Position? _deliveryLocation;
  Position? _driverLocation;
  
  // Vehicle marker management
  PointAnnotation? _driverMarker;
  bool _vehicleIconsLoaded = false;
  
  // User location (using Geolocator Position for GPS)
  geo.Position? _userLocation;
  
  // Marker tracking
  List<CircleAnnotation> _pickupMarkerCircles = [];
  List<CircleAnnotation> _dropoffMarkerCircles = [];
  List<CircleAnnotation> _driverMarkerCircles = [];
  CircleAnnotation? _userLocationMarker;
  CircleAnnotation? _userLocationAccuracyCircle;
  
  // User location tracking
  StreamSubscription<geo.Position>? _locationSubscription;
  late AnimationController _pulseController;
  Timer? _pulseTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation controller for user location
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Smooth 2-second cycles
      vsync: this,
    );
    
    // Start smooth repeating pulsing animation
    _pulseController.repeat();
    
    // Initialize locations from widget coordinates if provided
    _updateLocationsFromWidget();
    
    // Start user location tracking
    _startLocationTracking();
  }

  @override
  void didUpdateWidget(SharedDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check for meaningful coordinate changes (avoid micro-updates)
    final coordinatesChanged = widget.pickupLatitude != oldWidget.pickupLatitude ||
        widget.pickupLongitude != oldWidget.pickupLongitude ||
        widget.deliveryLatitude != oldWidget.deliveryLatitude ||
        widget.deliveryLongitude != oldWidget.deliveryLongitude ||
        widget.driverLatitude != oldWidget.driverLatitude ||
        widget.driverLongitude != oldWidget.driverLongitude;
        
    final statusChanged = widget.deliveryStatus != oldWidget.deliveryStatus;
    
    if (coordinatesChanged || statusChanged) {
      debugPrint('🔄 SharedDeliveryMap updating - coordinates: $coordinatesChanged, status: $statusChanged');
      
      if (coordinatesChanged) {
        _updateLocationsFromWidget();
      }
      
      // Update polyline only when delivery status changes
      if (statusChanged) {
        debugPrint('🔄 Status change: ${oldWidget.deliveryStatus} → ${widget.deliveryStatus}');
        _updatePolylineForStatus();
      }
    }
  }

  // Update internal locations from widget coordinates
  void _updateLocationsFromWidget() {
    bool shouldUpdate = false;
    
    // Update pickup location
    if (widget.pickupLatitude != null && widget.pickupLongitude != null) {
      final newPickup = Position(widget.pickupLongitude!, widget.pickupLatitude!);
      if (_pickupLocation?.lat != newPickup.lat || _pickupLocation?.lng != newPickup.lng) {
        _pickupLocation = newPickup;
        shouldUpdate = true;
      }
    }
    
    // Update delivery location
    if (widget.deliveryLatitude != null && widget.deliveryLongitude != null) {
      final newDelivery = Position(widget.deliveryLongitude!, widget.deliveryLatitude!);
      if (_deliveryLocation?.lat != newDelivery.lat || _deliveryLocation?.lng != newDelivery.lng) {
        _deliveryLocation = newDelivery;
        shouldUpdate = true;
      }
    }
    
    // Update driver location (real-time tracking)
    if (widget.driverLatitude != null && widget.driverLongitude != null) {
      final newDriver = Position(widget.driverLongitude!, widget.driverLatitude!);
      if (_driverLocation?.lat != newDriver.lat || _driverLocation?.lng != newDriver.lng) {
        _driverLocation = newDriver;
        shouldUpdate = true;
      }
    }
    
    // Update map markers and route if locations changed
    if (shouldUpdate) {
      _updateMapMarkers();
      
      // Auto-adjust camera (Uber-style behavior)
      if (_pickupLocation != null && _deliveryLocation != null) {
        // Both locations available - fit both
        _fitMapToBothLocations();
      } else if (_pickupLocation != null) {
        // Only pickup - center on pickup
        _updateMapCamera(_pickupLocation!.lat.toDouble(), _pickupLocation!.lng.toDouble());
      } else if (_deliveryLocation != null) {
        // Only delivery - center on delivery
        _updateMapCamera(_deliveryLocation!.lat.toDouble(), _deliveryLocation!.lng.toDouble());
      }
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    print('Mapbox map created successfully');
    
    try {
      // Create annotation managers
      _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
      _polylineAnnotationManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
      _circleAnnotationManager = await _mapboxMap!.annotations.createCircleAnnotationManager();
      print('Annotation managers created');
      
      // Note: Using emoji markers for now, custom images can be added later
      
      // Enable map interactions with 3D support
      await _mapboxMap!.gestures.updateSettings(GesturesSettings(
        rotateEnabled: true,
        pitchEnabled: true,        // Allow pitch gestures for 3D tilt
        scrollEnabled: true,
        simultaneousRotateAndPinchToZoomEnabled: true,
        pinchToZoomEnabled: true,
        quickZoomEnabled: true,    // Enhanced zoom performance
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
      ));
      print('Enhanced map gestures enabled (3D ready)');
      
      // Load vehicle icons for map markers
      await _loadVehicleIcons();
      
      // Update markers if locations are already set
      await _updateMapMarkers();
      
      // Update user location if available
      if (_userLocation != null) {
        await _updateUserLocationMarker(_userLocation!);
      }
      
      // Auto-focus on user location when map loads
      _autoFocusOnUserLocation();
    } catch (e) {
      print('Error setting up map annotations: $e');
    }
  }
  
  // Handle map tap for location selection
  void _onMapTapped(MapContentGestureContext context) async {
    final tappedPoint = context.point;
    final lat = tappedPoint.coordinates.lat.toDouble();
    final lng = tappedPoint.coordinates.lng.toDouble();
    
    print('Map tapped at: $lat, $lng');
    
    // If neither location is set, set pickup first
    if (_pickupLocation == null) {
      await _setLocationFromTap(lat, lng, true);
    }
    // If pickup is set but delivery isn't, set delivery
    else if (_deliveryLocation == null) {
      await _setLocationFromTap(lat, lng, false);
    }
    // If both are set, ask user which one to update (or update the closer one)
    else {
      await _showLocationSelectionDialog(lat, lng);
    }
  }
  
  // Set location from map tap and reverse geocode
  Future<void> _setLocationFromTap(double lat, double lng, bool isPickup) async {
    try {
      // Show loading feedback immediately with modern design
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Getting address...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      
      // Update location first (for immediate visual feedback)
      setState(() {
        if (isPickup) {
          _pickupLocation = Position(lng, lat);
        } else {
          _deliveryLocation = Position(lng, lat);
        }
      });
      
      // Update markers immediately
      await _updateMapMarkers();
      
      // Reverse geocode to get address (this might take a moment)
      String? address = await MapboxService.reverseGeocode(lat, lng);
      address ??= 'Selected Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
      
      // Notify parent widget to update address textboxes
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(address, lat, lng, isPickup);
      }
      
      // Show success feedback with the address
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPickup ? '📍' : '🏁',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPickup ? 'Pickup location set' : 'Delivery location set',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 12, 
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: isPickup ? Colors.green.shade600 : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      
    } catch (e) {
      print('Error setting location from tap: $e');
      
      // Show error feedback
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Failed to set location. Please try again.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }
  
  // Show dialog to select which location to update
  Future<void> _showLocationSelectionDialog(double lat, double lng) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_location,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Update Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: const Text(
            'Which location would you like to update?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            Container(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _setLocationFromTap(lat, lng, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Update Pickup Location',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _setLocationFromTap(lat, lng, false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Update Delivery Location',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Legacy method - now calls enhanced marker system
  Future<void> _updateMapMarkers() async {
    await _updateEnhancedMapMarkers();
  }

  // Legacy route drawing - now calls enhanced polyline management
  Future<void> _drawRoute() async {
    await _updatePolylineForStatus();
  }

  // Enhanced polyline management based on delivery status
  Future<void> _updatePolylineForStatus() async {
    if (_polylineAnnotationManager == null) return;
    
    try {
      // Always clear existing polylines first
      await _polylineAnnotationManager!.deleteAll();
      print('🗺️ Cleared existing polylines for status update');
      
      // Determine polyline phase based on delivery status
      final polylinePhase = _getPolylinePhase();
      print('🗺️ Polyline phase: $polylinePhase');
      
      switch (polylinePhase) {
        case PolylinePhase.driverToPickup:
          await _drawDriverToPickupRoute();
          break;
        case PolylinePhase.pickupToDelivery:
          await _drawPickupToDeliveryRoute();
          break;
        case PolylinePhase.routePreview:
          await _drawRoutePreview();
          break;
        case PolylinePhase.none:
          print('🗺️ No polyline needed for current status');
          break;
      }
    } catch (e) {
      print('❌ Error updating polyline for status: $e');
    }
  }

  // Determine which polyline phase to show
  PolylinePhase _getPolylinePhase() {
    print('🗺️ _getPolylinePhase called');
    print('🗺️ widget.deliveryStatus: ${widget.deliveryStatus}');
    print('🗺️ _pickupLocation: ${_pickupLocation != null ? '(${_pickupLocation!.lat}, ${_pickupLocation!.lng})' : 'null'}');
    print('🗺️ _deliveryLocation: ${_deliveryLocation != null ? '(${_deliveryLocation!.lat}, ${_deliveryLocation!.lng})' : 'null'}');
    print('🗺️ _driverLocation: ${_driverLocation != null ? '(${_driverLocation!.lat}, ${_driverLocation!.lng})' : 'null'}');
    
    // If no delivery status, check for route preview mode (location selection)
    if (widget.deliveryStatus == null) {
      // Show route preview if both pickup and delivery locations are available
      if (_pickupLocation != null && _deliveryLocation != null) {
        print('🗺️ Returning PolylinePhase.routePreview');
        return PolylinePhase.routePreview;
      }
      print('🗺️ Returning PolylinePhase.none (no locations)');
      return PolylinePhase.none;
    }
    
    PolylinePhase phase;
    switch (widget.deliveryStatus!) {
      case 'driver_assigned':
      case 'going_to_pickup':
        phase = PolylinePhase.driverToPickup;
        break;
      case 'package_collected':
      case 'going_to_destination':
      case 'in_transit':
        phase = PolylinePhase.pickupToDelivery;
        break;
      case 'pickup_arrived':
      case 'at_destination':
      case 'delivered':
        phase = PolylinePhase.none; // No route needed when arrived
        break;
      default:
        phase = PolylinePhase.none;
        break;
    }
    
    print('🗺️ Returning phase: $phase for status: ${widget.deliveryStatus}');
    return phase;
  }

  // Draw route from driver to pickup location (Phase 1)
  Future<void> _drawDriverToPickupRoute() async {
    print('🗺️ _drawDriverToPickupRoute called');
    print('🗺️ _driverLocation: ${_driverLocation != null ? '(${_driverLocation!.lat}, ${_driverLocation!.lng})' : 'null'}');
    print('🗺️ _pickupLocation: ${_pickupLocation != null ? '(${_pickupLocation!.lat}, ${_pickupLocation!.lng})' : 'null'}');
    
    if (_driverLocation == null || _pickupLocation == null) {
      print('❌ Missing driver or pickup location for Phase 1 route');
      print('   - Driver location: ${_driverLocation == null ? 'MISSING' : 'available'}');
      print('   - Pickup location: ${_pickupLocation == null ? 'MISSING' : 'available'}');
      return;
    }
    
    try {
      print('🗺️ Drawing Phase 1 route: Driver → Pickup');
      print('🗺️ Route coordinates: (${_driverLocation!.lat}, ${_driverLocation!.lng}) → (${_pickupLocation!.lat}, ${_pickupLocation!.lng})');
      
      // Get route from driver's current location to pickup
      final route = await MapboxService.getRoute(
        _driverLocation!.lat.toDouble(), _driverLocation!.lng.toDouble(),
        _pickupLocation!.lat.toDouble(), _pickupLocation!.lng.toDouble()
      );
      
      if (route != null) {
        // Use DoorDash-style vibrant blue
        await _createPolyline(route, const Color(0xFF007AFF), 'Driver → Pickup');
        
        // Calculate and report ETA
        final distance = _calculateRouteDistance(route);
        final estimatedMinutes = _estimateDeliveryTime(distance, isToPickup: true);
        widget.onRouteCalculated?.call(distance, estimatedMinutes);
      }
    } catch (e) {
      print('❌ Error drawing driver to pickup route: $e');
    }
  }

  // Draw route from pickup to delivery location (Phase 2)
  Future<void> _drawPickupToDeliveryRoute() async {
    if (_pickupLocation == null || _deliveryLocation == null) {
      print('🗺️ Missing pickup or delivery location for Phase 2 route');
      return;
    }
    
    try {
      print('🗺️ Drawing Phase 2 route: Pickup → Delivery');
      
      // Get route from pickup location to delivery destination
      final route = await MapboxService.getRoute(
        _pickupLocation!.lat.toDouble(), _pickupLocation!.lng.toDouble(),
        _deliveryLocation!.lat.toDouble(), _deliveryLocation!.lng.toDouble()
      );
      
      if (route != null) {
        // Use DoorDash-style delivery purple
        await _createPolyline(route, const Color(0xFF8B5CF6), 'Pickup → Delivery');
        
        // Calculate and report ETA
        final distance = _calculateRouteDistance(route);
        final estimatedMinutes = _estimateDeliveryTime(distance, isToPickup: false);
        widget.onRouteCalculated?.call(distance, estimatedMinutes);
      }
    } catch (e) {
      print('❌ Error drawing pickup to delivery route: $e');
    }
  }

  // Draw route preview for location selection (Pickup → Delivery preview)
  Future<void> _drawRoutePreview() async {
    if (_pickupLocation == null || _deliveryLocation == null) {
      print('🗺️ Missing pickup or delivery location for route preview');
      return;
    }
    
    try {
      print('🗺️ Drawing route preview: Pickup → Delivery');
      
      // Get route from pickup location to delivery destination
      final route = await MapboxService.getRoute(
        _pickupLocation!.lat.toDouble(), _pickupLocation!.lng.toDouble(),
        _deliveryLocation!.lat.toDouble(), _deliveryLocation!.lng.toDouble()
      );
      
      if (route != null) {
        // Use a distinctive color for route preview (green for preview)
        await _createPolyline(route, Colors.green, 'Route Preview');
        
        // Calculate and report route info for location selection
        final distance = _calculateRouteDistance(route);
        final estimatedMinutes = _estimateDeliveryTime(distance, isToPickup: false);
        widget.onRouteCalculated?.call(distance, estimatedMinutes);
        
        print('✅ Route preview created: ${distance.toStringAsFixed(1)}km, ${estimatedMinutes.toStringAsFixed(0)} min');
      }
    } catch (e) {
      print('❌ Error drawing route preview: $e');
    }
  }

  // Create polyline with specified color and label
  Future<void> _createPolyline(List<Map<String, double>> route, Color color, String label) async {
    try {
      // Convert route coordinates to Position objects
      final routePositions = route.map((coord) => Position(coord['lng']!, coord['lat']!)).toList();
      
      debugPrint('🗺️ Creating polyline with ${routePositions.length} points');
      debugPrint('🗺️ First point: ${routePositions.first.lng}, ${routePositions.first.lat}');
      debugPrint('🗺️ Last point: ${routePositions.last.lng}, ${routePositions.last.lat}');
      
      // Create enhanced polyline with DoorDash/Instacart style
      final polylineAnnotation = PolylineAnnotationOptions(
        geometry: LineString(coordinates: routePositions),
        lineColor: color.value,
        lineWidth: 6.0, // Thicker line for better visibility
        lineOpacity: 0.9, // More opaque for better contrast
      );
      
      await _polylineAnnotationManager!.create(polylineAnnotation);
      debugPrint('✅ $label polyline created with ${routePositions.length} points');
    } catch (e) {
      debugPrint('❌ Error creating $label polyline: $e');
    }
  }

  // Calculate total route distance in kilometers
  double _calculateRouteDistance(List<Map<String, double>> route) {
    if (route.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      final lat1 = route[i]['lat']!;
      final lng1 = route[i]['lng']!;
      final lat2 = route[i + 1]['lat']!;
      final lng2 = route[i + 1]['lng']!;
      
      // Use Haversine formula for distance calculation
      totalDistance += _calculateDistance(lat1, lng1, lat2, lng2);
    }
    
    return totalDistance;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Load vehicle icons (placeholder for future SVG implementation)
  Future<void> _loadVehicleIcons() async {
    if (_mapboxMap == null || _vehicleIconsLoaded) return;

    try {
      print('🚗 Preparing enhanced vehicle markers...');
      
      // For now, we'll use enhanced geometric markers that represent vehicle shapes
      // This provides immediate professional appearance while we prepare full SVG integration
      
      _vehicleIconsLoaded = true;
      print('✅ Vehicle marker system ready!');
      
    } catch (e) {
      print('❌ Error preparing vehicle markers: $e');
    }
  }

  // Get vehicle icon name for map marker


  // Create vehicle-specific SVG marker
  Future<void> _createEnhancedVehicleMarker() async {
    debugPrint('🚗 _createEnhancedVehicleMarker called for delivery tracking');
    debugPrint('🚗 _circleAnnotationManager: ${_circleAnnotationManager != null ? 'exists' : 'null'}');
    debugPrint('🚗 _pointAnnotationManager: ${_pointAnnotationManager != null ? 'exists' : 'null'}');
    debugPrint('🚗 _driverLocation: $_driverLocation');
    
    if (_pointAnnotationManager == null || _driverLocation == null) {
      debugPrint('❌ Cannot create vehicle marker - missing requirements:');
      debugPrint('   - _pointAnnotationManager: ${_pointAnnotationManager == null ? 'MISSING' : 'available'}');
      debugPrint('   - _driverLocation: ${_driverLocation == null ? 'MISSING' : 'available'}');
      return;
    }

    try {
      final vehicleType = widget.driverVehicleType ?? 'sedan';
      debugPrint('🚗 Creating SVG vehicle marker for: $vehicleType');
      debugPrint('🚗 Driver position: lat=${_driverLocation!.lat}, lng=${_driverLocation!.lng}');
      
      // Get vehicle-specific SVG icon path
      final iconPath = _getVehicleIconPath(vehicleType);
      debugPrint('🚗 Vehicle icon path: $iconPath');
      
      // For now, use enhanced circle marker (SVG loading will be added later)
      await _createFallbackVehicleMarker();

      // Create subtle background circle for better visibility
      if (_circleAnnotationManager != null) {
        final backgroundCircle = await _circleAnnotationManager!.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: _driverLocation!),
            circleRadius: 20.0,
            circleColor: Colors.white.withOpacity(0.9).value,
            circleStrokeColor: Colors.blue.value,
            circleStrokeWidth: 2.0,
          ),
        );
        _driverMarkerCircles.add(backgroundCircle);
      }
      
      debugPrint('✅ Enhanced $vehicleType SVG marker created successfully!');
    } catch (e) {
      debugPrint('❌ Error creating vehicle SVG marker: $e');
      // Fallback to basic circle marker if SVG fails
      await _createFallbackVehicleMarker();
    }
  }

  // Get vehicle-specific icon path
  String _getVehicleIconPath(String vehicleType) {
    final type = vehicleType.toLowerCase();
    
    if (type.contains('motorcycle') || type.contains('bike')) {
      return 'assets/icons/motorcycle.svg';
    } else if (type.contains('truck')) {
      return 'assets/icons/truck.svg';
    } else if (type.contains('van')) {
      return 'assets/icons/van.svg';
    } else {
      return 'assets/icons/sedan.svg'; // Default fallback
    }
  }

  // Create DoorDash/Instacart style driver marker
  Future<void> _createFallbackVehicleMarker() async {
    if (_circleAnnotationManager == null || _driverLocation == null) return;
    
    try {
      final vehicleColor = _getVehicleColor(widget.driverVehicleType ?? 'sedan');
      
      // Create outer glow effect (like DoorDash)
      final outerGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 20.0,
          circleColor: vehicleColor.withOpacity(0.2).value,
          circleStrokeColor: vehicleColor.withOpacity(0.4).value,
          circleStrokeWidth: 1.0,
        ),
      );
      
      // Create main marker with shadow effect
      final shadowMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLocation!.lng + 0.00002, _driverLocation!.lat - 0.00002)),
          circleRadius: 12.0,
          circleColor: Colors.black.withOpacity(0.2).value,
        ),
      );
      
      // Create main vehicle marker
      final mainMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 12.0,
          circleColor: vehicleColor.value,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 3.0,
        ),
      );
      
      // Add vehicle type indicator (small inner circle)
      final innerIndicator = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 6.0,
          circleColor: Colors.white.value,
        ),
      );
      
      _driverMarkerCircles.addAll([outerGlow, shadowMarker, mainMarker, innerIndicator]);
      
      // Start subtle pulsing animation like DoorDash
      _startDriverPulsingEffect();
      
      debugPrint('✅ DoorDash-style ${widget.driverVehicleType} marker created');
    } catch (e) {
      debugPrint('❌ Error creating enhanced marker: $e');
    }
  }

  // Get vehicle type color
  Color _getVehicleColor(String vehicleType) {
    final type = vehicleType.toLowerCase();
    
    if (type.contains('motorcycle') || type.contains('bike')) {
      return Colors.orange; // Orange for motorcycles
    } else if (type.contains('truck')) {
      return Colors.red; // Red for trucks
    } else if (type.contains('van')) {
      return Colors.purple; // Purple for vans
    } else {
      return Colors.blue; // Blue for sedans/default
    }
  }

  // Create vehicle-specific identifier patterns (shapes representing vehicle types)
  Future<void> _createVehicleIdentifierPattern(Map<String, Color> colors, String vehicleType) async {
    final vehicleTypeLower = vehicleType.toLowerCase();
    
    if (vehicleTypeLower.contains('motorcycle')) {
      // Single small dot for motorcycle (compact)
      final dot = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 4.0,
          circleColor: Colors.white.value,
          circleStrokeColor: colors['primary']!.value,
          circleStrokeWidth: 2.0,
        ),
      );
      _driverMarkerCircles.add(dot);
      
    } else if (vehicleTypeLower.contains('truck') || vehicleTypeLower.contains('van')) {
      // Rectangle pattern for trucks/vans (two horizontal dots)
      final dot1 = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLocation!.lng - 0.00008, _driverLocation!.lat)),
          circleRadius: 3.0,
          circleColor: Colors.white.value,
          circleStrokeColor: colors['primary']!.value,
          circleStrokeWidth: 1.5,
        ),
      );
      final dot2 = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLocation!.lng + 0.00008, _driverLocation!.lat)),
          circleRadius: 3.0,
          circleColor: Colors.white.value,
          circleStrokeColor: colors['primary']!.value,
          circleStrokeWidth: 1.5,
        ),
      );
      _driverMarkerCircles.addAll([dot1, dot2]);
      
    } else if (vehicleTypeLower.contains('suv') || vehicleTypeLower.contains('pickup')) {
      // Diamond pattern for SUVs/pickups (four small dots)
      final positions = [
        Position(_driverLocation!.lng, _driverLocation!.lat + 0.00006), // Top
        Position(_driverLocation!.lng + 0.00006, _driverLocation!.lat), // Right
        Position(_driverLocation!.lng, _driverLocation!.lat - 0.00006), // Bottom
        Position(_driverLocation!.lng - 0.00006, _driverLocation!.lat), // Left
      ];
      
      for (final pos in positions) {
        final dot = await _circleAnnotationManager!.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: pos),
            circleRadius: 2.5,
            circleColor: Colors.white.value,
            circleStrokeColor: colors['primary']!.value,
            circleStrokeWidth: 1.0,
          ),
        );
        _driverMarkerCircles.add(dot);
      }
      
    } else {
      // Default sedan pattern (center circle)
      final centerDot = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 5.0,
          circleColor: Colors.white.value,
          circleStrokeColor: colors['primary']!.value,
          circleStrokeWidth: 2.0,
        ),
      );
      _driverMarkerCircles.add(centerDot);
    }
  }

  // Get vehicle-specific design colors
  Map<String, Color> _getVehicleDesignColors(String vehicleType) {
    final vehicleTypeLower = vehicleType.toLowerCase();
    
    if (vehicleTypeLower.contains('motorcycle')) {
      return {'primary': Colors.orange.shade600};
    } else if (vehicleTypeLower.contains('truck')) {
      return {'primary': Colors.green.shade600};
    } else if (vehicleTypeLower.contains('van')) {
      return {'primary': Colors.purple.shade600};
    } else if (vehicleTypeLower.contains('suv')) {
      return {'primary': Colors.teal.shade600};
    } else if (vehicleTypeLower.contains('pickup')) {
      return {'primary': Colors.indigo.shade600};
    } else {
      return {'primary': Colors.blue.shade600}; // Default sedan
    }
  }

  // Get vehicle-specific marker styling with patterns


  // Estimate delivery time based on distance and phase
  double _estimateDeliveryTime(double distanceKm, {required bool isToPickup}) {
    // Base speed assumptions (km/h)
    const double citySpeed = 25.0; // Average city driving speed
    const double pickupTime = 3.0; // Additional time for pickup process (minutes)
    const double deliveryTime = 2.0; // Additional time for delivery process (minutes)
    
    // Calculate travel time
    final double travelTimeHours = distanceKm / citySpeed;
    final double travelTimeMinutes = travelTimeHours * 60;
    
    // Add process time based on phase
    final double processTime = isToPickup ? pickupTime : deliveryTime;
    
    return travelTimeMinutes + processTime;
  }

  Future<void> _fitMapToBothLocations() async {
    if (_mapboxMap == null || _pickupLocation == null || _deliveryLocation == null) return;
    
    try {
      // Calculate center point between pickup and delivery
      final centerLat = (_pickupLocation!.lat + _deliveryLocation!.lat) / 2;
      final centerLng = (_pickupLocation!.lng + _deliveryLocation!.lng) / 2;
      
      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(centerLng, centerLat)),
          zoom: 12.0,
          pitch: 20.0,    // SUBTLE 3D: Maintain subtle tilt when showing route
          bearing: 0.0,   // Keep north-up for route clarity
        ),
      );
    } catch (e) {
      print('Fit map error: $e');
    }
  }

  // Public methods to set locations from address search
  void setPickupLocation(double lat, double lng) {
    setState(() {
      _pickupLocation = Position(lng, lat);
    });
    _updateMapMarkers();
    _updateMapCamera(lat, lng);
  }

  void setDeliveryLocation(double lat, double lng) {
    setState(() {
      _deliveryLocation = Position(lng, lat);
    });
    _updateMapMarkers();
    if (_pickupLocation != null) {
      _fitMapToBothLocations();
    } else {
      _updateMapCamera(lat, lng);
    }
  }

  // Clear all map annotations (helpful for cleanup)
  Future<void> clearAllAnnotations() async {
    try {
      await _pointAnnotationManager?.deleteAll();
      await _polylineAnnotationManager?.deleteAll();
      await _circleAnnotationManager?.deleteAll();
      
      // Clear marker tracking lists
      _pickupMarkerCircles.clear();
      _dropoffMarkerCircles.clear();
      _userLocationMarker = null;
      _userLocationAccuracyCircle = null;
      
      // Clear pulse rings
      _pulseRings.clear();
      
      print('All map annotations cleared');
    } catch (e) {
      print('Error clearing annotations: $e');
    }
  }

  void _updateMapCamera(double lat, double lng) async {
    if (_mapboxMap == null) return;
    
    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 15.0,
        pitch: 20.0,    // SUBTLE 3D: Maintain subtle tilt when focusing on locations
        bearing: 0.0,   // Keep north-up orientation
      ),
    );
  }

  // Focus camera on user's current location
  Future<void> focusOnUserLocation() async {
    if (_mapboxMap == null) return;
    
    try {
      // Get fresh location
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      
      // Update user location
      _updateUserLocation(position);
      
      // Animate camera to user location
      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 16.0,
          pitch: 20.0,
          bearing: 0.0,
        ),
      );
    } catch (e) {
      print('Error focusing on user location: $e');
    }
  }

  // Auto-focus on user location when map loads (called from initState)
  Future<void> _autoFocusOnUserLocation() async {
    // Wait a bit for map to be ready
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (_userLocation != null && _mapboxMap != null) {
      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(_userLocation!.longitude, _userLocation!.latitude)),
          zoom: 14.0,
          pitch: 20.0,
          bearing: 0.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Interactive Map - FULL SCREEN
        Positioned.fill(
          child: MapWidget(
            key: const ValueKey("shared_delivery_map"),
            onMapCreated: _onMapCreated,
            onTapListener: _onMapTapped,
            // ENHANCED: Modern map style optimized for delivery apps
            styleUri: "mapbox://styles/mapbox/streets-v12", // Modern street style with 3D buildings
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(
                MapboxService.metroManilaLng, 
                MapboxService.metroManilaLat
              )),
              zoom: 12.0,
              pitch: 20.0,    // SUBTLE 3D: Perfect balance of depth and performance
              bearing: 0.0,   // No rotation for clean north-up orientation
            ),
          ),
        ),
        
        // Map interaction instructions - FLOATING OVERLAY
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.touch_app,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tap to set locations',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Auto-fills address fields below',
                        style: TextStyle(
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
        ),
        
        // Location status indicators - BOTTOM FLOATING
        if (_pickupLocation != null || _deliveryLocation != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_pickupLocation != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Pickup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_pickupLocation != null && _deliveryLocation != null)
                    const SizedBox(width: 8),
                  if (_deliveryLocation != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Delivery',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_pickupLocation != null && _deliveryLocation != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Route ready',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationSubscription?.cancel();
    _pulseTimer?.cancel();
    _driverPulseTimer?.cancel();
    
    // Clean up pulse rings
    _cleanupPulseRings();
    _cleanupDriverPulseRings();
    
    super.dispose();
  }

  // Clean up all pulse rings
  Future<void> _cleanupPulseRings() async {
    try {
      for (final ring in _pulseRings) {
        try {
          await _circleAnnotationManager?.delete(ring);
        } catch (e) {
          // Ring might already be deleted
        }
      }
      _pulseRings.clear();
    } catch (e) {
      print('Error cleaning up pulse rings: $e');
    }
  }

  // Clean up all driver pulse rings
  Future<void> _cleanupDriverPulseRings() async {
    try {
      for (final ring in _driverPulseRings) {
        try {
          await _circleAnnotationManager?.delete(ring);
        } catch (e) {
          // Ring might already be deleted
        }
      }
      _driverPulseRings.clear();
    } catch (e) {
      print('Error cleaning up driver pulse rings: $e');
    }
  }

  // Start user location tracking
  Future<void> _startLocationTracking() async {
    try {
      // Check location permissions
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          print('Location permissions are denied');
          return;
        }
      }
      
      if (permission == geo.LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return;
      }

      // Start location stream
      _locationSubscription = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((geo.Position position) {
        _updateUserLocation(position);
      });

      // Get initial location
      final position = await geo.Geolocator.getCurrentPosition();
      _updateUserLocation(position);
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }

  // Update user location marker
  void _updateUserLocation(geo.Position position) {
    // Check if user moved significantly (more than 50 meters)
    bool significantMovement = false;
    if (_userLocation != null) {
      final double distance = geo.Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        position.latitude,
        position.longitude,
      );
      significantMovement = distance > 50; // 50 meters threshold
    }

    setState(() {
      _userLocation = position;
    });

    if (_mapboxMap != null && _circleAnnotationManager != null) {
      _updateUserLocationMarker(position);
      
      // ENHANCED: Clear old pulse rings if user moved significantly to prevent trails
      if (significantMovement) {
        _clearOldPulseRings();
      }
    }
  }

  // Clear old pulse rings to prevent trails when user moves significantly
  Future<void> _clearOldPulseRings() async {
    try {
      // Clear all existing pulse rings to prevent trails
      for (final ring in _pulseRings.toList()) {
        try {
          await _circleAnnotationManager?.delete(ring);
        } catch (e) {
          // Ring might already be deleted
        }
      }
      _pulseRings.clear();
      print('Cleared old pulse rings due to significant user movement');
    } catch (e) {
      print('Error clearing old pulse rings: $e');
    }
  }

  // Update user location marker on map
  Future<void> _updateUserLocationMarker(geo.Position position) async {
    try {
      // Remove existing user location markers
      if (_userLocationMarker != null) {
        await _circleAnnotationManager!.delete(_userLocationMarker!);
      }
      if (_userLocationAccuracyCircle != null) {
        await _circleAnnotationManager!.delete(_userLocationAccuracyCircle!);
      }

      // Create accuracy circle (larger, semi-transparent)
      _userLocationAccuracyCircle = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: position.accuracy,
          circleColor: AppTheme.primaryBlue.withOpacity(0.1).value,
          circleStrokeColor: AppTheme.primaryBlue.withOpacity(0.2).value,
          circleStrokeWidth: 1.0,
        ),
      );

      // Create pulsing user location marker
      _userLocationMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: 8.0,
          circleColor: AppTheme.primaryBlue.value,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 3.0,
        ),
      );

      // Start pulsing effect
      _startPulsingEffect();
    } catch (e) {
      print('Error updating user location marker: $e');
    }
  }

  // Start smooth pulsing effect for user location
  void _startPulsingEffect() {
    _pulseTimer?.cancel();
    // Create overlapping pulse rings every 600ms for smooth continuous effect
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (_userLocationMarker != null && _circleAnnotationManager != null && _userLocation != null) {
        _createPulseRing();
      }
    });
  }

  // Variables to track pulse rings
  List<CircleAnnotation> _pulseRings = [];
  List<CircleAnnotation> _driverPulseRings = [];
  Timer? _driverPulseTimer;

  // Create smooth overlapping pulse rings with animation-driven scaling
  Future<void> _createPulseRing() async {
    if (_userLocation == null) return;

    try {
      // Clean up old rings (keep max 3 sets of rings for performance - 9 total rings)
      while (_pulseRings.length >= 9) { // 3 rings per set, max 3 sets to prevent trails
        final oldRing = _pulseRings.removeAt(0);
        try {
          await _circleAnnotationManager!.delete(oldRing);
        } catch (e) {
          // Ring might already be deleted
        }
      }

      final positions = Position(_userLocation!.longitude, _userLocation!.latitude);
      
      // Get current animation value for smooth scaling
      final animValue = _pulseController.value;
      final pulsePhase = Curves.easeInOut.transform(animValue);
      
      // Create 3 concentric rings with dynamic sizing and opacity based on animation
      final baseOpacity = 0.4 - (pulsePhase * 0.3); // Fade as it pulses
      final sizeMultiplier = 1.0 + (pulsePhase * 0.4);  // Smaller growth range
      
      // Outer ring (largest, most transparent) - Reduced from 28.0 to 18.0
      final outerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: positions),
          circleRadius: 18.0 * sizeMultiplier,
          circleColor: AppTheme.primaryBlue.withOpacity(baseOpacity * 0.3).value,
          circleStrokeColor: AppTheme.primaryBlue.withOpacity(baseOpacity * 0.5).value,
          circleStrokeWidth: 1.0,
        ),
      );
      
      // Middle ring - Reduced from 20.0 to 14.0
      final middleRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: positions),
          circleRadius: 14.0 * sizeMultiplier,
          circleColor: AppTheme.primaryBlue.withOpacity(baseOpacity * 0.5).value,
          circleStrokeColor: AppTheme.primaryBlue.withOpacity(baseOpacity * 0.7).value,
          circleStrokeWidth: 1.5,
        ),
      );
      
      // Inner ring (smallest, most opaque) - Reduced from 14.0 to 10.0
      final innerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: positions),
          circleRadius: 10.0 * sizeMultiplier,
          circleColor: AppTheme.primaryBlue.withOpacity(baseOpacity * 0.7).value,
          circleStrokeColor: AppTheme.primaryBlue.withOpacity(baseOpacity).value,
          circleStrokeWidth: 2.0,
        ),
      );

      _pulseRings.addAll([outerRing, middleRing, innerRing]);

      // Schedule cleanup with staggered timing for smooth effect
      Future.delayed(const Duration(milliseconds: 1800), () async {
        try {
          await _circleAnnotationManager?.delete(outerRing);
          _pulseRings.remove(outerRing);
        } catch (e) {
          // Ring might already be deleted
        }
      });
      
      Future.delayed(const Duration(milliseconds: 2000), () async {
        try {
          await _circleAnnotationManager?.delete(middleRing);
          _pulseRings.remove(middleRing);
        } catch (e) {
          // Ring might already be deleted
        }
      });
      
      Future.delayed(const Duration(milliseconds: 2200), () async {
        try {
          await _circleAnnotationManager?.delete(innerRing);
          _pulseRings.remove(innerRing);
        } catch (e) {
          // Ring might already be deleted
        }
      });

    } catch (e) {
      print('Error creating smooth pulse rings: $e');
    }
  }

  // Start pulsing effect for driver marker
  void _startDriverPulsingEffect() {
    _driverPulseTimer?.cancel();
    // Create pulsing rings for driver every 800ms
    _driverPulseTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_driverLocation != null && _circleAnnotationManager != null) {
        _createDriverPulseRing();
      }
    });
  }

  // Create pulsing ring for driver marker
  Future<void> _createDriverPulseRing() async {
    if (_driverLocation == null) return;

    try {
      // Clean up old driver pulse rings (keep max 2 for performance)
      while (_driverPulseRings.length >= 6) { // 3 rings per set, max 2 sets
        final oldRing = _driverPulseRings.removeAt(0);
        try {
          await _circleAnnotationManager!.delete(oldRing);
        } catch (e) {
          // Ring might already be deleted
        }
      }

      final positions = Position(_driverLocation!.lng, _driverLocation!.lat);
      
      // Get current animation value for smooth scaling
      final animValue = _pulseController.value;
      final pulsePhase = Curves.easeInOut.transform(animValue);
      
      // Create pulsing rings with blue color for driver
      final baseOpacity = 0.5 - (pulsePhase * 0.4);
      final sizeMultiplier = 1.0 + (pulsePhase * 0.6);  // Slightly larger growth for driver
      
      // Outer ring (blue for driver)
      final outerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: positions),
          circleRadius: 20.0 * sizeMultiplier,
          circleColor: Colors.blue.shade400.withOpacity(baseOpacity * 0.3).value,
          circleStrokeColor: Colors.blue.shade600.withOpacity(baseOpacity * 0.5).value,
          circleStrokeWidth: 1.0,
        ),
      );
      
      // Middle ring
      final middleRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: positions),
          circleRadius: 16.0 * sizeMultiplier,
          circleColor: Colors.blue.shade500.withOpacity(baseOpacity * 0.5).value,
          circleStrokeColor: Colors.blue.shade700.withOpacity(baseOpacity * 0.7).value,
          circleStrokeWidth: 1.5,
        ),
      );
      
      // Inner ring
      final innerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: positions),
          circleRadius: 12.0 * sizeMultiplier,
          circleColor: Colors.blue.shade600.withOpacity(baseOpacity * 0.7).value,
          circleStrokeColor: Colors.blue.shade800.withOpacity(baseOpacity).value,
          circleStrokeWidth: 2.0,
        ),
      );

      _driverPulseRings.addAll([outerRing, middleRing, innerRing]);

      // Schedule cleanup with staggered timing
      Future.delayed(const Duration(milliseconds: 2000), () async {
        try {
          await _circleAnnotationManager?.delete(outerRing);
          _driverPulseRings.remove(outerRing);
        } catch (e) {
          // Ring might already be deleted
        }
      });
      
      Future.delayed(const Duration(milliseconds: 2200), () async {
        try {
          await _circleAnnotationManager?.delete(middleRing);
          _driverPulseRings.remove(middleRing);
        } catch (e) {
          // Ring might already be deleted
        }
      });
      
      Future.delayed(const Duration(milliseconds: 2400), () async {
        try {
          await _circleAnnotationManager?.delete(innerRing);
          _driverPulseRings.remove(innerRing);
        } catch (e) {
          // Ring might already be deleted
        }
      });

    } catch (e) {
      print('Error creating driver pulse ring: $e');
    }
  }

  // Enhanced marker update method
  Future<void> _updateEnhancedMapMarkers() async {
    if (_pointAnnotationManager == null) return;

    try {
      // Update pickup marker
      await _updatePickupMarker();
      
      // Update drop-off marker  
      await _updateDropoffMarker();
      
      // Update driver marker (real-time tracking) - only when tracking delivery
      if (widget.deliveryStatus != null && (widget.driverLatitude != null || widget.driverLongitude != null)) {
        debugPrint('🚗 Delivery tracking mode detected, updating driver marker');
        await _updateDriverMarker();
      } else {
        debugPrint('🚗 Location selection mode - skipping driver marker update');
      }
      
      // Update route between markers
      if (_pickupLocation != null && _deliveryLocation != null) {
        await _drawRoute();
      }
    } catch (e) {
      print('Error updating map markers: $e');
    }
  }

  // Update pickup marker
  Future<void> _updatePickupMarker() async {
    if (_pickupLocation == null) return;

    try {
      // Remove existing pickup marker circles
      for (final circle in _pickupMarkerCircles) {
        try {
          await _circleAnnotationManager!.delete(circle);
        } catch (e) {
          // Circle might already be deleted
        }
      }
      _pickupMarkerCircles.clear();

      // FIXED: Use reliable circle-based marker instead of emoji
      await _createPickupCircleMarker();
      print('Pickup marker created at: ${_pickupLocation!.lat}, ${_pickupLocation!.lng}');
    } catch (e) {
      print('Error updating pickup marker: $e');
    }
  }

  // Create reliable pickup marker using circles
  Future<void> _createPickupCircleMarker() async {
    if (_circleAnnotationManager == null || _pickupLocation == null) return;

    try {
      // DoorDash/Instacart style pickup marker
      
      // Subtle outer glow
      final outerGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 24.0,
          circleColor: const Color(0xFF10B981).withOpacity(0.15).value,
          circleStrokeColor: const Color(0xFF10B981).withOpacity(0.3).value,
          circleStrokeWidth: 1.0,
        ),
      );

      // Shadow effect
      final shadow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_pickupLocation!.lng + 0.00002, _pickupLocation!.lat - 0.00002)),
          circleRadius: 14.0,
          circleColor: Colors.black.withOpacity(0.2).value,
        ),
      );

      // Main pickup circle with professional green
      final mainMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 14.0,
          circleColor: const Color(0xFF10B981).value, // Emerald green
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 3.0,
        ),
      );

      // Inner white indicator
      final innerIndicator = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 6.0,
          circleColor: Colors.white.value,
        ),
      );

      // Track all circles for cleanup
      _pickupMarkerCircles.addAll([outerGlow, shadow, mainMarker, innerIndicator]);
    } catch (e) {
      print('Error creating pickup circle marker: $e');
    }
  }

  // Update drop-off marker
  Future<void> _updateDropoffMarker() async {
    if (_deliveryLocation == null) return;

    try {
      // Remove existing dropoff marker circles
      for (final circle in _dropoffMarkerCircles) {
        try {
          await _circleAnnotationManager!.delete(circle);
        } catch (e) {
          // Circle might already be deleted
        }
      }
      _dropoffMarkerCircles.clear();

      // FIXED: Use reliable circle-based marker instead of emoji
      await _createDropoffCircleMarker();
      print('Dropoff marker created at: ${_deliveryLocation!.lat}, ${_deliveryLocation!.lng}');
    } catch (e) {
      print('Error updating dropoff marker: $e');
    }
  }

  // Create reliable dropoff marker using circles
  Future<void> _createDropoffCircleMarker() async {
    if (_circleAnnotationManager == null || _deliveryLocation == null) return;

    try {
      // DoorDash/Instacart style delivery marker
      
      // Subtle outer glow
      final outerGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 24.0,
          circleColor: const Color(0xFFEF4444).withOpacity(0.15).value,
          circleStrokeColor: const Color(0xFFEF4444).withOpacity(0.3).value,
          circleStrokeWidth: 1.0,
        ),
      );

      // Shadow effect
      final shadow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_deliveryLocation!.lng + 0.00002, _deliveryLocation!.lat - 0.00002)),
          circleRadius: 14.0,
          circleColor: Colors.black.withOpacity(0.2).value,
        ),
      );

      // Main delivery circle with professional red
      final mainMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 14.0,
          circleColor: const Color(0xFFEF4444).value, // Professional red
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 3.0,
        ),
      );

      // Inner white indicator
      final innerIndicator = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 6.0,
          circleColor: Colors.white.value,
        ),
      );

      // Track all circles for cleanup
      _dropoffMarkerCircles.addAll([outerGlow, shadow, mainMarker, innerIndicator]);
    } catch (e) {
      print('Error creating dropoff circle marker: $e');
    }
  }

  // Update driver marker (real-time tracking with pulsing effect)
  // Update driver marker with SVG vehicle icon (real-time tracking)
  Future<void> _updateDriverMarker() async {
    debugPrint('🚗 _updateDriverMarker called for delivery tracking');
    debugPrint('🚗 _driverLocation: $_driverLocation');
    debugPrint('🚗 _pointAnnotationManager: ${_pointAnnotationManager != null ? 'exists' : 'null'}');
    debugPrint('🚗 _circleAnnotationManager: ${_circleAnnotationManager != null ? 'exists' : 'null'}');
    debugPrint('🚗 widget.driverLatitude: ${widget.driverLatitude}');
    debugPrint('🚗 widget.driverLongitude: ${widget.driverLongitude}');
    debugPrint('🚗 deliveryStatus: ${widget.deliveryStatus}');
    
    if (_driverLocation == null || _pointAnnotationManager == null) {
      debugPrint('❌ Cannot create driver marker - missing requirements:');
      debugPrint('   - _driverLocation: ${_driverLocation == null ? 'MISSING' : 'available'}');
      debugPrint('   - _pointAnnotationManager: ${_pointAnnotationManager == null ? 'MISSING' : 'available'}');
      return;
    }

    try {
      print('🚗 Starting driver marker creation process...');
      
      // Remove existing driver marker
      if (_driverMarker != null) {
        await _pointAnnotationManager!.delete(_driverMarker!);
        _driverMarker = null;
        print('🚗 Existing driver marker removed');
      }

      // Remove existing pulsing circles
      for (final circle in _driverMarkerCircles) {
        try {
          await _circleAnnotationManager!.delete(circle);
        } catch (e) {
          // Circle might already be deleted
        }
      }
      _driverMarkerCircles.clear();
      print('🚗 Existing driver circles cleared');

      // Create new SVG-based vehicle marker
      print('🚗 Creating enhanced vehicle marker...');
      await _createEnhancedVehicleMarker();
      
      // Start pulsing effect around the vehicle icon for visibility
      print('🚗 Starting pulsing effect...');
      _startDriverPulsingEffect();
      
      final vehicleType = widget.driverVehicleType ?? 'sedan';
      print('✅ Driver marker creation complete: $vehicleType at ${_driverLocation!.lat}, ${_driverLocation!.lng}');
    } catch (e) {
      print('❌ Error updating driver vehicle marker: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Get vehicle-type specific colors for map markers



}