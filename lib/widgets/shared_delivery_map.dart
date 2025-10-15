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
  
  // Multi-stop delivery support
  final bool isMultiStop;
  final List<Map<String, dynamic>>? additionalStops;

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
    this.isMultiStop = false,
    this.additionalStops,
  });

  @override
  State<SharedDeliveryMap> createState() => _SharedDeliveryMapState();
}

class _SharedDeliveryMapState extends State<SharedDeliveryMap> with TickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  PointAnnotationManager? _stopNumberAnnotationManager; // For numbered stop markers
  
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
  List<CircleAnnotation> _userLocationMarkerCircles = []; // 🧹 Track all user location circles
  List<List<CircleAnnotation>> _multiStopMarkerCircles = []; // 🚏 Track multi-stop markers
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

  // Track if user has interacted with camera to prevent auto-adjustments
  bool _hasUserInteractedWithCamera = false;
  DateTime? _lastCameraInteraction;

  // Helper method to check if additional stops list content changed
  bool _additionalStopsListChanged(List<Map<String, dynamic>>? newList, List<Map<String, dynamic>>? oldList) {
    // If both null, no change
    if (newList == null && oldList == null) return false;
    
    // If one is null and other isn't, changed
    if (newList == null || oldList == null) return true;
    
    // If different lengths, changed
    if (newList.length != oldList.length) return true;
    
    // Check each stop's coordinates (deep comparison)
    for (int i = 0; i < newList.length; i++) {
      final newStop = newList[i];
      final oldStop = oldList[i];
      
      if (newStop['latitude'] != oldStop['latitude'] ||
          newStop['longitude'] != oldStop['longitude'] ||
          newStop['address'] != oldStop['address']) {
        return true;
      }
    }
    
    return false; // No changes detected
  }

  @override
  void didUpdateWidget(SharedDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check for meaningful coordinate changes (avoid micro-updates)
    final pickupChanged = widget.pickupLatitude != oldWidget.pickupLatitude ||
        widget.pickupLongitude != oldWidget.pickupLongitude;
    final deliveryChanged = widget.deliveryLatitude != oldWidget.deliveryLatitude ||
        widget.deliveryLongitude != oldWidget.deliveryLongitude;
    final driverChanged = widget.driverLatitude != oldWidget.driverLatitude ||
        widget.driverLongitude != oldWidget.driverLongitude;
        
    final statusChanged = widget.deliveryStatus != oldWidget.deliveryStatus;
    
    // Check if additional stops changed (for multi-stop deliveries)
    // FIXED: Deep comparison of list contents, not just reference
    final additionalStopsChanged = widget.isMultiStop != oldWidget.isMultiStop ||
        _additionalStopsListChanged(widget.additionalStops, oldWidget.additionalStops);
    
    if (pickupChanged || deliveryChanged || driverChanged || statusChanged || additionalStopsChanged) {
      debugPrint('🔄 SharedDeliveryMap updating - pickup: $pickupChanged, delivery: $deliveryChanged, driver: $driverChanged, status: $statusChanged, stops: $additionalStopsChanged');
      
      // Update locations without camera adjustments for driver updates
      _updateLocationsFromWidgetSilently();
      
      // Only adjust camera for pickup/delivery changes or initial setup
      if ((pickupChanged || deliveryChanged || additionalStopsChanged) && !_hasUserInteractedWithCamera) {
        _smartCameraAdjustment();
      }
      
      // Update polyline when status changes OR when stops change
      if (statusChanged || additionalStopsChanged) {
        debugPrint('🔄 Status change: ${oldWidget.deliveryStatus} → ${widget.deliveryStatus}');
        debugPrint('🚏 Stops changed: Multi-stop=${widget.isMultiStop}, Stops count=${widget.additionalStops?.length ?? 0}');
        _updatePolylineForStatus();
      }
    }
  }

  // Update locations silently without camera adjustments (for driver tracking)
  void _updateLocationsFromWidgetSilently() {
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
    
    // Update driver location (real-time tracking) - NO CAMERA ADJUSTMENT
    if (widget.driverLatitude != null && widget.driverLongitude != null) {
      final newDriver = Position(widget.driverLongitude!, widget.driverLatitude!);
      if (_driverLocation?.lat != newDriver.lat || _driverLocation?.lng != newDriver.lng) {
        _driverLocation = newDriver;
        shouldUpdate = true;
        debugPrint('🚗 Driver location updated silently: ${newDriver.lat}, ${newDriver.lng}');
      }
    }
    
    // Only update markers, no camera adjustments
    if (shouldUpdate) {
      _updateMapMarkers();
    }
  }

  // Smart camera adjustment that respects user interaction
  void _smartCameraAdjustment() {
    // Don't adjust camera if user has interacted recently (within 10 seconds)
    if (_hasUserInteractedWithCamera && _lastCameraInteraction != null) {
      final timeSinceInteraction = DateTime.now().difference(_lastCameraInteraction!);
      if (timeSinceInteraction.inSeconds < 10) {
        debugPrint('⏱️ Skipping camera adjustment - user interacted ${timeSinceInteraction.inSeconds}s ago');
        return;
      }
    }
    
    // Adjust camera based on available locations
    if (_pickupLocation != null && _deliveryLocation != null) {
      _fitMapToBothLocations();
    } else if (_pickupLocation != null) {
      _updateMapCamera(_pickupLocation!.lat.toDouble(), _pickupLocation!.lng.toDouble());
    } else if (_deliveryLocation != null) {
      _updateMapCamera(_deliveryLocation!.lat.toDouble(), _deliveryLocation!.lng.toDouble());
    }
  }

  // Legacy method for backward compatibility - now uses silent updates
  void _updateLocationsFromWidget() {
    _updateLocationsFromWidgetSilently();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    print('Mapbox map created successfully');
    
    try {
      // Create annotation managers
      _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
      _polylineAnnotationManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
      _circleAnnotationManager = await _mapboxMap!.annotations.createCircleAnnotationManager();
      _stopNumberAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
      print('Annotation managers created (including stop numbers)');
      
      // Initialize location pucks for driver and user
      await _setupLocationPucks();
      
      // Set up camera interaction listeners
      await _setupCameraInteractionListeners();
      
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

  // Set up listeners to detect user camera interactions
  Future<void> _setupCameraInteractionListeners() async {
    try {
      // For now, we'll rely on gesture detection since camera listeners might vary by Mapbox version
      // The gesture detector in the build method will handle user interaction detection
      print('✅ Using gesture-based camera interaction detection');
    } catch (e) {
      print('❌ Error setting up camera listeners: $e');
    }
  }

  // Handle user gesture interactions (pan, zoom, etc.)
  void _onUserInteraction() {
    _hasUserInteractedWithCamera = true;
    _lastCameraInteraction = DateTime.now();
    debugPrint('👆 User gesture detected - camera auto-adjustment disabled');
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
    // Handle multi-stop mode
    if (widget.isMultiStop && widget.additionalStops != null && widget.additionalStops!.isNotEmpty) {
      await _drawMultiStopRoute();
      return;
    }
    
    // Handle single-stop mode
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

  // 🚏 Draw multi-stop route with numbered markers
  Future<void> _drawMultiStopRoute() async {
    debugPrint('');
    debugPrint('🚏 ═══════════════════════════════════════════════');
    debugPrint('🚏     MULTI-STOP ROUTE DRAWING START');
    debugPrint('🚏 ═══════════════════════════════════════════════');
    
    if (_pickupLocation == null || widget.additionalStops == null || widget.additionalStops!.isEmpty) {
      debugPrint('❌ Missing pickup or stops for multi-stop route');
      debugPrint('   - Pickup location null: ${_pickupLocation == null}');
      debugPrint('   - Additional stops null: ${widget.additionalStops == null}');
      debugPrint('   - Additional stops empty: ${widget.additionalStops?.isEmpty ?? true}');
      return;
    }

    try {
      debugPrint('📍 Pickup Location: ${_pickupLocation!.lat}, ${_pickupLocation!.lng}');
      debugPrint('🚏 Total Stops: ${widget.additionalStops!.length}');
      
      for (int i = 0; i < widget.additionalStops!.length; i++) {
        final stop = widget.additionalStops![i];
        debugPrint('   Stop ${i + 1}: ${stop['address']}');
        debugPrint('            Lat: ${stop['latitude']}, Lng: ${stop['longitude']}');
      }
      
      // Clear old multi-stop markers
      debugPrint('🧹 Clearing old multi-stop markers...');
      for (final markerList in _multiStopMarkerCircles) {
        for (final marker in markerList) {
          try {
            await _circleAnnotationManager!.delete(marker);
          } catch (e) {
            // Marker might already be deleted
          }
        }
      }
      _multiStopMarkerCircles.clear();
      debugPrint('✅ Old markers cleared');
      
      // 🔧 CRITICAL FIX: Build complete waypoints list including main delivery + additional stops
      List<Map<String, dynamic>> allWaypoints = [];
      
      // First waypoint: Main delivery destination
      if (_deliveryLocation != null) {
        allWaypoints.add({
          'latitude': _deliveryLocation!.lat,
          'longitude': _deliveryLocation!.lng,
          'address': widget.initialDeliveryAddress ?? 'Delivery Location',
        });
      }
      
      // Subsequent waypoints: Additional stops
      for (int i = 0; i < widget.additionalStops!.length; i++) {
        allWaypoints.add(widget.additionalStops![i]);
      }
      
      // 🧹 Remove duplicate waypoints (same coordinates within 10 meters)
      debugPrint('📍 Filtering duplicate waypoints...');
      final uniqueWaypoints = <Map<String, dynamic>>[];
      for (final waypoint in allWaypoints) {
        final lat = waypoint['latitude'] as double;
        final lng = waypoint['longitude'] as double;
        
        // Check if this coordinate already exists
        final isDuplicate = uniqueWaypoints.any((existing) {
          final existingLat = existing['latitude'] as double;
          final existingLng = existing['longitude'] as double;
          
          // Calculate distance difference (rough approximation)
          final latDiff = (lat - existingLat).abs();
          final lngDiff = (lng - existingLng).abs();
          
          // If difference is less than 0.0001 degrees (~11 meters), consider it duplicate
          return latDiff < 0.0001 && lngDiff < 0.0001;
        });
        
        if (!isDuplicate) {
          uniqueWaypoints.add(waypoint);
          debugPrint('   ✅ Waypoint ${uniqueWaypoints.length}: ${waypoint['address']} (${lat}, ${lng})');
        } else {
          debugPrint('   ⚠️ SKIPPED duplicate: ${waypoint['address']} (${lat}, ${lng})');
        }
      }
      
      allWaypoints = uniqueWaypoints;
      debugPrint('🚏 Total waypoints after deduplication: ${allWaypoints.length}');
      
      // Get multi-stop route with ALL waypoints
      debugPrint('🗺️ Calling MapboxService.getMultiStopRoute...');
      final route = await MapboxService.getMultiStopRoute(
        _pickupLocation!.lat.toDouble(),
        _pickupLocation!.lng.toDouble(),
        allWaypoints,
      );
      
      debugPrint('📊 Route result: ${route == null ? "NULL" : "${route.length} coordinates"}');
      
      if (route != null && route.isNotEmpty) {
        debugPrint('✅ Route data received!');
        debugPrint('   First coordinate: ${route.first}');
        debugPrint('   Last coordinate: ${route.last}');
        
        // Draw the polyline through all stops
        debugPrint('🎨 Creating polyline...');
        await _createPolyline(route, Colors.green, 'Multi-Stop Route');
        debugPrint('✅ Polyline created!');
        
        // Create numbered markers for ALL waypoints (main delivery + additional stops)
        debugPrint('📍 Creating stop markers for all waypoints...');
        for (int i = 0; i < allWaypoints.length; i++) {
          final waypoint = allWaypoints[i];
          final position = Position(waypoint['longitude'], waypoint['latitude']);
          debugPrint('   Creating marker ${i + 1} at ${waypoint['latitude']}, ${waypoint['longitude']} (${waypoint['address']})');
          final markerCircles = await _createNumberedStopMarker(i + 1, position);
          _multiStopMarkerCircles.add(markerCircles);
        }
        debugPrint('✅ All ${allWaypoints.length} stop markers created!');
        
        // Calculate and report total route info
        final distance = _calculateRouteDistance(route);
        final estimatedMinutes = _estimateDeliveryTime(distance, isToPickup: false);
        widget.onRouteCalculated?.call(distance, estimatedMinutes);
        
        debugPrint('📊 Route Statistics:');
        debugPrint('   - Distance: ${distance.toStringAsFixed(2)} km');
        debugPrint('   - Estimated Time: $estimatedMinutes minutes');
        debugPrint('   - Total Waypoints: ${allWaypoints.length}');
        debugPrint('   - Main Delivery: Yes');
        debugPrint('   - Additional Stops: ${widget.additionalStops!.length}');
        debugPrint('🎉 Multi-stop route drawing COMPLETE!');
        debugPrint('🚏 ═══════════════════════════════════════════════');
        debugPrint('');
      } else {
        debugPrint('❌ No route data returned from MapboxService!');
        debugPrint('🚏 ═══════════════════════════════════════════════');
        debugPrint('');
      }
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ CRITICAL ERROR drawing multi-stop route!');
      debugPrint('Error: $e');
      debugPrint('Stack trace:');
      debugPrint(stackTrace.toString());
      debugPrint('🚏 ═══════════════════════════════════════════════');
      debugPrint('');
    }
  }

  // Create polyline with specified color and label
  Future<void> _createPolyline(List<Map<String, double>> route, Color color, String label) async {
    try {
      debugPrint('');
      debugPrint('🎨 ═══════════════════════════════════════════════');
      debugPrint('🎨     CREATING POLYLINE: $label');
      debugPrint('🎨 ═══════════════════════════════════════════════');
      
      // 🧹 CLEANUP: Delete all previous polylines before creating new one
      if (_polylineAnnotationManager != null) {
        debugPrint('🧹 Deleting all existing polylines...');
        await _polylineAnnotationManager!.deleteAll();
        debugPrint('✅ Old polylines cleared');
      } else {
        debugPrint('⚠️ WARNING: _polylineAnnotationManager is NULL!');
        debugPrint('   This means polyline manager was never initialized!');
        return;
      }
      
      // Convert route coordinates to Position objects
      final routePositions = route.map((coord) => Position(coord['lng']!, coord['lat']!)).toList();
      
      debugPrint('� Polyline Details:');
      debugPrint('   - Label: $label');
      debugPrint('   - Total Points: ${routePositions.length}');
      debugPrint('   - First Point: ${routePositions.first.lng}, ${routePositions.first.lat}');
      debugPrint('   - Last Point: ${routePositions.last.lng}, ${routePositions.last.lat}');
      debugPrint('   - Color: 0xFF00BFFF (NEON BLUE - Deep Sky Blue)');
      debugPrint('   - Emissive Strength: 1.0 (BYPASSES dark map lighting!)');
      debugPrint('   - Width: 8.0px');
      debugPrint('   - Border: 0xFFFFFFFF (WHITE)');
      debugPrint('   - Border Width: 3.0px');
      debugPrint('   - Z-Index: 999999 (MAX)');
      
      // Create enhanced polyline with NEON BLUE + EMISSIVE STRENGTH 💙✨🔥
      // CRITICAL: lineEmissiveStrength = 1.0 prevents dark map from darkening the line!
      final polylineAnnotation = PolylineAnnotationOptions(
        geometry: LineString(coordinates: routePositions),
        
        // � NEON BLUE CORE - Unaffected by dark map lighting!
        lineColor: 0xFF00BFFF,         // � Deep Sky Blue - Bright neon blue
        lineWidth: 4.0,                // 📏 Thinner, cleaner line
        lineOpacity: 1.0,              // 🔥 Full opacity
        lineSortKey: 999999.0,         // 🚀 MAXIMUM Z-INDEX - Force above ALL map layers
        lineBlur: 0.0,                 // Sharp, crisp core
        
        // ⚪ WHITE BORDER - Creates contrast separation from dark map
        lineBorderColor: 0xFFFFFFFF,   // Pure white border
        lineBorderWidth: 1.5,          // Thinner border
        
        // 🎯 GAP WIDTH - Creates layered casing effect (outline)
        lineGapWidth: 0.5,             // Subtle gap
      );
      
      debugPrint('🔨 Creating polyline annotation...');
      await _polylineAnnotationManager!.create(polylineAnnotation);
      
      // ✨ EMISSIVE STRENGTH - THE KEY TO PREVENTING DARKENING!
      // Apply to the annotation manager (applies to ALL polylines in this manager)
      // Value of 1.0 = Final color determined ONLY by lineColor, ignoring 3D lighting
      debugPrint('🔥 Setting line emissive strength to 1.0...');
      await _polylineAnnotationManager!.setLineEmissiveStrength(1.0);
      
      debugPrint('✅ $label polyline created successfully with emissive strength!');
      debugPrint('🎨 ═══════════════════════════════════════════════');
      debugPrint('');
      
      // 📐 AUTO-FIT: Adjust camera to show complete route after drawing
      if (_pickupLocation != null && _deliveryLocation != null && routePositions.length >= 2) {
        debugPrint('📷 Auto-fitting camera to show route...');
        await _fitRouteInView(routePositions);
        debugPrint('✅ Camera fitted');
      }
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ ERROR creating $label polyline!');
      debugPrint('Error: $e');
      debugPrint('Stack trace:');
      debugPrint(stackTrace.toString());
      debugPrint('🎨 ═══════════════════════════════════════════════');
      debugPrint('');
    }
  }

  /// 📐 Automatically fits the map camera to show the complete route
  /// Calculates bounding box from route coordinates and applies padding
  Future<void> _fitRouteInView(List<Position> routePositions) async {
    try {
      if (routePositions.isEmpty || _mapboxMap == null) return;
      
      // Calculate bounding box from all route points
      double minLat = routePositions.first.lat.toDouble();
      double maxLat = routePositions.first.lat.toDouble();
      double minLng = routePositions.first.lng.toDouble();
      double maxLng = routePositions.first.lng.toDouble();
      
      for (final position in routePositions) {
        final lat = position.lat.toDouble();
        final lng = position.lng.toDouble();
        
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
      
      // Add padding to bounding box (10% on each side)
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;
      
      minLat -= latPadding;
      maxLat += latPadding;
      minLng -= lngPadding;
      maxLng += lngPadding;
      
      // Calculate center point for camera
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      
      // Calculate appropriate zoom level based on bounds size
      final latDelta = maxLat - minLat;
      final lngDelta = maxLng - minLng;
      final maxDelta = math.max(latDelta, lngDelta);
      
      // Simple zoom calculation (adjust multiplier as needed)
      final zoom = 14.0 - (math.log(maxDelta * 100) / math.ln2);
      final clampedZoom = zoom.clamp(10.0, 16.0); // Reasonable zoom range
      
      // Apply camera with calculated center and zoom
      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(centerLng, centerLat)),
          zoom: clampedZoom,
          padding: MbxEdgeInsets(
            top: 100,    // Top padding for instruction overlay
            left: 50,
            right: 50,
            bottom: 150, // Bottom padding for status indicators
          ),
          pitch: 20.0,   // Subtle 3D tilt
          bearing: 0.0,  // North-up orientation
        ),
      );
      
      debugPrint('📐 Camera fitted to route: center=($centerLat, $centerLng), zoom=$clampedZoom');
    } catch (e) {
      debugPrint('❌ Error fitting route in view: $e');
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

  // Setup location puck for customer's own location (not driver)
  Future<void> _setupLocationPucks() async {
    if (_mapboxMap == null) return;

    try {
      print('🎯 Setting up customer location puck...');
      
      // Configure user location puck (shows customer's own GPS location)
      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: true, // Show customer's location on map
        puckBearingEnabled: false, // Customer doesn't need bearing
        pulsingEnabled: true, // Subtle pulsing for customer location
        pulsingColor: const Color(0xFF0080FF).value, // Blue for customer
        pulsingMaxRadius: 40.0,
        showAccuracyRing: false, // Cleaner look
      ));
      
      print('✅ Customer location puck configured');
    } catch (e) {
      print('❌ Error setting up location puck: $e');
    }
  }

  // Calculate if driver is nearby for pulsing effect
  bool _isDriverNearby() {
    if (_driverLocation == null || _pickupLocation == null) return false;
    
    final distanceToPickup = _calculateDistance(
      _driverLocation!.lat.toDouble(),
      _driverLocation!.lng.toDouble(),
      _pickupLocation!.lat.toDouble(),
      _pickupLocation!.lng.toDouble(),
    );
    
    return distanceToPickup < 1.0; // Within 1km
  }

  // Update driver marker with pulsing when nearby
  Future<void> _updateDriverMarkerWithPulsing() async {
    if (_circleAnnotationManager == null || _driverLocation == null) return;

    try {
      // Clear existing driver markers
      for (final circle in _driverMarkerCircles) {
        try {
          await _circleAnnotationManager!.delete(circle);
        } catch (e) {
          // Ignore deletion errors
        }
      }
      _driverMarkerCircles.clear();

      final bool isNearby = _isDriverNearby();
      print('🚗 Driver marker update (nearby: $isNearby)');

      // DoorDash-inspired driver colors
      const driverOrange = Color(0xFFFF6B35); // Orange for driver
      const driverGreen = Color(0xFF00D68F); // Green when nearby
      final markerColor = isNearby ? driverGreen : driverOrange;

      // Add pulsing effect when driver is nearby
      if (isNearby) {
        // Outer pulse ring (animated effect)
        final outerPulse = await _circleAnnotationManager!.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: _driverLocation!),
            circleRadius: 50.0,
            circleColor: driverGreen.withOpacity(0.2).value,
            circleBlur: 2.0,
          ),
        );
        _driverMarkerCircles.add(outerPulse);

        // Middle pulse ring
        final middlePulse = await _circleAnnotationManager!.create(
          CircleAnnotationOptions(
            geometry: Point(coordinates: _driverLocation!),
            circleRadius: 35.0,
            circleColor: driverGreen.withOpacity(0.3).value,
            circleBlur: 1.5,
          ),
        );
        _driverMarkerCircles.add(middlePulse);
      }

      // Create subtle drop shadow for depth
      final shadowMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLocation!.lng + 0.00002, _driverLocation!.lat - 0.00002)),
          circleRadius: 18.0,
          circleColor: const Color(0x1A000000).value,
        ),
      );
      _driverMarkerCircles.add(shadowMarker);

      // Create outer white ring (clean outline)
      final outerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 20.0,
          circleColor: Colors.white.value,
        ),
      );
      _driverMarkerCircles.add(outerRing);

      // Create main driver circle
      final mainMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 16.0,
          circleColor: markerColor.value,
        ),
      );
      _driverMarkerCircles.add(mainMarker);

      // Create inner white core (directional indicator)
      final innerCore = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 6.0,
          circleColor: Colors.white.value,
        ),
      );
      _driverMarkerCircles.add(innerCore);

      print('✅ Driver marker created with ${isNearby ? 'GREEN PULSING' : 'orange color'}');
    } catch (e) {
      print('❌ Error updating driver marker: $e');
    }
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


  // Create vehicle-specific marker with pulsing when nearby
  Future<void> _createEnhancedVehicleMarker() async {
    debugPrint('🚗 _createEnhancedVehicleMarker called for delivery tracking');
    debugPrint('🚗 _driverLocation: $_driverLocation');
    
    if (_driverLocation == null) {
      debugPrint('❌ Cannot create vehicle marker - missing driver location');
      return;
    }

    try {
      final vehicleType = widget.driverVehicleType ?? 'sedan';
      debugPrint('🚗 Creating driver marker for: $vehicleType');
      debugPrint('🚗 Driver position: lat=${_driverLocation!.lat}, lng=${_driverLocation!.lng}');
      
      // Use enhanced marker with pulsing effect when nearby
      await _updateDriverMarkerWithPulsing();
      
      debugPrint('✅ Driver marker updated successfully!');
    } catch (e) {
      debugPrint('❌ Error creating vehicle marker: $e');
      // Fallback to basic circle marker if enhancement fails
      await _createFallbackVehicleMarker();
    }
  }

  // Create DoorDash-style driver marker (clean, no animation)
  Future<void> _createFallbackVehicleMarker() async {
    if (_circleAnnotationManager == null || _driverLocation == null) return;
    
    try {
      // DoorDash-inspired color scheme
      const driverBlue = Color(0xFF0073E6); // DoorDash blue
      const shadowColor = Color(0x1A000000); // Subtle shadow
      
      // Create subtle drop shadow for depth (DoorDash style)
      final shadowMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLocation!.lng + 0.00002, _driverLocation!.lat - 0.00002)),
          circleRadius: 18.0,
          circleColor: shadowColor.value,
        ),
      );
      
      // Create outer white ring (clean outline)
      final outerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 17.0,
          circleColor: Colors.white.value,
        ),
      );
      
      // Create main driver circle (vibrant blue)
      final mainMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 14.0,
          circleColor: driverBlue.value,
        ),
      );
      
      // Create inner white car icon representation
      final carIcon = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 6.0,
          circleColor: Colors.white.value,
        ),
      );
      
      // Add directional indicator (small arrow-like shape using offset circles)
      final directionDot1 = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLocation!.lng, _driverLocation!.lat + 0.00003)),
          circleRadius: 2.0,
          circleColor: driverBlue.value,
        ),
      );
      
      final directionDot2 = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLocation!.lng - 0.00002, _driverLocation!.lat + 0.00002)),
          circleRadius: 1.5,
          circleColor: driverBlue.value,
        ),
      );
      
      final directionDot3 = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(_driverLocation!.lng + 0.00002, _driverLocation!.lat + 0.00002)),
          circleRadius: 1.5,
          circleColor: driverBlue.value,
        ),
      );
      
      _driverMarkerCircles.addAll([shadowMarker, outerRing, mainMarker, carIcon, directionDot1, directionDot2, directionDot3]);
      
      debugPrint('✅ DoorDash-style ${widget.driverVehicleType} marker created');
    } catch (e) {
      debugPrint('❌ Error creating DoorDash marker: $e');
    }
  }

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
    
    // Don't adjust camera if user has interacted recently
    if (_hasUserInteractedWithCamera && _lastCameraInteraction != null) {
      final timeSinceInteraction = DateTime.now().difference(_lastCameraInteraction!);
      if (timeSinceInteraction.inSeconds < 10) {
        debugPrint('⏱️ Skipping camera fit - user interacted ${timeSinceInteraction.inSeconds}s ago');
        return;
      }
    }
    
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
      
      print('All map annotations cleared');
    } catch (e) {
      print('Error clearing annotations: $e');
    }
  }

  void _updateMapCamera(double lat, double lng) async {
    if (_mapboxMap == null) return;
    
    // Don't adjust camera if user has interacted recently
    if (_hasUserInteractedWithCamera && _lastCameraInteraction != null) {
      final timeSinceInteraction = DateTime.now().difference(_lastCameraInteraction!);
      if (timeSinceInteraction.inSeconds < 10) {
        debugPrint('⏱️ Skipping camera update - user interacted ${timeSinceInteraction.inSeconds}s ago');
        return;
      }
    }
    
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
    return Semantics(
      label: 'Interactive delivery map. ${_pickupLocation != null ? 'Pickup location selected. ' : ''}${_deliveryLocation != null ? 'Delivery location selected. ' : ''}Tap on map to set locations.',
      child: Stack(
        children: [
          // Interactive Map - FULL SCREEN WITH DARK THEME 🌙
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey("shared_delivery_map"),
              onMapCreated: _onMapCreated,
              onTapListener: _onMapTapped,
              onScrollListener: (_) => _onUserInteraction(), // ✅ Native scroll detection
              // � CUSTOM STYLE: SwiftDash branded map style with optimized visibility
              styleUri: "mapbox://styles/swiftdash/cmgqyhjx4004w01st4egv244p",
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
        
          // Map interaction instructions - FLOATING OVERLAY 🌙 DARK GLASSMORPHISM
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Semantics(
              label: 'Map instructions. Tap on map to set pickup and delivery locations',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.85), // 🌙 Dark glass background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1), // 🌙 Subtle border
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withOpacity(0.05), // 🌊 Subtle neon glow
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00F0FF).withOpacity(0.2), // 🌊 Neon cyan
                            const Color(0xFF0080FF).withOpacity(0.15), // 🌊 Blue glow
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.touch_app,
                        color: Color(0xFF00F0FF), // 🌊 Neon cyan icon
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tap to set locations',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white, // 🌙 White text for dark theme
                            ),
                          ),
                          Text(
                            'Auto-fills address fields below',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6), // 🌙 Dimmed white
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Location status indicators - BOTTOM FLOATING 🌙 DARK GLASSMORPHISM
        if (_pickupLocation != null || _deliveryLocation != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Semantics(
              label: '${_pickupLocation != null ? 'Pickup location set. ' : ''}${_deliveryLocation != null ? 'Delivery location set. ' : ''}${_pickupLocation != null && _deliveryLocation != null ? 'Route ready for navigation.' : ''}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.85), // 🌙 Dark glass background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1), // 🌙 Subtle border
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withOpacity(0.05), // 🌊 Subtle neon glow
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_pickupLocation != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00FF88).withOpacity(0.2), // 🟢 Bright green
                              const Color(0xFF00CC66).withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF00FF88).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00FF88), // 🟢 Bright neon green
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF00FF88),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Pickup',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF00FF88), // 🟢 Neon green
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
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF0066).withOpacity(0.2), // 🔴 Bright red
                              const Color(0xFFCC0055).withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFFF0066).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF0066), // 🔴 Bright neon red
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFFF0066),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Delivery',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFF0066), // 🔴 Neon red
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
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00F0FF), // 🌊 Neon cyan
                              Color(0xFF0080FF), // 🌊 Blue
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F0FF).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Route ready',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationSubscription?.cancel();
    _pulseTimer?.cancel();
    
    super.dispose();
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
    setState(() {
      _userLocation = position;
    });

    if (_mapboxMap != null && _circleAnnotationManager != null) {
      _updateUserLocationMarker(position);
    }
  }



  // Update user location marker on map (DoorDash-style, no pulsing)
  Future<void> _updateUserLocationMarker(geo.Position position) async {
    try {
      // 🧹 CLEANUP: Remove ALL existing user location markers (prevents duplicates)
      if (_userLocationMarkerCircles.isNotEmpty) {
        for (final circle in _userLocationMarkerCircles) {
          await _circleAnnotationManager!.delete(circle);
        }
        _userLocationMarkerCircles.clear();
        debugPrint('🧹 Cleared ${_userLocationMarkerCircles.length} old user location markers');
      }
      
      // Legacy cleanup (backwards compatibility)
      if (_userLocationMarker != null) {
        await _circleAnnotationManager!.delete(_userLocationMarker!);
        _userLocationMarker = null;
      }
      if (_userLocationAccuracyCircle != null) {
        await _circleAnnotationManager!.delete(_userLocationAccuracyCircle!);
        _userLocationAccuracyCircle = null;
      }

      // Create DoorDash-style user location marker
      await _createDoorDashUserLocationMarker(position);
    } catch (e) {
      print('Error updating user location marker: $e');
    }
  }

  // Create DoorDash-style user location marker
  Future<void> _createDoorDashUserLocationMarker(geo.Position position) async {
    if (_circleAnnotationManager == null) return;

    try {
      // DoorDash user location colors
      const userBlue = Color(0xFF007AFF); // iOS blue for user
      const shadowColor = Color(0x1A000000);
      
      // Create accuracy circle (subtle, clean)
      final accuracyCircle = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: math.min(position.accuracy, 50.0), // Cap accuracy circle size
          circleColor: userBlue.withOpacity(0.08).value,
          circleStrokeColor: userBlue.withOpacity(0.15).value,
          circleStrokeWidth: 1.0,
        ),
      );
      _userLocationMarkerCircles.add(accuracyCircle); // 🧹 Track for cleanup
      _userLocationAccuracyCircle = accuracyCircle; // Legacy reference

      // Create subtle drop shadow
      final shadowCircle = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude + 0.00001, position.latitude - 0.00001)),
          circleRadius: 12.0,
          circleColor: shadowColor.value,
        ),
      );
      _userLocationMarkerCircles.add(shadowCircle); // 🧹 Track for cleanup

      // Create outer white ring
      final whiteRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: 11.0,
          circleColor: Colors.white.value,
        ),
      );
      _userLocationMarkerCircles.add(whiteRing); // 🧹 Track for cleanup

      // Create main user location circle
      final mainCircle = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: 8.0,
          circleColor: userBlue.value,
        ),
      );
      _userLocationMarkerCircles.add(mainCircle); // 🧹 Track for cleanup
      _userLocationMarker = mainCircle; // Legacy reference

      // Create inner white dot (classic design)
      final innerDot = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: 3.0,
          circleColor: Colors.white.value,
        ),
      );
      _userLocationMarkerCircles.add(innerDot); // 🧹 Track for cleanup
      
      debugPrint('✅ DoorDash-style user location marker created (${_userLocationMarkerCircles.length} circles)');
    } catch (e) {
      print('❌ Error creating DoorDash user location marker: $e');
    }
  }

  // Variables for marker management (clean, no pulsing)

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

  // Create neon-glowing pickup marker 🟢 ENHANCED DARK THEME STYLE
  Future<void> _createPickupCircleMarker() async {
    if (_circleAnnotationManager == null || _pickupLocation == null) return;

    try {
      // 🌙 DARK THEME PICKUP MARKER - ENHANCED VISIBILITY
      
      // Outer glow ring (wide soft glow) - BRIGHTER
      final outerGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 35.0,                                           // Larger glow
          circleColor: const Color(0xFF00FF88).withOpacity(0.4).value,  // 🟢 Brighter neon green
          circleBlur: 2.0,                                              // More blur for glow
        ),
      );

      // Middle glow ring - ENHANCED
      final middleGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 26.0,
          circleColor: const Color(0xFF00FF88).withOpacity(0.6).value,
          circleBlur: 1.5,
        ),
      );

      // Main pickup circle with bright neon green - ENHANCED
      final mainMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 18.0,                                           // Larger
          circleColor: const Color(0xFF00FF88).value,                   // 🟢 NEON GREEN
          circleStrokeColor: Colors.white.value,                        // ⚪ WHITE BORDER for contrast
          circleStrokeWidth: 4.0,                                       // Thicker white border
          circleOpacity: 1.0,                                           // Full opacity
        ),
      );

      // Inner white core (for contrast) - ENHANCED
      final innerCore = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 8.0,                                            // Larger core
          circleColor: Colors.white.value,                              // Pure white
        ),
      );

      // Pulsing outer ring (animated effect) - ENHANCED
      final pulseRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 22.0,
          circleColor: Colors.transparent.value,
          circleStrokeColor: const Color(0xFF00FF88).withOpacity(0.9).value, // Brighter
          circleStrokeWidth: 3.5,                                       // Thicker pulse
        ),
      );

      // Track all circles for cleanup
      _pickupMarkerCircles.addAll([outerGlow, middleGlow, mainMarker, innerCore, pulseRing]);
      
      // Apply emissive strength to prevent darkening
      await _circleAnnotationManager!.setCircleEmissiveStrength(1.0);
      
      debugPrint('🟢 Neon pickup marker created with glow effect + emissive strength');
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

  // Create neon-glowing dropoff marker 🔴 ENHANCED DARK THEME STYLE
  Future<void> _createDropoffCircleMarker() async {
    if (_circleAnnotationManager == null || _deliveryLocation == null) return;

    try {
      // 🌙 DARK THEME DROPOFF MARKER - ENHANCED VISIBILITY
      
      // Outer glow ring (wide soft glow) - BRIGHTER
      final outerGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 35.0,                                           // Larger glow
          circleColor: const Color(0xFFFF0066).withOpacity(0.4).value,  // 🔴 Brighter neon red
          circleBlur: 2.0,                                              // More blur for glow
        ),
      );

      // Middle glow ring - ENHANCED
      final middleGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 26.0,
          circleColor: const Color(0xFFFF0066).withOpacity(0.6).value,
          circleBlur: 1.5,
        ),
      );

      // Main delivery circle with bright neon red - ENHANCED
      final mainMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 18.0,                                           // Larger
          circleColor: const Color(0xFFFF0066).value,                   // 🔴 NEON RED
          circleStrokeColor: Colors.white.value,                        // ⚪ WHITE BORDER for contrast
          circleStrokeWidth: 4.0,                                       // Thicker white border
          circleOpacity: 1.0,                                           // Full opacity
        ),
      );

      // Inner white core (for contrast) - ENHANCED
      final innerCore = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 8.0,                                            // Larger core
          circleColor: Colors.white.value,                              // Pure white
        ),
      );

      // Pulsing outer ring (animated effect) - ENHANCED
      final pulseRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 22.0,
          circleColor: Colors.transparent.value,
          circleStrokeColor: const Color(0xFFFF0066).withOpacity(0.9).value, // Brighter
          circleStrokeWidth: 3.5,                                       // Thicker pulse
        ),
      );

      // Track all circles for cleanup
      _dropoffMarkerCircles.addAll([outerGlow, middleGlow, mainMarker, innerCore, pulseRing]);
      
      // Apply emissive strength to prevent darkening (applies to all circles in manager)
      // Note: This affects ALL circles, so we only need to set it once
      
      debugPrint('🔴 Neon dropoff marker created with glow effect + emissive strength');
    } catch (e) {
      print('Error creating dropoff circle marker: $e');
    }
  }

  // 🚏 Create numbered marker for multi-stop delivery - ENHANCED VISIBILITY
  Future<List<CircleAnnotation>> _createNumberedStopMarker(int stopNumber, Position position) async {
    if (_circleAnnotationManager == null || _stopNumberAnnotationManager == null) return [];
    
    List<CircleAnnotation> circles = [];
    
    try {
      const stopBlue = Color(0xFF0080FF); // Blue for stops
      
      // Outer glow (largest, soft) - ENHANCED
      final outerGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: position),
          circleRadius: 35.0,                                     // Larger
          circleColor: stopBlue.withOpacity(0.4).value,          // Brighter
          circleBlur: 2.0,                                        // More blur
        ),
      );
      circles.add(outerGlow);

      // Middle glow - ENHANCED
      final middleGlow = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: position),
          circleRadius: 26.0,
          circleColor: stopBlue.withOpacity(0.6).value,
          circleBlur: 1.5,
        ),
      );
      circles.add(middleGlow);

      // Main circle (solid blue) - ENHANCED
      final mainMarker = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: position),
          circleRadius: 18.0,
          circleColor: stopBlue.value,
          circleStrokeColor: Colors.white.value,                 // ⚪ WHITE BORDER
          circleStrokeWidth: 4.0,                                // Thick border
          circleOpacity: 1.0,                                    // Full opacity
        ),
      );
      circles.add(mainMarker);

      // White ring for contrast - ENHANCED
      final whiteRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: position),
          circleRadius: 14.0,
          circleColor: Colors.white.value,
        ),
      );
      circles.add(whiteRing);

      // Inner blue circle (will contain number visually) - ENHANCED
      final innerCircle = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: position),
          circleRadius: 12.0,
          circleColor: stopBlue.value,
        ),
      );
      circles.add(innerCircle);

      // Add text number using PointAnnotation with textField - ENHANCED
      try {
        await _stopNumberAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: position),
            textField: stopNumber.toString(),
            textSize: 16.0,                                      // Larger text
            textColor: Colors.white.value,
            textHaloColor: stopBlue.value,
            textHaloWidth: 3.0,                                  // Thicker halo
            textHaloBlur: 0.5,
            textOffset: [0.0, 0.0],
            iconSize: 0.0, // No icon, just text
          ),
        );
        debugPrint('🚏 Numbered marker created for stop $stopNumber with text');
      } catch (e) {
        debugPrint('⚠️ Error adding text to marker: $e');
      }

      return circles;
    } catch (e) {
      debugPrint('❌ Error creating numbered stop marker: $e');
      return circles;
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

      // Create new DoorDash-style vehicle marker (no pulsing)
      print('🚗 Creating DoorDash-style vehicle marker...');
      await _createEnhancedVehicleMarker();
      
      final vehicleType = widget.driverVehicleType ?? 'sedan';
      print('✅ Driver marker creation complete: $vehicleType at ${_driverLocation!.lat}, ${_driverLocation!.lng}');
    } catch (e) {
      print('❌ Error updating driver vehicle marker: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Get vehicle-type specific colors for map markers



}