import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert'; // For JSON encoding
import 'dart:math' as math;

import '../services/mapbox_service.dart';
import '../services/driver_marker_service.dart';
import '../services/map_marker_service.dart';
import '../constants/app_theme.dart';

// Polyline phases for delivery tracking
enum PolylinePhase {
  none,           // No polyline needed (arrived, pending, etc.)
  driverToPickup, // Phase 1: Driver heading to pickup location
  driverToDelivery, // Phase 2: Driver with package heading to delivery
  pickupToDelivery, // Phase 2 (deprecated): Pickup to delivery for old tracking
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
  final String? driverProfilePictureUrl;
  final String? driverId;
  
  // Multi-stop delivery support
  final bool isMultiStop;
  final List<Map<String, dynamic>>? additionalStops;

  // Traffic-aware routing (Matrix API) - ONLY for location selection screen
  final List<Map<String, dynamic>>? trafficSegments;

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
    this.driverProfilePictureUrl,
    this.driverId,
    this.isMultiStop = false,
    this.additionalStops,
    this.trafficSegments,
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
  
  // Driver interpolation for smooth movement
  Position? _driverInterpolationStart;
  Position? _driverInterpolationTarget;
  late AnimationController _driverAnimationController;
  Animation<double>? _driverLatAnimation;
  Animation<double>? _driverLngAnimation;
  
  // Debouncer for location updates (prevent animation spam)
  Timer? _locationUpdateDebouncer;
  Position? _pendingDriverLocation;
  
  // 🚗 Polyline update tracking (to reduce polyline as driver moves)
  Position? _lastPolylineUpdatePosition;
  DateTime? _lastPolylineUpdateTime;
  
  // 🎬 Line trim animation for traffic polylines
  late AnimationController _lineTrimController;
  Animation<double>? _lineTrimAnimation;
  
  // Vehicle marker management
  PointAnnotation? _driverMarker;
  bool _vehicleIconsLoaded = false;
  
  // User location (using Geolocator Position for GPS)
  geo.Position? _userLocation;
  
  // Marker tracking
  PointAnnotation? _pickupMarker; // Track pickup pin marker
  PointAnnotation? _deliveryMarker; // Track delivery pin marker
  List<PointAnnotation> _additionalStopMarkers = []; // Track multi-stop markers
  List<CircleAnnotation> _pickupMarkerCircles = [];
  List<CircleAnnotation> _dropoffMarkerCircles = [];
  List<CircleAnnotation> _driverMarkerCircles = [];
  List<CircleAnnotation> _userLocationMarkerCircles = []; // 🧹 Track all user location circles
  List<List<CircleAnnotation>> _multiStopMarkerCircles = []; // 🚏 Track multi-stop markers
  CircleAnnotation? _userLocationMarker;
  CircleAnnotation? _userLocationAccuracyCircle;
  
  // 🔧 PERFORMANCE: Track marker existence to prevent unnecessary recreation
  bool _pickupMarkerExists = false;
  bool _deliveryMarkerExists = false;
  bool _driverMarkerExists = false;
  bool _polylineExists = false;
  
  // 🔧 PERFORMANCE: Profile picture download state (prevent repeated failures)
  String? _lastAttemptedProfileUrl;
  bool _profilePictureDownloadFailed = false;
  
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
    
    // Initialize driver interpolation animation controller
    _driverAnimationController = AnimationController(
      duration: const Duration(seconds: 5), // Match typical GPS update interval
      vsync: this,
    );
    
    // Listen to animation updates to smoothly move driver marker
    _driverAnimationController.addListener(() {
      if (_driverLatAnimation != null && _driverLngAnimation != null && mounted) {
        final newPosition = Position(
          _driverLngAnimation!.value,
          _driverLatAnimation!.value,
        );
        
        setState(() {
          _driverLocation = newPosition;
        });
        
        // Update marker position on map during animation
        if (_driverMarker != null && _pointAnnotationManager != null) {
          _driverMarker!.geometry = Point(coordinates: newPosition);
          _pointAnnotationManager!.update(_driverMarker!);
        }
      }
    });
    
    // 🎬 Initialize line trim animation controller for traffic polylines
    _lineTrimController = AnimationController(
      duration: const Duration(milliseconds: 2500), // 2.5 seconds for smoother, more visible animation
      vsync: this,
    );
    
