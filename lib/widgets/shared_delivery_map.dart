import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:async';
import '../services/mapbox_service.dart';
import '../constants/app_theme.dart';

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
    // Update map when coordinates change (Uber-style responsiveness)
    if (widget.pickupLatitude != oldWidget.pickupLatitude ||
        widget.pickupLongitude != oldWidget.pickupLongitude ||
        widget.deliveryLatitude != oldWidget.deliveryLatitude ||
        widget.deliveryLongitude != oldWidget.deliveryLongitude ||
        widget.driverLatitude != oldWidget.driverLatitude ||
        widget.driverLongitude != oldWidget.driverLongitude) {
      _updateLocationsFromWidget();
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

  Future<void> _drawRoute() async {
    if (_pickupLocation == null || _deliveryLocation == null || _polylineAnnotationManager == null) return;
    
    try {
      // FIXED: Clear all existing polylines before drawing new route
      await _polylineAnnotationManager!.deleteAll();
      print('Cleared existing polylines');
      
      // Get route from Mapbox Directions API
      final route = await MapboxService.getRoute(
        _pickupLocation!.lat.toDouble(), _pickupLocation!.lng.toDouble(),
        _deliveryLocation!.lat.toDouble(), _deliveryLocation!.lng.toDouble()
      );
      
      if (route != null) {
        // Convert route coordinates to Position objects
        final routePositions = route.map((coord) => Position(coord['lng']!, coord['lat']!)).toList();
        
        // Create blue polyline
        final polylineAnnotation = PolylineAnnotationOptions(
          geometry: LineString(coordinates: routePositions),
          lineColor: AppTheme.primaryBlue.value,
          lineWidth: 5.0,
        );
        await _polylineAnnotationManager!.create(polylineAnnotation);
        print('Route polyline added');
      }
    } catch (e) {
      print('Route drawing error: $e');
    }
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
    
    // Clean up pulse rings
    _cleanupPulseRings();
    
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

  // Enhanced marker update method
  Future<void> _updateEnhancedMapMarkers() async {
    if (_pointAnnotationManager == null) return;

    try {
      // Update pickup marker
      await _updatePickupMarker();
      
      // Update drop-off marker  
      await _updateDropoffMarker();
      
      // Update driver marker (real-time tracking)
      await _updateDriverMarker();
      
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
      // Create outer ring for visibility (larger and more prominent)
      final outerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 20.0,
          circleColor: Colors.green.withOpacity(0.2).value,
          circleStrokeColor: Colors.green.value,
          circleStrokeWidth: 3.0,
        ),
      );

      // Create inner solid circle (brighter and larger)
      final innerCircle = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 10.0,
          circleColor: Colors.green.shade600.value,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 4.0,
        ),
      );

      // Create center dot for precise location (larger for visibility)
      final centerDot = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          circleRadius: 4.0,
          circleColor: Colors.white.value,
          circleStrokeColor: Colors.green.shade800.value,
          circleStrokeWidth: 1.0,
        ),
      );

      // Track all circles for cleanup
      _pickupMarkerCircles.addAll([outerRing, innerCircle, centerDot]);
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
      // Create outer ring for visibility (larger and more prominent)
      final outerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 20.0,
          circleColor: Colors.red.withOpacity(0.2).value,
          circleStrokeColor: Colors.red.value,
          circleStrokeWidth: 3.0,
        ),
      );

      // Create inner solid circle (brighter and larger)
      final innerCircle = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 10.0,
          circleColor: Colors.red.shade600.value,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 4.0,
        ),
      );

      // Create center dot for precise location (larger for visibility)
      final centerDot = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          circleRadius: 4.0,
          circleColor: Colors.white.value,
          circleStrokeColor: Colors.red.shade800.value,
          circleStrokeWidth: 1.0,
        ),
      );

      // Track all circles for cleanup
      _dropoffMarkerCircles.addAll([outerRing, innerCircle, centerDot]);
    } catch (e) {
      print('Error creating dropoff circle marker: $e');
    }
  }

  // Update driver marker (real-time tracking)
  Future<void> _updateDriverMarker() async {
    if (_driverLocation == null) return;

    try {
      // Remove existing driver marker circles
      for (final circle in _driverMarkerCircles) {
        try {
          await _circleAnnotationManager!.delete(circle);
        } catch (e) {
          // Circle might already be deleted
        }
      }
      _driverMarkerCircles.clear();

      // Create driver marker
      await _createDriverCircleMarker();
      print('Driver marker updated at: ${_driverLocation!.lat}, ${_driverLocation!.lng}');
    } catch (e) {
      print('Error updating driver marker: $e');
    }
  }

  // Create reliable driver marker using circles (different color for driver)
  Future<void> _createDriverCircleMarker() async {
    if (_circleAnnotationManager == null || _driverLocation == null) return;

    try {
      // Create outer ring for visibility (blue for driver)
      final outerRing = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 12.0,
          circleColor: Colors.blue.shade600.withOpacity(0.3).value,
          circleStrokeColor: Colors.blue.shade800.value,
          circleStrokeWidth: 2.0,
        ),
      );

      // Create inner circle for contrast
      final innerCircle = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 8.0,
          circleColor: Colors.blue.shade500.value,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 2.0,
        ),
      );

      // Create center dot for precise location
      final centerDot = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _driverLocation!),
          circleRadius: 4.0,
          circleColor: Colors.white.value,
          circleStrokeColor: Colors.blue.shade800.value,
          circleStrokeWidth: 1.0,
        ),
      );

      // Track all circles for cleanup
      _driverMarkerCircles.addAll([outerRing, innerCircle, centerDot]);
    } catch (e) {
      print('Error creating driver circle marker: $e');
    }
  }


}