import 'dart:async';
import 'dart:math' show asin, cos, pi, pow, sin, sqrt;
import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart' as mbx;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng; // reuse LatLng type for interop
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../config/env.dart';
import '../services/mapbox_service.dart';

class MapboxAddressPicker extends StatefulWidget {
  final String label;
  final Function(String address, double latitude, double longitude, double? distance, LatLng? otherLocation) onLocationSelected;
  final String? initialAddress;
  final LatLng? otherLocation; // The other point to draw route to
  final bool isPickup; // Whether this is pickup (true) or delivery (false) point

  const MapboxAddressPicker({
    super.key,
    required this.label,
    required this.onLocationSelected,
    this.initialAddress,
    this.otherLocation,
    required this.isPickup,
  });

  @override
  State<MapboxAddressPicker> createState() => _MapboxAddressPickerState();
}

class _MapboxAddressPickerState extends State<MapboxAddressPicker> {
  final TextEditingController _searchController = TextEditingController();
  mbx.MapboxMapController? _controller;
  LatLng? _selectedLocation;
  bool _isLoading = true;
  String _selectedAddress = '';
  double? _distance;
  bool _permissionDenied = false;
  bool _usingRealRoute = false;
  List<MapboxGeocodeSuggestion> _suggestions = [];
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialAddress ?? '';
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
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

      final Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
          _permissionDenied = false;
        });
        _updateCamera(_selectedLocation!);
        _getAddressFromLatLng(_selectedLocation!);
        _updateRouteAndDistance();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedLocation = const LatLng(14.5995, 120.9842); // Manila
          _isLoading = false;
        });
        _updateRouteAndDistance();
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    // Prefer Mapbox reverse geocoding; fall back to platform geocoding
    String? addr = await MapboxService.reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (addr == null || addr.isEmpty) {
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          addr = '${p.street}, ${p.subLocality}, ${p.locality}, ${p.postalCode}';
        }
      } catch (_) {}
    }
    final resolvedAddr = addr ?? 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    if (!mounted) return;
    setState(() {
      _selectedAddress = resolvedAddr;
      _searchController.text = resolvedAddr;
    });
    widget.onLocationSelected(resolvedAddr, position.latitude, position.longitude, _distance, widget.otherLocation);
  }

  void _updateCamera(LatLng pos) {
    _controller?.moveCamera(mbx.CameraUpdate.newLatLng(mbx.LatLng(pos.latitude, pos.longitude)));
  }

  Future<void> _updateRouteAndDistance() async {
    if (_selectedLocation == null || widget.otherLocation == null) {
      return;
    }
    // Try Mapbox Directions for real route; fall back to straight line
    final route = await MapboxService.getDrivingRoute(
      origin: _selectedLocation!,
      destination: widget.otherLocation!,
    );
    if (route != null && route.points.length >= 2) {
      setState(() { 
        _distance = route.distanceKm; 
        _usingRealRoute = true;
      });
      if (_controller != null) {
        try {
          await _controller!.clearLines();
        } catch (_) {}
        try {
          await _controller!.addLine(mbx.LineOptions(
            geometry: route.points,
            lineColor: '#1976D2',
            lineWidth: 6.0,
            lineOpacity: 0.95,
          ));
        } catch (_) {}
        // Adjust camera to fit route
        if (route.points.isNotEmpty) {
          final lats = route.points.map((p) => p.latitude);
          final lngs = route.points.map((p) => p.longitude);
          final sw = mbx.LatLng(lats.reduce((a,b)=>a<b?a:b), lngs.reduce((a,b)=>a<b?a:b));
          final ne = mbx.LatLng(lats.reduce((a,b)=>a>b?a:b), lngs.reduce((a,b)=>a>b?a:b));
          try {
            await _controller!.animateCamera(mbx.CameraUpdate.newLatLngBounds(mbx.LatLngBounds(southwest: sw, northeast: ne),
              left: 50, right: 50, top: 80, bottom: 80));
          } catch (_) {}
        }
      }
      // Inform parent about updated distance
      final addr = _selectedAddress.isNotEmpty 
          ? _selectedAddress 
          : 'Location: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}';
      widget.onLocationSelected(addr, _selectedLocation!.latitude, _selectedLocation!.longitude, _distance, widget.otherLocation);
      return;
    }

    // Fallback: straight-line
    const double R = 6371; // km
    final lat1 = _selectedLocation!.latitude * pi / 180;
    final lon1 = _selectedLocation!.longitude * pi / 180;
    final lat2 = widget.otherLocation!.latitude * pi / 180;
    final lon2 = widget.otherLocation!.longitude * pi / 180;
    final dlon = lon2 - lon1;
    final dlat = lat2 - lat1;
    final a = pow(sin(dlat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);
    final c = 2 * asin(sqrt(a));
    final distance = R * c;
    setState(() { 
      _distance = distance; 
      _usingRealRoute = false;
    });
    if (_controller != null) {
      try { await _controller!.clearLines(); } catch (_) {}
      try {
        await _controller!.addLine(mbx.LineOptions(
          geometry: [
            mbx.LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude),
            mbx.LatLng(widget.otherLocation!.latitude, widget.otherLocation!.longitude),
          ],
          lineColor: '#FF9800',
          lineWidth: 4.0,
          lineOpacity: 0.9,
        ));
      } catch (_) {}
    }
  // Inform parent about updated distance on fallback too
  final addr = _selectedAddress.isNotEmpty 
    ? _selectedAddress 
    : 'Location: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}';
  widget.onLocationSelected(addr, _selectedLocation!.latitude, _selectedLocation!.longitude, _distance, widget.otherLocation);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar (Mapbox forward geocoding)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: widget.label,
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (q) async {
                  if (q.trim().isEmpty) { setState(() => _suggestions = []); return; }
                  setState(() => _searchLoading = true);
                  final results = await MapboxService.forwardGeocode(q);
                  if (!mounted) return;
                  setState(() {
                    _suggestions = results;
                    _searchLoading = false;
                  });
                },
              ),
              if (_searchLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        leading: const Icon(Icons.place_outlined, size: 20),
                        title: Text(s.placeName, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          setState(() { _suggestions = []; });
                          final pos = LatLng(s.latitude, s.longitude);
                          setState(() { _selectedLocation = pos; });
                          _updateCamera(pos);
                          await _getAddressFromLatLng(pos);
                          await _updateRouteAndDistance();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
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
              ],
            ),
          ),

        // Map
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
            child: mbx.MapboxMap(
              accessToken: Env.mapboxAccessToken,
              styleString: Env.mapboxStyleUrl,
              initialCameraPosition: mbx.CameraPosition(
                target: mbx.LatLng(
                  _selectedLocation?.latitude ?? 14.5995,
                  _selectedLocation?.longitude ?? 120.9842,
                ),
                zoom: 14,
              ),
              onMapCreated: (c) => _controller = c,
              onMapClick: (p, latLng) async {
                setState(() {
                  _selectedLocation = LatLng(latLng.latitude, latLng.longitude);
                });
                _updateCamera(_selectedLocation!);
                await _getAddressFromLatLng(_selectedLocation!);
                await _updateRouteAndDistance();
              },
            ),
          ),
        ),

        if (_selectedAddress.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedAddress, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (_distance != null && widget.otherLocation != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_usingRealRoute ? Icons.route : Icons.straighten, size: 14, color: _usingRealRoute ? Colors.blue : Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '${_distance!.toStringAsFixed(1)} km ${_usingRealRoute ? '(driving route)' : '(straight line)'}',
                        style: TextStyle(fontSize: 12, color: _usingRealRoute ? Colors.blue : Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