    // Create tween animation from 0.0 (hidden) to 1.0 (fully visible)
    _lineTrimAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lineTrimController,
      curve: Curves.easeOut, // Start fast, slow down at the end (feels more natural)
    ));
    
    // Listen to line trim animation to update map
    _lineTrimController.addListener(() {
      if (_mapboxMap != null && mounted) {
        _updateLineTrimOffset();
      }
    });
    
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
      
      // 🔧 PERFORMANCE FIX: Only update what changed, don't recreate everything
      
      // Update pickup marker ONLY when pickup changes
      if (pickupChanged && widget.pickupLatitude != null && widget.pickupLongitude != null) {
        _pickupLocation = Position(widget.pickupLongitude!, widget.pickupLatitude!);
        _updatePickupMarkerOnly();
        _pickupMarkerExists = true;
        
        // Adjust camera for pickup changes (if user hasn't interacted)
        if (!_hasUserInteractedWithCamera) {
          _smartCameraAdjustment();
        }
      }
      
      // Update delivery marker ONLY when delivery changes
      if (deliveryChanged && widget.deliveryLatitude != null && widget.deliveryLongitude != null) {
        _deliveryLocation = Position(widget.deliveryLongitude!, widget.deliveryLatitude!);
        _updateDropoffMarkerOnly();
        _deliveryMarkerExists = true;
        
        // Adjust camera for delivery changes (if user hasn't interacted)
        if (!_hasUserInteractedWithCamera) {
          _smartCameraAdjustment();
        }
      }
      
      // Update multi-stop markers when stops change
      if (additionalStopsChanged) {
        debugPrint('🚏 Stops changed: Multi-stop=${widget.isMultiStop}, Stops count=${widget.additionalStops?.length ?? 0}');
        _updateMultiStopMarkers();
        
        // Adjust camera for stop changes
        if (!_hasUserInteractedWithCamera) {
          _smartCameraAdjustment();
        }
      }
      
      // Update driver position ONLY when driver changes
      if (driverChanged && widget.driverLatitude != null && widget.driverLongitude != null) {
        final newDriver = Position(widget.driverLongitude!, widget.driverLatitude!);
        
        if (_driverLocation == null || !_driverMarkerExists) {
          // First time - create marker immediately (no debounce)
          _driverLocation = newDriver;
          _updateDriverMarkerOnly();
          _driverMarkerExists = true;
          debugPrint('🚗 Driver marker created for first time: ${newDriver.lat}, ${newDriver.lng}');
          
          // ONLY draw polyline if this is the very first driver location AND no polyline exists
          if (!_polylineExists && _pickupLocation != null && _deliveryLocation != null) {
            debugPrint('🔄 Initial polyline creation with first driver location');
            _updatePolylineForStatus().then((_) {
              if (mounted) {
                setState(() {
                  _polylineExists = true;
                });
              }
            });
          }
        } else {
          // Subsequent updates - debounce to prevent animation spam
          _debouncedDriverUpdate(newDriver);
        }
      }
      
      // Update polyline ONLY when:
      // 1. Status changes (delivery phase transitions)
      // 2. Stops change (multi-stop routing updates)
      // 3. Pickup or delivery locations change (route needs recalculation)
      // NOTE: Driver location changes do NOT trigger polyline redraw!
      
      if (statusChanged || additionalStopsChanged || pickupChanged || deliveryChanged) {
        // Reset polyline flag when locations change to force full redraw
        if (pickupChanged || deliveryChanged) {
          _polylineExists = false;
          debugPrint('🔄 Location changed - clearing and redrawing route');
          debugPrint('   - Pickup changed: $pickupChanged, Delivery changed: $deliveryChanged');
        } else {
          debugPrint('🔄 Status/stops changed - updating polyline');
          debugPrint('   - Status: ${oldWidget.deliveryStatus} → ${widget.deliveryStatus}');
        }
        
        // Call async method to update polyline - it will clear old ones first
        _updatePolylineForStatus().then((_) {
          if (mounted) {
            setState(() {
              _polylineExists = true;
            });
          }
        });
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
    
    // Update driver location (real-time tracking) - SMOOTH INTERPOLATION
    if (widget.driverLatitude != null && widget.driverLongitude != null) {
      final newDriver = Position(widget.driverLongitude!, widget.driverLatitude!);
      if (_driverLocation?.lat != newDriver.lat || _driverLocation?.lng != newDriver.lng) {
        // CRITICAL FIX: Set driver location immediately so marker can be created
        if (_driverLocation == null) {
          // First time - set immediately without animation
          _driverLocation = newDriver;
          debugPrint('🚗 Driver location set for first time: ${newDriver.lat}, ${newDriver.lng}');
        } else {
          // Subsequent updates - animate smoothly
          _animateDriverToPosition(newDriver);
          debugPrint('🎬 Driver location animation started to: ${newDriver.lat}, ${newDriver.lng}');
        }
        shouldUpdate = true;
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

  // Animate driver marker smoothly from current position to target position
  void _animateDriverToPosition(Position targetPosition) {
    // Get start position (current location or target if first update)
    final startPosition = _driverLocation ?? targetPosition;
    
    // Don't animate if positions are identical
    if (startPosition.lat == targetPosition.lat && startPosition.lng == targetPosition.lng) {
      return;
    }
    
    // Calculate distance to determine animation duration
    final distance = _calculateDistance(
      startPosition.lat.toDouble(),
      startPosition.lng.toDouble(),
      targetPosition.lat.toDouble(),
      targetPosition.lng.toDouble(),
    );
    
    // Adjust animation duration based on distance
    // OPTIMIZED: Match animation speed to typical GPS update frequency (3 seconds)
    // This ensures smooth tracking without lag at high speeds (60km/h)
    Duration animationDuration;
    if (distance > 0.3) {
      // Distance > 300m - likely GPS jump or very high speed, update instantly
      setState(() {
        _driverLocation = targetPosition;
      });
      debugPrint('⚡ Large distance jump (${distance.toStringAsFixed(0)}m), updating instantly');
      return;
    } else if (distance > 0.1) {
      // 100-300m - high speed driving (60-100 km/h)
      // Use 3 seconds to match typical GPS update frequency
      animationDuration = const Duration(milliseconds: 2800);
    } else if (distance > 0.03) {
      // 30-100m - normal city driving (30-50 km/h)
      // Use 2.5 seconds for smooth tracking
      animationDuration = const Duration(milliseconds: 2500);
    } else {
      // < 30m - slow movement or stopped
      // Use 2 seconds for short distances
      animationDuration = const Duration(seconds: 2);
    }
    
    // Store interpolation endpoints
    _driverInterpolationStart = startPosition;
    _driverInterpolationTarget = targetPosition;
    
    // Update animation duration
    _driverAnimationController.duration = animationDuration;
    
    // Create tween animations for latitude and longitude
    _driverLatAnimation = Tween<double>(
      begin: startPosition.lat.toDouble(),
      end: targetPosition.lat.toDouble(),
    ).animate(CurvedAnimation(
      parent: _driverAnimationController,
      curve: Curves.linear, // Constant speed for realistic movement
    ));
    
    _driverLngAnimation = Tween<double>(
      begin: startPosition.lng.toDouble(),
      end: targetPosition.lng.toDouble(),
    ).animate(CurvedAnimation(
      parent: _driverAnimationController,
      curve: Curves.linear,
    ));
    
    // Start animation from beginning
    _driverAnimationController.forward(from: 0.0);
    
    debugPrint('🎬 Driver animation: ${distance.toStringAsFixed(0)}m over ${animationDuration.inSeconds}s');
    debugPrint('   From: (${startPosition.lat}, ${startPosition.lng})');
    debugPrint('   To: (${targetPosition.lat}, ${targetPosition.lng})');
  }

  // Debounced driver location update to prevent animation spam
  void _debouncedDriverUpdate(Position newPosition) {
    // Store the latest position
    _pendingDriverLocation = newPosition;
    
    // Cancel previous debounce timer
    _locationUpdateDebouncer?.cancel();
    
    // Set new debounce timer (150ms - short enough to feel instant, long enough to batch rapid updates)
    _locationUpdateDebouncer = Timer(const Duration(milliseconds: 150), () {
      if (_pendingDriverLocation != null && mounted) {
        _animateDriverToPosition(_pendingDriverLocation!);
        debugPrint('🎬 Debounced driver position animated to: ${_pendingDriverLocation!.lat}, ${_pendingDriverLocation!.lng}');
        
        // 🔄 Check if we need to update the polyline as driver moves
        _checkAndUpdatePolylineIfNeeded(_pendingDriverLocation!);
      }
    });
  }

  // 🔄 Check if driver has moved significantly and update polyline to reduce it
  void _checkAndUpdatePolylineIfNeeded(Position currentDriverPosition) {
    // Only update polyline if driver is actively delivering (going to pickup or delivery)
    final polylinePhase = _getPolylinePhase();
    if (polylinePhase != PolylinePhase.driverToPickup && 
        polylinePhase != PolylinePhase.driverToDelivery) {
      return; // No need to update polyline if not in active delivery phase
    }
    
    // Don't update if we haven't set an initial polyline yet
    if (_lastPolylineUpdatePosition == null) {
      _lastPolylineUpdatePosition = currentDriverPosition;
      _lastPolylineUpdateTime = DateTime.now();
      return;
    }
    
    // Calculate distance from last polyline update
    final distanceFromLastUpdate = _calculateDistance(
      _lastPolylineUpdatePosition!.lat.toDouble(),
      _lastPolylineUpdatePosition!.lng.toDouble(),
      currentDriverPosition.lat.toDouble(),
      currentDriverPosition.lng.toDouble(),
    );
    
    // Time since last update
    final timeSinceLastUpdate = DateTime.now().difference(_lastPolylineUpdateTime ?? DateTime.now());
    
    // Update polyline if driver has moved 75+ meters OR 30+ seconds have passed
    // This ensures polyline stays current while preventing excessive API calls
    if (distanceFromLastUpdate > 0.075 || timeSinceLastUpdate.inSeconds > 30) {
      debugPrint('🔄 Driver moved ${(distanceFromLastUpdate * 1000).toStringAsFixed(0)}m - updating polyline to reduce route');
      
      // Update tracking variables
      _lastPolylineUpdatePosition = currentDriverPosition;
      _lastPolylineUpdateTime = DateTime.now();
      
      // Trigger polyline recalculation from new driver position
      _updatePolylineForStatus();
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    print('Mapbox map created successfully');
    
    // Defer heavy initialization to prevent main thread blocking
    // This allows the map to render immediately while setup happens in background
    Future.microtask(() async {
      try {
        // Create annotation managers sequentially but wrapped in microtask
        // to prevent blocking the main thread during map initialization
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
        
        // Load vehicle icons for map markers (async, non-blocking)
        _loadVehicleIcons();
        
        // 🔧 CRITICAL FIX: Initialize driver location from widget props NOW
        // This ensures _driverLocation is set when map is ready
        if (widget.driverLatitude != null && widget.driverLongitude != null) {
          _driverLocation = Position(widget.driverLongitude!, widget.driverLatitude!);
          debugPrint('🚗 Driver location initialized on map creation: ${_driverLocation!.lat}, ${_driverLocation!.lng}');
        }
        
        // Update markers if locations are already set (non-blocking)
        _updateMapMarkers();
        
        // 🎯 Enable native Mapbox location puck (replaces custom user location marker)
        _enableNativeUserLocationPuck();
        
        // Auto-focus on user location when map loads
        _autoFocusOnUserLocation();
      } catch (e) {
        print('Error setting up map annotations: $e');
      }
    });
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

  // 🎯 Enable native Mapbox location puck (simple blue dot, no direction arrow)
  Future<void> _enableNativeUserLocationPuck() async {
    if (_mapboxMap == null) return;
    
    try {
      debugPrint('🎯 Enabling native user location puck...');
      
      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        // Basic settings
        enabled: true,
        
        // NO direction arrow (simple dot only)
        puckBearingEnabled: false,
        
        // Smooth pulsing animation (native GPU-accelerated)
        pulsingEnabled: true,
        pulsingColor: const Color(0xFF007AFF).value, // iOS blue
        pulsingMaxRadius: 50.0,
        
        // Accuracy ring (auto-scaled based on GPS accuracy)
        showAccuracyRing: true,
        accuracyRingColor: const Color(0xFF007AFF).withOpacity(0.08).value,
        accuracyRingBorderColor: const Color(0xFF007AFF).withOpacity(0.15).value,
      ));
      
      debugPrint('✅ Native location puck enabled (no direction, with pulsing)');
    } catch (e) {
      debugPrint('❌ Error enabling native location puck: $e');
      // Fall back to manual location tracking if native fails
      _startLocationTracking();
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
    // Only handle map taps if onLocationSelected callback is provided (location selection mode)
    if (widget.onLocationSelected == null) {
      // Tracking mode - no location selection allowed
      return;
    }
    
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
      // 🧹 Use centralized clearing method
      await clearAllPolylines();
      print('🗺️ Cleared existing polylines for status update');
      
      // Determine polyline phase based on delivery status
      final polylinePhase = _getPolylinePhase();
      print('🗺️ Polyline phase: $polylinePhase');
      
      switch (polylinePhase) {
        case PolylinePhase.driverToPickup:
          await _drawDriverToPickupRoute();
          break;
        case PolylinePhase.driverToDelivery:
          await _drawDriverToDeliveryRoute();
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
        phase = PolylinePhase.driverToDelivery; // Driver with package → delivery
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
      
      // Check if traffic segments are available (from tracking screen)
      if (widget.trafficSegments != null && widget.trafficSegments!.isNotEmpty) {
        print('🚦 Using traffic-aware polylines for Driver → Pickup route');
        await _createTrafficPolylines(widget.trafficSegments!, 'Driver → Pickup (Traffic)');
        
        // Calculate distance from traffic segments
        double totalDistance = 0.0;
        for (final segment in widget.trafficSegments!) {
          final distance = segment['distance'] as num?;
          if (distance != null) {
            totalDistance += distance.toDouble();
          }
        }
        
        // Convert meters to kilometers
        final distanceKm = totalDistance / 1000.0;
        final estimatedMinutes = _estimateDeliveryTime(distanceKm, isToPickup: true);
        widget.onRouteCalculated?.call(distanceKm, estimatedMinutes);
        
        print('✅ Traffic route created: ${distanceKm.toStringAsFixed(1)}km, ${estimatedMinutes.toStringAsFixed(0)} min');
      } else {
        // Fallback to simple polyline if no traffic data
        print('🗺️ Using simple polyline for Driver → Pickup (no traffic data)');
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

  // Draw route from driver's current location to delivery (when package collected)
  Future<void> _drawDriverToDeliveryRoute() async {
    print('🗺️ _drawDriverToDeliveryRoute called');
    print('🗺️ _driverLocation: ${_driverLocation != null ? '(${_driverLocation!.lat}, ${_driverLocation!.lng})' : 'null'}');
    print('🗺️ _deliveryLocation: ${_deliveryLocation != null ? '(${_deliveryLocation!.lat}, ${_deliveryLocation!.lng})' : 'null'}');
    
    if (_driverLocation == null || _deliveryLocation == null) {
      print('❌ Missing driver or delivery location for Driver → Delivery route');
      print('   - Driver location: ${_driverLocation == null ? 'MISSING' : 'available'}');
      print('   - Delivery location: ${_deliveryLocation == null ? 'MISSING' : 'available'}');
      return;
    }
    
    try {
      print('🗺️ Drawing Driver → Delivery route (package collected)');
      print('🗺️ Route coordinates: (${_driverLocation!.lat}, ${_driverLocation!.lng}) → (${_deliveryLocation!.lat}, ${_deliveryLocation!.lng})');
      
      // Check if traffic segments are available (from tracking screen)
      if (widget.trafficSegments != null && widget.trafficSegments!.isNotEmpty) {
        print('🚦 Using traffic-aware polylines for Driver → Delivery route');
        await _createTrafficPolylines(widget.trafficSegments!, 'Driver → Delivery (Traffic)');
        
        // Calculate distance from traffic segments
        double totalDistance = 0.0;
        for (final segment in widget.trafficSegments!) {
          final distance = segment['distance'] as num?;
          if (distance != null) {
            totalDistance += distance.toDouble();
          }
        }
        
        // Convert meters to kilometers
        final distanceKm = totalDistance / 1000.0;
        final estimatedMinutes = _estimateDeliveryTime(distanceKm, isToPickup: false);
        widget.onRouteCalculated?.call(distanceKm, estimatedMinutes);
        
        print('✅ Traffic route created: ${distanceKm.toStringAsFixed(1)}km, ${estimatedMinutes.toStringAsFixed(0)} min');
      } else {
        // Fallback to simple polyline if no traffic data
        print('🗺️ Using simple polyline for Driver → Delivery (no traffic data)');
        final route = await MapboxService.getRoute(
          _driverLocation!.lat.toDouble(), _driverLocation!.lng.toDouble(),
          _deliveryLocation!.lat.toDouble(), _deliveryLocation!.lng.toDouble()
        );
        
        if (route != null) {
          // Use DoorDash-style delivery purple
          await _createPolyline(route, const Color(0xFF8B5CF6), 'Driver → Delivery');
          
          // Calculate and report ETA
          final distance = _calculateRouteDistance(route);
          final estimatedMinutes = _estimateDeliveryTime(distance, isToPickup: false);
          widget.onRouteCalculated?.call(distance, estimatedMinutes);
        }
      }
    } catch (e) {
      print('❌ Error drawing driver to delivery route: $e');
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
      
      // Check if traffic segments are available (from Matrix API)
      if (widget.trafficSegments != null && widget.trafficSegments!.isNotEmpty) {
        print('🚦 Using traffic-aware polylines for route preview');
        await _createTrafficPolylines(widget.trafficSegments!, 'Route Preview (Traffic)');
        
        // Calculate distance from traffic segments
        double totalDistance = 0.0;
        for (final segment in widget.trafficSegments!) {
          final distance = segment['distance'] as num?;
          if (distance != null) {
            totalDistance += distance.toDouble();
          }
        }
        
        // Convert meters to kilometers
        final distanceKm = totalDistance / 1000.0;
        final estimatedMinutes = _estimateDeliveryTime(distanceKm, isToPickup: false);
        widget.onRouteCalculated?.call(distanceKm, estimatedMinutes);
        
        print('✅ Traffic route preview created: ${distanceKm.toStringAsFixed(1)}km, ${estimatedMinutes.toStringAsFixed(0)} min');
      } else {
        // Fallback to simple polyline if no traffic data
        print('🗺️ Using simple polyline for route preview (no traffic data)');
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
      
      // 🧹 Use centralized clearing methods
      debugPrint('🧹 Clearing old multi-stop markers and polylines...');
      await clearMultiStopMarkers();
      await clearAllPolylines();
      debugPrint('✅ Old markers and polylines cleared');
      
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
        lineWidth: 2.5,                // 📏 Thinner line
        lineOpacity: 1.0,              // 🔥 Full opacity
        lineSortKey: 999999.0,         // 🚀 MAXIMUM Z-INDEX - Force above ALL map layers
        lineBlur: 0.0,                 // Sharp, crisp core
        
        // ⚪ WHITE BORDER - Creates contrast separation from dark map
        lineBorderColor: 0xFFFFFFFF,   // Pure white border
        lineBorderWidth: 1.0,          // Thinner border
        
        // 🎯 GAP WIDTH - Creates layered casing effect (outline)
        lineGapWidth: 0.3,             // Smaller gap
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
      
      // IMPORTANT: Mark polyline as existing so future updates work correctly
      _polylineExists = true;
      
      // 📐 AUTO-FIT: Adjust camera to show complete route (only if user hasn't interacted recently)
      if (!_hasUserInteractedWithCamera && _pickupLocation != null && _deliveryLocation != null && routePositions.length >= 2) {
        debugPrint('📷 Auto-fitting camera to show route...');
        await _fitRouteInView(routePositions);
        debugPrint('✅ Camera fitted');
      } else if (_hasUserInteractedWithCamera) {
        debugPrint('⏭️ Skipping camera auto-fit - user has interacted with map');
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

  // Create traffic-aware polylines using GeoJSON source and LineLayer (Mapbox best practice)
  Future<void> _createTrafficPolylines(List<Map<String, dynamic>> trafficSegments, String label) async {
    try {
      if (_mapboxMap == null) {
        print('❌ Mapbox map not initialized');
        return;
      }
      
      print('🚦 ═══════════════════════════════════════════════');
      print('🚦 Creating traffic route using GeoJSON + LineLayer');
      print('🚦 Total segments: ${trafficSegments.length}');
      print('🚦 ═══════════════════════════════════════════════');
      
      // Step 1: Remove existing traffic layers and sources if they exist
      try {
        await _mapboxMap!.style.removeStyleLayer('traffic-route-layer');
        print('  ✅ Removed old traffic layer');
      } catch (e) {
        print('  ℹ️ No existing traffic layer to remove');
      }
      
      try {
        await _mapboxMap!.style.removeStyleSource('traffic-route-source');
        print('  ✅ Removed old traffic source');
      } catch (e) {
        print('  ℹ️ No existing traffic source to remove');
      }
      
      // Step 2: Build GeoJSON FeatureCollection with traffic segments
      // Each segment will have a 'congestion' property for color mapping
      final List<Map<String, dynamic>> features = [];
      
      for (int i = 0; i < trafficSegments.length; i++) {
        final segment = trafficSegments[i];
        final coordinates = segment['coordinates'] as List<dynamic>;
        final congestion = segment['congestion'] as String? ?? 'unknown';
        
        // Convert coordinates to GeoJSON format [lng, lat]
        final geoJsonCoords = coordinates.map((coord) {
          return [
            (coord['lng'] as num).toDouble(),
            (coord['lat'] as num).toDouble(),
          ];
        }).toList();
        
        // Create a LineString feature for this segment
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': geoJsonCoords,
          },
          'properties': {
            'congestion': congestion,
            'segment_index': i,
          },
        });
      }
      
      // Build complete GeoJSON FeatureCollection
      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };
      
      print('📊 GeoJSON created with ${features.length} features');
      
      // Step 3: Add GeoJSON source to map
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: 'traffic-route-source',
        data: json.encode(geoJson),
        lineMetrics: true, // 🎬 ENABLE line metrics for trim animation!
      ));
      print('  ✅ Added GeoJSON source (with line metrics for animation)');
      
      // Step 4: Add LineLayer with color expression based on congestion property
      // This is the key - using Mapbox expressions for dynamic styling!
      await _mapboxMap!.style.addLayer(LineLayer(
        id: 'traffic-route-layer',
        sourceId: 'traffic-route-source',
        
        // Line width (can vary by zoom level like in Mapbox example)
        lineWidth: 5.0,
        
        // Line color - use match expression to map congestion levels to colors
        lineColorExpression: [
          'match',
          ['get', 'congestion'],
          'low', 0xFF00E5FF,       // Cyan - light traffic
          'moderate', 0xFFFFD700,  // Yellow - moderate traffic
          'heavy', 0xFFFF8C00,     // Orange - heavy traffic
          'severe', 0xFFFF0000,    // Red - severe traffic
          0xFF00BFFF,              // Default blue for unknown
        ],
        
        // Border for better visibility
        lineBorderColor: 0xFFFFFFFF, // White border
        lineBorderWidth: 1.5,
        
        // Line properties for smooth rendering
        lineOpacity: 1.0,
        lineCap: LineCap.ROUND,
        lineJoin: LineJoin.ROUND,
        
        // Visual effects
        lineBlur: 0.0,
        lineGapWidth: 0.0,
        
        // 🎬 ANIMATION: Line trim offset for animated drawing effect
        // Start fully hidden [1, 1] and will animate to [0, 1] (fully visible)
        lineTrimOffset: [1.0, 1.0],
      ));
      print('  ✅ Added LineLayer with traffic colors and trim animation');
      
      // Apply emissive strength to prevent darkening on dark maps
      await _mapboxMap!.style.setStyleLayerProperty(
        'traffic-route-layer',
        'line-emissive-strength',
        1.0,
      );
      print('  ✅ Applied emissive strength');
      
      // IMPORTANT: Mark polyline as existing so future updates work correctly
      _polylineExists = true;
      
      // 🎬 START LINE TRIM ANIMATION - Draw the line from start to finish!
      _lineTrimController.forward(from: 0.0);
      print('  🎬 Started line trim animation');
      
      print('✅ Traffic route created using GeoJSON + LineLayer!');
      print('🚦 ═══════════════════════════════════════════════');
      
    } catch (e, stackTrace) {
      print('❌ Error creating traffic polylines: $e');
      print('Stack trace: $stackTrace');
    }
  }
  
  /// 🎬 Updates the line trim offset during animation
  /// This creates the "drawing" effect as the line appears from start to finish
  void _updateLineTrimOffset() async {
    if (_mapboxMap == null || _lineTrimAnimation == null) return;
    
    try {
      // Calculate trim offset based on animation progress
      // Animation goes from 0.0 → 1.0
      // Trim offset needs to go from [1, 1] (hidden) → [0, 1] (fully visible)
      final progress = _lineTrimAnimation!.value;
      final trimStart = 1.0 - progress; // 1.0 → 0.0
      
      // Update the line trim offset property
      await _mapboxMap!.style.setStyleLayerProperty(
        'traffic-route-layer',
        'line-trim-offset',
        [trimStart, 1.0],
      );
    } catch (e) {
      // Silently fail if layer doesn't exist (might be removed during animation)
    }
  }
  
  // Get color based on traffic congestion level
  int _getTrafficColor(String? congestion) {
    switch (congestion) {
      case 'low':
        return 0xFF00E5FF; // Bright Cyan - Light traffic
      case 'moderate':
        return 0xFFFFD700; // Bright Yellow - Moderate traffic
      case 'heavy':
        return 0xFFFF8C00; // Bright Orange - Heavy traffic
      case 'severe':
        return 0xFFFF0000; // Bright Red - Severe traffic
      default:
        return 0xFF00BFFF; // Default bright blue for unknown
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


  // Create vehicle-specific marker with profile picture or fallback to Mapbox default
  Future<void> _createEnhancedVehicleMarker() async {
    debugPrint('🚗 _createEnhancedVehicleMarker called for delivery tracking');
    debugPrint('🚗 _driverLocation: $_driverLocation');
    
    if (_driverLocation == null) {
      debugPrint('❌ Cannot create vehicle marker - missing driver location');
      return;
    }

    // Clear existing driver markers first
    for (final circle in _driverMarkerCircles) {
      try {
        await _circleAnnotationManager?.delete(circle);
      } catch (e) {
        // Ignore deletion errors
      }
    }
    _driverMarkerCircles.clear();

    // Try to use profile picture if available
    if (widget.driverProfilePictureUrl != null && 
        widget.driverProfilePictureUrl!.isNotEmpty &&
        widget.driverId != null) {
      debugPrint('� Attempting to use driver profile picture: ${widget.driverProfilePictureUrl}');
      
      // 🔧 PERFORMANCE: Check if we already know this URL fails
      if (_lastAttemptedProfileUrl == widget.driverProfilePictureUrl && _profilePictureDownloadFailed) {
        debugPrint('⏭️ Skipping profile picture - known failure');
      } else {
        _lastAttemptedProfileUrl = widget.driverProfilePictureUrl;
        
        final success = await _createProfilePictureMarker();
        if (success) {
          debugPrint('✅ Driver profile picture marker created successfully!');
          _profilePictureDownloadFailed = false;
          return;
        } else {
          debugPrint('⚠️ Profile picture marker failed, using Mapbox default');
          _profilePictureDownloadFailed = true;
        }
      }
    } else {
      debugPrint('ℹ️ No profile picture URL available, using Mapbox default marker');
    }

    // Fallback: Use Mapbox's built-in location puck
    await _createMapboxDefaultMarker();
  }

  /// Create driver marker using profile picture (circular with border)
  Future<bool> _createProfilePictureMarker() async {
    try {
      if (_pointAnnotationManager == null || _driverLocation == null) {
        return false;
      }

      // Download and process profile picture
      final markerImage = await DriverMarkerService.createDriverMarker(
        profilePictureUrl: widget.driverProfilePictureUrl!,
        driverId: widget.driverId!,
        size: 120, // Increased size for better visibility
        borderWidth: 5,
        borderColor: Colors.white,
      );

      if (markerImage == null) {
        debugPrint('❌ Failed to create marker image from profile picture');
        return false;
      }

      debugPrint('📍 Creating PointAnnotation with profile picture (${markerImage.length} bytes)');

      // Delete old driver marker if exists
      if (_driverMarker != null) {
        await _pointAnnotationManager!.delete(_driverMarker!);
        _driverMarker = null;
      }

      // Create point annotation with profile picture
      _driverMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          image: markerImage,
          iconSize: 1.0, // Keep at 1.0 for consistent zoom-independent size
          iconAnchor: IconAnchor.CENTER, // Center anchor for circular marker
        ),
      );

      debugPrint('✅ Profile picture marker created at (${_driverLocation!.lat}, ${_driverLocation!.lng})');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating profile picture marker: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Create simple circle marker as fallback (when no profile picture)
  Future<void> _createMapboxDefaultMarker() async {
    try {
      if (_pointAnnotationManager == null || _driverLocation == null) return;

      debugPrint('🚗 Creating driver marker without profile picture...');

      // Generate custom driver icon with car symbol
      final driverIcon = await MapMarkerService.createDriverMarker(size: 80);

      // Create point annotation with custom icon
      _driverMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          image: driverIcon,
          iconSize: 1.0, // Keep at 1.0 for consistent size
          iconAnchor: IconAnchor.CENTER, // Center anchor for circular marker
        ),
      );

      debugPrint('✅ Driver marker created at (${_driverLocation!.lat}, ${_driverLocation!.lng})');
    } catch (e) {
      debugPrint('❌ Error creating driver marker: $e');
    }
  }

  /// Deprecated: Old circle-based marker method
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

  void _updateMapCamera(double lat, double lng, {double? zoom}) async {
    if (_mapboxMap == null) return;
    
    // Don't adjust camera if user has interacted recently
    if (_hasUserInteractedWithCamera && _lastCameraInteraction != null) {
      final timeSinceInteraction = DateTime.now().difference(_lastCameraInteraction!);
      if (timeSinceInteraction.inSeconds < 10) {
        debugPrint('⏱️ Skipping camera update - user interacted ${timeSinceInteraction.inSeconds}s ago');
        return;
      }
    }
    
    debugPrint('📍 Zooming to location: $lat, $lng (zoom: ${zoom ?? 16.0})');
    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom ?? 16.0,  // Use 16.0 for better zoom on single locations
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
        ],
      ),
    );
  }

  // 🧹 CENTRALIZED CLEARING METHODS
  
  /// Clear all pickup and delivery markers
  Future<void> clearPickupDeliveryMarkers() async {
    debugPrint('🧹 Clearing pickup and delivery markers...');
    
    // Clear pickup marker
    if (_pickupMarker != null && _pointAnnotationManager != null) {
      try {
        await _pointAnnotationManager!.delete(_pickupMarker!);
        _pickupMarker = null;
        debugPrint('  ✅ Pickup marker cleared');
      } catch (e) {
        debugPrint('  ⚠️ Error clearing pickup marker: $e');
      }
    }
    
    // Clear pickup circles
    for (final circle in _pickupMarkerCircles) {
      try {
        await _circleAnnotationManager?.delete(circle);
      } catch (e) {}
    }
    _pickupMarkerCircles.clear();
    _pickupMarkerExists = false;
    
    // Clear delivery marker
    if (_deliveryMarker != null && _pointAnnotationManager != null) {
      try {
        await _pointAnnotationManager!.delete(_deliveryMarker!);
        _deliveryMarker = null;
        debugPrint('  ✅ Delivery marker cleared');
      } catch (e) {
        debugPrint('  ⚠️ Error clearing delivery marker: $e');
      }
    }
    
    // Clear delivery circles
    for (final circle in _dropoffMarkerCircles) {
      try {
        await _circleAnnotationManager?.delete(circle);
      } catch (e) {}
    }
    _dropoffMarkerCircles.clear();
    _deliveryMarkerExists = false;
    
    debugPrint('🧹 Pickup and delivery markers cleared');
  }
  
  /// Clear all multi-stop markers and labels
  Future<void> clearMultiStopMarkers() async {
    debugPrint('🧹 Clearing multi-stop markers...');
    
    // Clear circle markers
    for (final markerList in _multiStopMarkerCircles) {
      for (final marker in markerList) {
        try {
          await _circleAnnotationManager?.delete(marker);
        } catch (e) {}
      }
    }
    _multiStopMarkerCircles.clear();
    
    // Clear stop number annotations (text labels)
    if (_stopNumberAnnotationManager != null) {
      try {
        await _stopNumberAnnotationManager!.deleteAll();
        debugPrint('  ✅ All stop number labels cleared');
      } catch (e) {
        debugPrint('  ⚠️ Error clearing stop numbers: $e');
      }
    }
    
    debugPrint('🧹 Multi-stop markers cleared');
  }
  
  /// Clear all polylines
  Future<void> clearAllPolylines() async {
    debugPrint('🧹 Clearing all polylines...');
    
    // Clear PolylineAnnotations (old method)
    if (_polylineAnnotationManager != null) {
      try {
        await _polylineAnnotationManager!.deleteAll();
        debugPrint('  ✅ All polyline annotations cleared');
      } catch (e) {
        debugPrint('  ⚠️ Error clearing polyline annotations: $e');
      }
    }
    
    // Clear GeoJSON-based traffic route (new method)
    if (_mapboxMap != null) {
      try {
        await _mapboxMap!.style.removeStyleLayer('traffic-route-layer');
        debugPrint('  ✅ Removed traffic route layer');
      } catch (e) {
        debugPrint('  ℹ️ No traffic layer to remove');
      }
      
      try {
        await _mapboxMap!.style.removeStyleSource('traffic-route-source');
        debugPrint('  ✅ Removed traffic route source');
      } catch (e) {
        debugPrint('  ℹ️ No traffic source to remove');
      }
    }
    
    _polylineExists = false;
    debugPrint('🧹 Polylines cleared');
  }
  
  /// Clear all markers (pickup, delivery, multi-stop, driver)
  Future<void> clearAllMarkers() async {
    debugPrint('🧹 Clearing ALL markers...');
    
    await clearPickupDeliveryMarkers();
    await clearMultiStopMarkers();
    
    // Clear driver marker
    if (_driverMarker != null && _pointAnnotationManager != null) {
      try {
        await _pointAnnotationManager!.delete(_driverMarker!);
        _driverMarker = null;
        debugPrint('  ✅ Driver marker cleared');
      } catch (e) {
        debugPrint('  ⚠️ Error clearing driver marker: $e');
      }
    }
    
    // Clear driver circles
    for (final circle in _driverMarkerCircles) {
      try {
        await _circleAnnotationManager?.delete(circle);
      } catch (e) {}
    }
    _driverMarkerCircles.clear();
    _driverMarkerExists = false;
    
    debugPrint('🧹 All markers cleared');
  }
  
  /// Switch from single-stop to multi-stop mode (or vice versa)
  Future<void> switchDeliveryMode({required bool isMultiStop}) async {
    debugPrint('🔄 Switching delivery mode: ${isMultiStop ? 'MULTI-STOP' : 'SINGLE-STOP'}');
    
    // Clear everything first
    await clearAllPolylines();
    
    if (isMultiStop) {
      // Switching TO multi-stop: clear single delivery marker
      if (_deliveryMarker != null && _pointAnnotationManager != null) {
        try {
          await _pointAnnotationManager!.delete(_deliveryMarker!);
          _deliveryMarker = null;
        } catch (e) {}
      }
      for (final circle in _dropoffMarkerCircles) {
        try {
          await _circleAnnotationManager?.delete(circle);
        } catch (e) {}
      }
      _dropoffMarkerCircles.clear();
      _deliveryMarkerExists = false;
    } else {
      // Switching TO single-stop: clear multi-stop markers
      await clearMultiStopMarkers();
    }
    
    debugPrint('🔄 Delivery mode switched');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _driverAnimationController.dispose();
    _lineTrimController.dispose(); // 🎬 Dispose line trim animation controller
    _locationSubscription?.cancel();
    _pulseTimer?.cancel();
    _locationUpdateDebouncer?.cancel(); // 🔧 Cancel debouncer
    
    super.dispose();
  }



  // Start user location tracking
  // Start user location tracking (kept for permission handling and initial focus)
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

      // 🎯 Native location puck automatically tracks user location
      // We just need to get initial position for auto-focus
      final position = await geo.Geolocator.getCurrentPosition();
      _userLocation = position;
      
      print('✅ User location obtained: ${position.latitude}, ${position.longitude}');
      print('🎯 Native location puck will automatically track user movement');
      
    } catch (e) {
      print('Error starting location tracking: $e');
    }
  }

  // Update user location marker
  void _updateUserLocation(geo.Position position) {
    // Don't use setState here to avoid triggering a full rebuild
    // which would clear polylines/markers
    _userLocation = position;

    // 🎯 Native location puck handles user location display automatically
    // No need to manually update markers anymore!
    // The Mapbox location component tracks GPS and updates the puck automatically
    
    // if (_mapboxMap != null && _circleAnnotationManager != null) {
    //   _updateUserLocationMarker(position);
    // }
  }



  // Update user location marker on map (DoorDash-style, no pulsing)
  Future<void> _updateUserLocationMarker(geo.Position position) async {
    try {
      // 🧹 CLEANUP: Remove ALL existing user location markers (prevents duplicates)
      if (_userLocationMarkerCircles.isNotEmpty) {
        final circlesToDelete = List.from(_userLocationMarkerCircles);
        _userLocationMarkerCircles.clear(); // Clear list first to prevent issues
        
        int deletedCount = 0;
        for (final circle in circlesToDelete) {
          try {
            await _circleAnnotationManager?.delete(circle);
            deletedCount++;
          } catch (e) {
            // Silently ignore - circle may not be on map yet
            debugPrint('⚠️ Could not delete circle (may not be added yet): ${circle.id}');
          }
        }
        debugPrint('🧹 Cleared $deletedCount old user location markers');
      }
      
      // Legacy cleanup (backwards compatibility)
      if (_userLocationMarker != null) {
        try {
          await _circleAnnotationManager?.delete(_userLocationMarker!);
        } catch (e) {
          debugPrint('⚠️ Could not delete legacy marker (may not be added yet)');
        }
        _userLocationMarker = null;
      }
      if (_userLocationAccuracyCircle != null) {
        try {
          await _circleAnnotationManager?.delete(_userLocationAccuracyCircle!);
        } catch (e) {
          debugPrint('⚠️ Could not delete legacy accuracy circle (may not be added yet)');
        }
        _userLocationAccuracyCircle = null;
      }

      // Create DoorDash-style user location marker
      await _createDoorDashUserLocationMarker(position);
    } catch (e) {
      print('Error updating user location marker: $e');
    }
  }

  // Create optimized user location marker (reduced from 10 to 4 circles for performance)
  Future<void> _createDoorDashUserLocationMarker(geo.Position position) async {
    if (_circleAnnotationManager == null) return;

    try {
      // DoorDash user location colors
      const userBlue = Color(0xFF007AFF); // iOS blue for user
      
      final circles = <CircleAnnotationOptions>[];
      
      // 1. Create accuracy circle (subtle, clean) - only if accuracy is good
      if (position.accuracy < 100) {
        circles.add(
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(position.longitude, position.latitude)),
            circleRadius: math.min(position.accuracy, 50.0), // Cap accuracy circle size
            circleColor: userBlue.withOpacity(0.08).value,
            circleStrokeColor: userBlue.withOpacity(0.15).value,
            circleStrokeWidth: 1.0,
          ),
        );
      }

      // 2. Create outer white ring
      circles.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: 11.0,
          circleColor: Colors.white.value,
        ),
      );

      // 3. Create main user location circle
      circles.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: 8.0,
          circleColor: userBlue.value,
        ),
      );

      // 4. Create inner white dot (classic design)
      circles.add(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(position.longitude, position.latitude)),
          circleRadius: 3.0,
          circleColor: Colors.white.value,
        ),
      );
      
      // Create all circles in a batch for better performance
      final createdCircles = await _circleAnnotationManager!.createMulti(circles);
      _userLocationMarkerCircles.addAll(createdCircles.whereType<CircleAnnotation>());
      
      // Legacy references
      final validCircles = createdCircles.whereType<CircleAnnotation>().toList();
      if (validCircles.length >= 2) {
        _userLocationMarker = validCircles[validCircles.length - 2]; // Main blue circle
      }
      if (position.accuracy < 100 && validCircles.isNotEmpty) {
        _userLocationAccuracyCircle = validCircles[0]; // Accuracy circle
      }
      
      debugPrint('✅ Optimized user location marker created (${_userLocationMarkerCircles.length} circles)');
    } catch (e) {
      print('❌ Error creating user location marker: $e');
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
      // 🔧 FIX: Changed || to && - we need BOTH lat AND lng to create a marker
      if (widget.deliveryStatus != null && widget.driverLatitude != null && widget.driverLongitude != null) {
        debugPrint('🚗 Delivery tracking mode detected, updating driver marker');
        await _updateDriverMarker();
      } else {
        debugPrint('🚗 Location selection mode or missing coordinates - skipping driver marker update');
        if (widget.deliveryStatus != null) {
          debugPrint('   - driverLatitude: ${widget.driverLatitude}');
          debugPrint('   - driverLongitude: ${widget.driverLongitude}');
        }
      }
      
      // Update route between markers
      if (_pickupLocation != null && _deliveryLocation != null) {
        await _drawRoute();
      }
    } catch (e) {
      print('Error updating map markers: $e');
    }
  }
  
  // 🔧 PERFORMANCE: Individual marker update methods (prevent unnecessary recreation)
  
  Future<void> _updatePickupMarkerOnly() async {
    if (_pointAnnotationManager == null || _pickupLocation == null) return;
    debugPrint('🟢 Updating ONLY pickup marker');
    await _updatePickupMarker();
  }
  
  Future<void> _updateDropoffMarkerOnly() async {
    if (_pointAnnotationManager == null || _deliveryLocation == null) return;
    debugPrint('🔴 Updating ONLY delivery marker');
    await _updateDropoffMarker();
  }
  
  Future<void> _updateDriverMarkerOnly() async {
    if (_pointAnnotationManager == null || _driverLocation == null) return;
    if (widget.deliveryStatus == null) return;
    debugPrint('🚗 Updating ONLY driver marker');
    await _updateDriverMarker();
  }
  
  Future<void> _updateMultiStopMarkers() async {
    if (_pointAnnotationManager == null) return;
    debugPrint('🚏 Updating multi-stop markers');
    
    // Clear existing multi-stop markers AND polylines
    await clearMultiStopMarkers();
    await clearAllPolylines();
    
    // Redraw multi-stop route
    if (widget.isMultiStop && widget.additionalStops != null && widget.additionalStops!.isNotEmpty) {
      await _drawMultiStopRoute();
    }
  }

  // Update pickup marker
  Future<void> _updatePickupMarker() async {
    if (_pickupLocation == null) return;

    try {
      // Delete old pickup point annotation marker
      if (_pickupMarker != null && _pointAnnotationManager != null) {
        try {
          await _pointAnnotationManager!.delete(_pickupMarker!);
          _pickupMarker = null;
        } catch (e) {
          print('Error deleting old pickup marker: $e');
        }
      }
      
      // Remove existing pickup marker circles (legacy cleanup)
      for (final circle in _pickupMarkerCircles) {
        try {
          await _circleAnnotationManager!.delete(circle);
        } catch (e) {
          // Circle might already be deleted
        }
      }
      _pickupMarkerCircles.clear();

      // Create new pickup marker
      await _createPickupCircleMarker();
      print('Pickup marker created at: ${_pickupLocation!.lat}, ${_pickupLocation!.lng}');
    } catch (e) {
      print('Error updating pickup marker: $e');
    }
  }

  // Create pickup marker with pin icon 🟢 ZOOM-INDEPENDENT
  Future<void> _createPickupCircleMarker() async {
    if (_pointAnnotationManager == null || _pickupLocation == null) return;

    try {
      debugPrint('🟢 Creating pickup pin marker...');
      
      // Generate custom pickup pin icon (larger size)
      final pickupIcon = await MapMarkerService.createPickupMarker(size: 120);
      
      // Create point annotation with custom icon and track it
      _pickupMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          image: pickupIcon,
          iconSize: 1.2, // Larger icon size
          iconAnchor: IconAnchor.BOTTOM, // Anchor at bottom point of pin
        ),
      );
      
      debugPrint('✅ Pickup pin marker created at (${_pickupLocation!.lat}, ${_pickupLocation!.lng})');
    } catch (e) {
      print('❌ Error creating pickup pin marker: $e');
    }
  }

  // Update drop-off marker
  Future<void> _updateDropoffMarker() async {
    if (_deliveryLocation == null) return;

    try {
      // Delete old delivery point annotation marker
      if (_deliveryMarker != null && _pointAnnotationManager != null) {
        try {
          await _pointAnnotationManager!.delete(_deliveryMarker!);
          _deliveryMarker = null;
        } catch (e) {
          print('Error deleting old delivery marker: $e');
        }
      }
      
      // Remove existing dropoff marker circles (legacy cleanup)
      for (final circle in _dropoffMarkerCircles) {
        try {
          await _circleAnnotationManager!.delete(circle);
        } catch (e) {
          // Circle might already be deleted
        }
      }
      _dropoffMarkerCircles.clear();

      // Create new delivery marker
      await _createDropoffCircleMarker();
      print('Dropoff marker created at: ${_deliveryLocation!.lat}, ${_deliveryLocation!.lng}');
    } catch (e) {
      print('Error updating dropoff marker: $e');
    }
  }

  // Create delivery marker with pin icon 🔴 ZOOM-INDEPENDENT
  Future<void> _createDropoffCircleMarker() async {
    if (_pointAnnotationManager == null || _deliveryLocation == null) return;

    try {
      debugPrint('🔴 Creating delivery pin marker...');
      
      // Generate custom delivery pin icon (larger size)
      final deliveryIcon = await MapMarkerService.createDeliveryMarker(size: 120);
      
      // Create point annotation with custom icon and track it
      _deliveryMarker = await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          image: deliveryIcon,
          iconSize: 1.2, // Larger icon size
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
      
      debugPrint('✅ Delivery pin marker created at (${_deliveryLocation!.lat}, ${_deliveryLocation!.lng})');
    } catch (e) {
      print('❌ Error creating delivery pin marker: $e');
    }
  }

  // 🚏 Create numbered marker for multi-stop delivery - ENHANCED VISIBILITY + DARK MODE FIX
  Future<List<CircleAnnotation>> _createNumberedStopMarker(int stopNumber, Position position) async {
    if (_circleAnnotationManager == null || _stopNumberAnnotationManager == null) return [];
    
    List<CircleAnnotation> circles = [];
    
    try {
      const stopBlue = Color(0xFF0080FF); // Blue for stops
      const pureWhite = Color(0xFFFFFFFF); // ⚪ PURE WHITE (fixes dark mode)
      
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
          circleStrokeColor: pureWhite.value,                    // ⚪ PURE WHITE BORDER
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
          circleColor: pureWhite.value,                          // ⚪ PURE WHITE
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

      // Add text number using PointAnnotation with textField - ENHANCED + DARK MODE FIX
      try {
        await _stopNumberAnnotationManager!.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: position),
            textField: stopNumber.toString(),
            textSize: 16.0,                                      // Larger text
            textColor: pureWhite.value,                          // ⚪ PURE WHITE TEXT (fixes dark mode)
            textHaloColor: stopBlue.value,                       // Blue halo
            textHaloWidth: 3.0,                                  // Thicker halo
            textHaloBlur: 0.5,
            textOffset: [0.0, 0.0],
            iconSize: 0.0, // No icon, just text
          ),
        );
        debugPrint('🚏 Numbered marker created for stop $stopNumber with white text');
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
  // ⚠️ IMPORTANT: This method RECREATES the marker - only call for initial creation!
  // For position updates during animation, the marker geometry is updated directly in the animation listener.
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
      
      // Remove existing driver marker (only if recreating)
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