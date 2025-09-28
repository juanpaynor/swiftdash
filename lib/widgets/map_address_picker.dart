import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' show asin, cos, pi, pow, sin, sqrt, min, max;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'address_autocomplete.dart';
import '../services/directions_service.dart';

class MapAddressPicker extends StatefulWidget {
  final String label;
  final Function(String address, double latitude, double longitude, double? distance, LatLng? otherLocation) onLocationSelected;
  final String? initialAddress;
  final LatLng? otherLocation; // The other point to draw route to
  final bool isPickup; // Whether this is pickup (true) or delivery (false) point

  const MapAddressPicker({
    super.key,
    required this.label,
    required this.onLocationSelected,
    this.initialAddress,
    this.otherLocation,
    required this.isPickup,
  });

  @override
  State<MapAddressPicker> createState() => _MapAddressPickerState();
}

class _MapAddressPickerState extends State<MapAddressPicker> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;
  String _selectedAddress = '';
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  double? _distance;
  bool _permissionDenied = false;
  bool _usingRealRoutes = true; // Track if we're using real routes or fallback

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialAddress ?? '';
    _getCurrentLocation();
    // Test the API when the widget initializes
    _testDirectionsAPI();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _testDirectionsAPI() async {
    // Test with known good coordinates (Los Angeles to San Francisco)
    final testOrigin = LatLng(34.0522, -118.2437);  // Los Angeles
    final testDestination = LatLng(37.7749, -122.4194); // San Francisco
    
    print('Testing Directions API with LA -> SF route...');
    final result = await DirectionsService.getDirections(
      origin: testOrigin,
      destination: testDestination,
    );
    
    if (result != null && result.polylinePoints.isNotEmpty) {
      print('✅ Directions API test successful: ${result.polylinePoints.length} points, ${result.distanceKm}km');
    } else {
      print('❌ Directions API test failed - no polyline data returned');
    }
  }

  Future<void> _calculateRouteAndDistance() async {
    if (_selectedLocation != null && widget.otherLocation != null) {
      // Check if locations are very close (less than 100 meters apart)
      const double earthRadius = 6371000; // in meters
      final double lat1 = _selectedLocation!.latitude * pi / 180;
      final double lon1 = _selectedLocation!.longitude * pi / 180;
      final double lat2 = widget.otherLocation!.latitude * pi / 180;
      final double lon2 = widget.otherLocation!.longitude * pi / 180;
      
      final double dlon = lon2 - lon1;
      final double dlat = lat2 - lat1;

      final double a = pow(sin(dlat / 2), 2) +
          cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);
      final double c = 2 * asin(sqrt(a));
      final double distanceMeters = earthRadius * c;
      
      print('Distance between points: ${distanceMeters.toInt()} meters');
      
      // If locations are very close (less than 200 meters), skip directions API
      if (distanceMeters < 200) {
        print('Locations too close for directions API, using straight line');
        _calculateStraightLineDistance();
        return;
      }
      
      try {
        // Get real driving directions from Google Directions API
        final directions = await DirectionsService.getDirections(
          origin: _selectedLocation!,
          destination: widget.otherLocation!,
        );

        if (directions != null && directions.polylinePoints.isNotEmpty) {
          // Sanity check: ensure route isn't a straight vertical/horizontal line due to decoding issues
          bool isDegenerate(List<LatLng> pts) {
            if (pts.length < 2) return true;
            double minLat = pts.first.latitude, maxLat = pts.first.latitude;
            double minLng = pts.first.longitude, maxLng = pts.first.longitude;
            for (final p in pts) {
              if (p.latitude < minLat) minLat = p.latitude;
              if (p.latitude > maxLat) maxLat = p.latitude;
              if (p.longitude < minLng) minLng = p.longitude;
              if (p.longitude > maxLng) maxLng = p.longitude;
            }
            return (maxLat - minLat).abs() < 1e-6 || (maxLng - minLng).abs() < 1e-6;
          }

          if (isDegenerate(directions.polylinePoints)) {
            debugPrint('MapAddressPicker: Degenerate polyline received, using straight-line fallback');
            await _calculateStraightLineDistance();
            return;
          }

          print('MapAddressPicker: Got ${directions.polylinePoints.length} polyline points for route');
          print('MapAddressPicker: Distance: ${directions.distanceKm}km, Duration: ${directions.durationMinutes}min');
          setState(() {
            _distance = directions.distanceKm;
            _usingRealRoutes = true;
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                color: const Color(0xFF1976D2),
                points: directions.polylinePoints,
                width: 7,
                patterns: const [],
                endCap: Cap.roundCap,
                startCap: Cap.roundCap,
                jointType: JointType.round,
                geodesic: false,
                zIndex: 1,
                consumeTapEvents: false,
              ),
            );

            // Add markers for both points
            _markers.clear();
            _markers.addAll({
              Marker(
                markerId: const MarkerId('selected_location'),
                position: _selectedLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  widget.isPickup ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(
                  title: widget.isPickup ? 'Pickup Location' : 'Delivery Location',
                ),
              ),
              Marker(
                markerId: const MarkerId('other_location'),
                position: widget.otherLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  !widget.isPickup ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(
                  title: !widget.isPickup ? 'Pickup Location' : 'Delivery Location',
                ),
              ),
            });
          });

          // Update camera to show the route bounds (slight delay to ensure map is ready)
          if (_mapController != null) {
            await Future.delayed(const Duration(milliseconds: 50));
            try {
              await _mapController!.animateCamera(
                CameraUpdate.newLatLngBounds(directions.bounds, 80),
              );
            } catch (_) {
              // Fallback: center on mid-point
              final mid = directions.polylinePoints[(directions.polylinePoints.length / 2).floor()];
              await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(mid, 13));
            }
          }
        } else {
          // Fall back to straight line if directions API fails or returns no polyline
          debugPrint('Directions API returned no polyline data, falling back to straight line');
          _calculateStraightLineDistance();
        }
      } catch (e) {
        // Fall back to straight line calculation
        debugPrint('Directions API error: $e, falling back to straight line');
        _calculateStraightLineDistance();
      }
    } else {
      setState(() {
        _distance = null;
        _polylines.clear();
        _markers.clear();
        if (_selectedLocation != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('selected_location'),
              position: _selectedLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                widget.isPickup ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(
                title: widget.isPickup ? 'Pickup Location' : 'Delivery Location',
              ),
            ),
          );
        }
      });
    }
  }

  // Fallback method for straight-line distance
  Future<void> _calculateStraightLineDistance() async {
    if (_selectedLocation != null && widget.otherLocation != null) {
      // Calculate straight-line distance as fallback
      const double earthRadius = 6371; // in kilometers
      final double lat1 = _selectedLocation!.latitude * pi / 180;
      final double lon1 = _selectedLocation!.longitude * pi / 180;
      final double lat2 = widget.otherLocation!.latitude * pi / 180;
      final double lon2 = widget.otherLocation!.longitude * pi / 180;
      
      final double dlon = lon2 - lon1;
      final double dlat = lat2 - lat1;

      final double a = pow(sin(dlat / 2), 2) +
          cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);
      final double c = 2 * asin(sqrt(a));
      final double distance = earthRadius * c;

      // Draw a straight line between points as fallback
      final List<LatLng> polylineCoordinates = [
        _selectedLocation!,
        widget.otherLocation!,
      ];

      setState(() {
        _distance = distance;
        _usingRealRoutes = false; // Mark as fallback
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: const Color(0xFFFF9800), // Orange for fallback
            points: polylineCoordinates,
            width: 4,
            patterns: [PatternItem.dash(15), PatternItem.gap(8)], // More visible dashed line
            endCap: Cap.roundCap,
            startCap: Cap.roundCap,
            zIndex: 1,
          ),
        );

        // Add markers for both points
        _markers.clear();
        _markers.addAll({
          Marker(
            markerId: const MarkerId('selected_location'),
            position: _selectedLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              widget.isPickup ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
          ),
          Marker(
            markerId: const MarkerId('other_location'),
            position: widget.otherLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              !widget.isPickup ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
            ),
          ),
        });
      });

      // Update camera to show both points
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          min(_selectedLocation!.latitude, widget.otherLocation!.latitude),
          min(_selectedLocation!.longitude, widget.otherLocation!.longitude),
        ),
        northeast: LatLng(
          max(_selectedLocation!.latitude, widget.otherLocation!.latitude),
          max(_selectedLocation!.longitude, widget.otherLocation!.longitude),
        ),
      );

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _permissionDenied = true;
          throw Exception('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _permissionDenied = true;
        throw Exception('Location permission permanently denied');
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
          _permissionDenied = false;
        });
        _updateCameraPosition(_selectedLocation!);
        _getAddressFromLatLng(_selectedLocation!);
        _calculateRouteAndDistance();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Default to a central location if unable to get current location
          _selectedLocation = const LatLng(14.5995, 120.9842); // Manila coordinates
          _isLoading = false;
        });
        _calculateRouteAndDistance();
      }
    }
  }

  Future<void> _setLocationFromLatLng(LatLng pos) async {
    setState(() {
      _selectedLocation = pos;
    });
    await _getAddressFromLatLng(pos);
    await _calculateRouteAndDistance();
  }

  Future<void> _showCoordinatesDialog() async {
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Coordinates'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: latCtrl,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d < -90 || d > 90) return 'Invalid latitude';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lngCtrl,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d < -180 || d > 180) return 'Invalid longitude';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final lat = double.parse(latCtrl.text);
              final lng = double.parse(lngCtrl.text);
              Navigator.pop(ctx);
              await _setLocationFromLatLng(LatLng(lat, lng));
            },
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
        
        setState(() {
          _selectedAddress = address;
          _searchController.text = address;
        });

        widget.onLocationSelected(
          address,
          position.latitude,
          position.longitude,
          _distance,
          widget.otherLocation,
        );
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
      
      // Even if geocoding fails, still call onLocationSelected with coordinates
      // and a basic address
      String fallbackAddress = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      setState(() {
        _selectedAddress = fallbackAddress;
        _searchController.text = fallbackAddress;
      });
      
      widget.onLocationSelected(
        fallbackAddress,
        position.latitude,
        position.longitude,
        _distance,
        widget.otherLocation,
      );
    }
  }

  void _updateCameraPosition(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_permissionDenied)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_off, color: Colors.orange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Location permission denied. You can search an address or pick a location on the map.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _getCurrentLocation,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        // Cross-platform address autocomplete
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AddressAutocomplete(
            label: widget.label,
            apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
            initialValue: _searchController.text,
            onSelected: (address, lat, lng) async {
              setState(() {
                _searchController.text = address;
                _selectedLocation = LatLng(lat, lng);
              });
              _updateCameraPosition(LatLng(lat, lng));
              await _getAddressFromLatLng(LatLng(lat, lng));
              await _calculateRouteAndDistance();
            },
          ),
        ),

        // Map view
        Container(
          height: 260,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.grey.shade100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? const LatLng(14.5995, 120.9842),
                zoom: 15,
              ),
              onMapCreated: (c) => _mapController = c,
              onTap: (pos) async {
                await _setLocationFromLatLng(pos);
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              markers: _markers,
              polylines: _polylines,
            ),
          ),
        ),

        // Selected address preview (if available)
        if (_selectedAddress.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedAddress,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_distance != null && widget.otherLocation != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _usingRealRoutes ? Icons.route : Icons.straighten,
                        size: 14,
                        color: _usingRealRoutes ? Colors.blue : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_distance!.toStringAsFixed(1)} km ${_usingRealRoutes ? "(driving route)" : "(straight line)"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _usingRealRoutes ? Colors.blue : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

        // Manual coordinate input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Enter coordinates'),
              onPressed: _showCoordinatesDialog,
            ),
          ),
        ),
      ],
    );
  }
}