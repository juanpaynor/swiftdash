import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../services/mapbox_service.dart';
import '../constants/app_theme.dart';

class SharedDeliveryMap extends StatefulWidget {
  final Function(String address, double lat, double lng, bool isPickup)? onLocationSelected;
  final String? initialPickupAddress;
  final String? initialDeliveryAddress;

  const SharedDeliveryMap({
    super.key,
    this.onLocationSelected,
    this.initialPickupAddress,
    this.initialDeliveryAddress,
  });

  @override
  State<SharedDeliveryMap> createState() => _SharedDeliveryMapState();
}

class _SharedDeliveryMapState extends State<SharedDeliveryMap> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  
  // Location states
  Position? _pickupLocation;
  Position? _deliveryLocation;
  
  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    // Create point annotation manager for markers
    _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
  }

  Future<void> _updateMapMarkers() async {
    if (_pointAnnotationManager == null) return;
    
    try {
      // Clear existing annotations
      await _pointAnnotationManager!.deleteAll();
      
      // Add pickup marker
      if (_pickupLocation != null) {
        final pickupAnnotation = PointAnnotationOptions(
          geometry: Point(coordinates: _pickupLocation!),
          iconImage: "default_marker",
        );
        await _pointAnnotationManager!.create(pickupAnnotation);
      }
      
      // Add delivery marker
      if (_deliveryLocation != null) {
        final deliveryAnnotation = PointAnnotationOptions(
          geometry: Point(coordinates: _deliveryLocation!),
          iconImage: "default_marker",
        );
        await _pointAnnotationManager!.create(deliveryAnnotation);
      }
      
      // Fit map to show both locations
      if (_pickupLocation != null && _deliveryLocation != null) {
        await _fitMapToBothLocations();
      }
    } catch (e) {
      print('Update markers error: $e');
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
    // Make map responsive to screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.4; // 40% of screen height
    final minHeight = 250.0; // Minimum height for usability
    final maxHeight = 450.0; // Maximum height to leave space for other content
    
    final responsiveHeight = mapHeight.clamp(minHeight, maxHeight);
    
    return Container(
      height: responsiveHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MapWidget(
          key: const ValueKey("shared_delivery_map"),
          onMapCreated: _onMapCreated,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(
              MapboxService.metroManilaLng, 
              MapboxService.metroManilaLat
            )),
            zoom: 12.0,
          ),
        ),
      ),
    );
  }
}