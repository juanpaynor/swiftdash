import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/mapbox_service.dart';

class SharedDeliveryMap extends StatefulWidget {
  final Function(String address, double lat, double lng, bool isPickup)? onLocationSelected;
  final String? initialPickupAddress;
  final String? initialDeliveryAddress;
  
  // Real-time coordinate updates (Uber-style)
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  const SharedDeliveryMap({
    super.key,
    this.onLocationSelected,
    this.initialPickupAddress,
    this.initialDeliveryAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
  });

  @override
  State<SharedDeliveryMap> createState() => _SharedDeliveryMapState();
}

class _SharedDeliveryMapState extends State<SharedDeliveryMap> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  
  // Location states
  Position? _pickupLocation;
  Position? _deliveryLocation;
  
  @override
  void initState() {
    super.initState();
    // Initialize locations from widget coordinates if provided
    _updateLocationsFromWidget();
  }

  @override
  void didUpdateWidget(SharedDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update map when coordinates change (Uber-style responsiveness)
    if (widget.pickupLatitude != oldWidget.pickupLatitude ||
        widget.pickupLongitude != oldWidget.pickupLongitude ||
        widget.deliveryLatitude != oldWidget.deliveryLatitude ||
        widget.deliveryLongitude != oldWidget.deliveryLongitude) {
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
      print('Annotation managers created');
      
      // Enable map interactions
      await _mapboxMap!.gestures.updateSettings(GesturesSettings(
        rotateEnabled: true,
        pitchEnabled: true,
        scrollEnabled: true,
        simultaneousRotateAndPinchToZoomEnabled: true,
        pinchToZoomEnabled: true,
      ));
      print('Map gestures enabled');
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
      // Show loading feedback immediately
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
              const Text('Getting address...'),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue,
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPickup ? '📍 Pickup location set' : '🏁 Delivery location set',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  fontSize: 12, 
                  color: Colors.white.withOpacity(0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: isPickup ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
    } catch (e) {
      print('Error setting location from tap: $e');
      
      // Show error feedback
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to set location. Please try again.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
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
          title: const Text('Update Location'),
          content: const Text('Which location would you like to update?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _setLocationFromTap(lat, lng, true);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Pickup'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _setLocationFromTap(lat, lng, false);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Delivery'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateMapMarkers() async {
    if (_pointAnnotationManager == null) return;
    
    try {
      // Clear existing annotations
      await _pointAnnotationManager!.deleteAll();
      if (_polylineAnnotationManager != null) {
        await _polylineAnnotationManager!.deleteAll();
      }
      
      // Add pickup marker (green) - Larger pins
      if (_pickupLocation != null) {
        final pickupAnnotation = PointAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          iconColor: Colors.green.value,
          iconSize: 3.0, // Increased from 2.0
          textField: "📍", // Pickup emoji
          textSize: 32.0, // Increased from 20.0
        );
        await _pointAnnotationManager!.create(pickupAnnotation);
      }
      
      // Add delivery marker (red) - Larger pins
      if (_deliveryLocation != null) {
        final deliveryAnnotation = PointAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          iconColor: Colors.red.value,
          iconSize: 3.0, // Increased from 2.0
          textField: "🏁", // Delivery flag emoji
          textSize: 32.0, // Increased from 20.0
        );
        await _pointAnnotationManager!.create(deliveryAnnotation);
      }
      
      // Draw route polyline if both locations exist
      if (_pickupLocation != null && _deliveryLocation != null && _polylineAnnotationManager != null) {
        await _drawRoute();
      }
      
      // Fit map to show both locations
      if (_pickupLocation != null && _deliveryLocation != null) {
        await _fitMapToBothLocations();
      }
    } catch (e) {
      print('Update markers error: $e');
    }
  }

  Future<void> _drawRoute() async {
    if (_pickupLocation == null || _deliveryLocation == null || _polylineAnnotationManager == null) return;
    
    try {
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
          lineColor: Colors.blue.value,
          lineWidth: 4.0,
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

  void _updateMapCamera(double lat, double lng) async {
    if (_mapboxMap == null) return;
    
    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 15.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Map interaction instructions
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap on the map to set locations and auto-fill address fields. Pinch to zoom, drag to pan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Interactive Map - EXPANDED TO FILL AVAILABLE SPACE
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MapWidget(
                key: const ValueKey("shared_delivery_map"),
                onMapCreated: _onMapCreated,
                onTapListener: _onMapTapped,
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(
                    MapboxService.metroManilaLng, 
                    MapboxService.metroManilaLat
                  )),
                  zoom: 12.0,
                ),
              ),
            ),
          ),
        ),
        
        // Location status indicators
        if (_pickupLocation != null || _deliveryLocation != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                if (_pickupLocation != null) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Pickup', style: TextStyle(fontSize: 12)),
                ],
                if (_pickupLocation != null && _deliveryLocation != null)
                  const SizedBox(width: 16),
                if (_deliveryLocation != null) ...[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Delivery', style: TextStyle(fontSize: 12)),
                ],
                const Spacer(),
                if (_pickupLocation != null && _deliveryLocation != null)
                  const Text(
                    'Both locations set',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}