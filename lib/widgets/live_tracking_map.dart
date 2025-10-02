import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/delivery.dart';
import '../services/directions_service.dart';

class LiveTrackingMap extends StatefulWidget {
  final Delivery delivery;
  final Map<String, dynamic>? driverLocation;
  final Function(MapboxMap)? onMapCreated;

  const LiveTrackingMap({
    Key? key,
    required this.delivery,
    this.driverLocation,
    this.onMapCreated,
  }) : super(key: key);

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  
  // Map annotations
  PointAnnotation? _driverAnnotation;
  PolylineAnnotation? _routePolyline;
  
  // ETA tracking
  String? _driverETA;
  String? _deliveryETA;
  Timer? _etaUpdateTimer;

  @override
  void initState() {
    super.initState();
    _startETAUpdates();
  }

  @override
  void dispose() {
    _etaUpdateTimer?.cancel();
    super.dispose();
  }

  void _startETAUpdates() {
    // Update ETAs every 30 seconds
    _etaUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (widget.driverLocation != null) {
        _calculateETAs();
      }
    });
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    // Create annotation managers
    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    
    // Set up initial map view
    await _setupInitialView();
    
    // Add delivery location pins
    await _addDeliveryPins();
    
    // Add driver location if available
    if (widget.driverLocation != null) {
      await _updateDriverLocation();
    }
    
    // Draw route based on delivery status
    await _updateRouteVisualization();
    
    widget.onMapCreated?.call(mapboxMap);
  }

  Future<void> _setupInitialView() async {
    if (_mapboxMap == null) return;

    // Calculate bounds to show all relevant points
    double minLat = widget.delivery.pickupLatitude;
    double maxLat = widget.delivery.deliveryLatitude;
    double minLng = widget.delivery.pickupLongitude;
    double maxLng = widget.delivery.deliveryLongitude;

    if (widget.driverLocation != null) {
      final driverLat = widget.driverLocation!['current_latitude'] as double;
      final driverLng = widget.driverLocation!['current_longitude'] as double;
      minLat = [minLat, driverLat, maxLat].reduce((a, b) => a < b ? a : b);
      maxLat = [minLat, driverLat, maxLat].reduce((a, b) => a > b ? a : b);
      minLng = [minLng, driverLng, maxLng].reduce((a, b) => a < b ? a : b);
      maxLng = [minLng, driverLng, maxLng].reduce((a, b) => a > b ? a : b);
    }

    // Calculate center point and appropriate zoom level
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    
    // Calculate zoom level based on the distance between points
    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();
    final maxDiff = math.max(latDiff, lngDiff);
    
    double zoom = 12.0;
    if (maxDiff < 0.01) zoom = 16.0;
    else if (maxDiff < 0.05) zoom = 14.0;
    else if (maxDiff < 0.1) zoom = 13.0;
    else if (maxDiff < 0.5) zoom = 11.0;
    else zoom = 10.0;

    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
      ),
    );
  }

  Future<void> _addDeliveryPins() async {
    if (_pointAnnotationManager == null) return;

    // Pickup pin (green)
    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.delivery.pickupLongitude, widget.delivery.pickupLatitude),
        ),
        textField: "📍",
        textSize: 24.0,
        textOffset: [0.0, -1.0],
      ),
    );

    // Delivery pin (red)  
    await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.delivery.deliveryLongitude, widget.delivery.deliveryLatitude),
        ),
        textField: "🏁",
        textSize: 24.0,
        textOffset: [0.0, -1.0],
      ),
    );
  }

  Future<void> _updateDriverLocation() async {
    if (_pointAnnotationManager == null || widget.driverLocation == null) return;

    final driverLat = widget.driverLocation!['current_latitude'] as double;
    final driverLng = widget.driverLocation!['current_longitude'] as double;

    // Remove existing driver annotation
    if (_driverAnnotation != null) {
      await _pointAnnotationManager!.delete(_driverAnnotation!);
    }

    // Create new driver annotation (car icon)
    _driverAnnotation = await _pointAnnotationManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(driverLng, driverLat)),
        textField: "🚗",
        textSize: 20.0,
        textOffset: [0.0, -1.0],
      ),
    );

    // Smooth camera follow (only if driver is moving significantly)
    await _followDriverSmoothly(driverLat, driverLng);
    
    // Update ETAs
    await _calculateETAs();
  }

  Future<void> _followDriverSmoothly(double lat, double lng) async {
    if (_mapboxMap == null) return;

    // Always follow driver location for live tracking experience
    // Use smooth animation to driver location
    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: 16.0,
      ),
    );
  }

  Future<void> _updateRouteVisualization() async {
    if (_polylineAnnotationManager == null) return;

    // Remove existing route
    if (_routePolyline != null) {
      await _polylineAnnotationManager!.delete(_routePolyline!);
    }

    List<Position> routePoints = [];
    
    try {
      switch (widget.delivery.status) {
        case 'driver_assigned':
          // Show driver → pickup route
          if (widget.driverLocation != null) {
            final route = await DirectionsService.getRoute(
              startLat: widget.driverLocation!['current_latitude'],
              startLng: widget.driverLocation!['current_longitude'],
              endLat: widget.delivery.pickupLatitude,
              endLng: widget.delivery.pickupLongitude,
            );
            routePoints = route.map((point) => Position(point.lng, point.lat)).toList();
          }
          break;

        case 'pickup_arrived':
          // Highlight pickup location (no route needed)
          break;

        case 'package_collected':
        case 'in_transit':
          // Show pickup → delivery route
          final route = await DirectionsService.getRoute(
            startLat: widget.delivery.pickupLatitude,
            startLng: widget.delivery.pickupLongitude,
            endLat: widget.delivery.deliveryLatitude,
            endLng: widget.delivery.deliveryLongitude,
          );
          routePoints = route.map((point) => Position(point.lng, point.lat)).toList();
          break;

        default:
          // No route for other statuses
          break;
      }

      // Draw route if we have points
      if (routePoints.isNotEmpty) {
        _routePolyline = await _polylineAnnotationManager!.create(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: routePoints),
            lineColor: Colors.blue.value,
            lineWidth: 4.0,
          ),
        );
      }
    } catch (e) {
      print('Route visualization error: $e');
    }
  }

  Future<void> _calculateETAs() async {
    if (widget.driverLocation == null) return;

    try {
      final driverLat = widget.driverLocation!['current_latitude'] as double;
      final driverLng = widget.driverLocation!['current_longitude'] as double;

      String? pickupETA;
      String? deliveryETA;

      switch (widget.delivery.status) {
        case 'driver_assigned':
          // Calculate driver → pickup ETA
          final pickupDuration = await DirectionsService.getDuration(
            startLat: driverLat,
            startLng: driverLng,
            endLat: widget.delivery.pickupLatitude,
            endLng: widget.delivery.pickupLongitude,
          );
          pickupETA = _formatDuration(pickupDuration);
          break;

        case 'package_collected':
        case 'in_transit':
          // Calculate pickup → delivery ETA (from current driver position)
          final deliveryDuration = await DirectionsService.getDuration(
            startLat: driverLat,
            startLng: driverLng,
            endLat: widget.delivery.deliveryLatitude,
            endLng: widget.delivery.deliveryLongitude,
          );
          deliveryETA = _formatDuration(deliveryDuration);
          break;
      }

      if (mounted) {
        setState(() {
          _driverETA = pickupETA;
          _deliveryETA = deliveryETA;
        });
      }
    } catch (e) {
      print('ETA calculation error: $e');
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '< 1 min';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = (minutes / 60).floor();
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  Future<void> _centerOnDriver() async {
    if (_mapboxMap == null || widget.driverLocation == null) return;

    final driverLat = widget.driverLocation!['current_latitude'] as double;
    final driverLng = widget.driverLocation!['current_longitude'] as double;

    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(driverLng, driverLat)),
        zoom: 16.0,
      ),
    );
  }

  Future<void> _showFullRoute() async {
    await _setupInitialView();
  }

  Widget _buildETAInfo() {
    if (_driverETA == null && _deliveryETA == null) return Container();

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_driverETA != null) ...[
              Text(
                'Driver arriving in',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                _driverETA!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
            if (_deliveryETA != null) ...[
              const SizedBox(height: 8),
              Text(
                'Delivery in',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                _deliveryETA!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: "center",
            onPressed: _centerOnDriver,
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "overview",
            onPressed: _showFullRoute,
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            child: const Icon(Icons.map),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: ValueKey("tracking_map"),
          onMapCreated: _onMapCreated,
          cameraOptions: CameraOptions(
            center: Point(
              coordinates: Position(
                widget.delivery.pickupLongitude,
                widget.delivery.pickupLatitude,
              ),
            ),
            zoom: 12.0,
          ),
        ),
        _buildETAInfo(),
        _buildMapControls(),
      ],
    );
  }

  // Method to be called from parent when driver location updates
  void updateDriverLocation(Map<String, dynamic> newLocation) {
    if (mounted) {
      setState(() {
        // This will trigger _updateDriverLocation in the next build
      });
      _updateDriverLocation();
      _updateRouteVisualization();
    }
  }
}