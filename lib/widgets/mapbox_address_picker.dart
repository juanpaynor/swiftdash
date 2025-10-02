import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
// Google Maps removed - using Mapbox only
import '../services/mapbox_service.dart';
import '../constants/app_theme.dart';

class MapboxAddressPicker extends StatefulWidget {
  final String label;
  final String? initialAddress;
  final bool isPickup;
  final Function(String address, double lat, double lng, double? distance)? onLocationSelected;
  final double? otherLatitude;
  final double? otherLongitude;

  const MapboxAddressPicker({
    super.key,
    required this.label,
    this.initialAddress,
    this.isPickup = false,
    this.onLocationSelected,
    this.otherLatitude,
    this.otherLongitude,
  });

  @override
  State<MapboxAddressPicker> createState() => _MapboxAddressPickerState();
}

class _MapboxAddressPickerState extends State<MapboxAddressPicker> {
  MapboxMap? _mapboxMap;
  final TextEditingController _searchController = TextEditingController();
  List<MapboxGeocodeSuggestion> _suggestions = [];
  bool _isSearching = false;
  Position? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialAddress ?? '';
    // Initialize with Metro Manila coordinates
    _selectedLocation = Position(MapboxService.metroManilaLng, MapboxService.metroManilaLat);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
  }

  void _onSearchChanged(String value) async {
    if (value.length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final suggestions = await MapboxService.getAddressSuggestions(value);
      setState(() {
        _suggestions = suggestions;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectSuggestion(MapboxGeocodeSuggestion suggestion) async {
    setState(() {
      _searchController.text = suggestion.displayName;
      _suggestions = [];
      _selectedLocation = Position(suggestion.longitude, suggestion.latitude);
    });

    // Calculate distance if other location is provided
    double? distance;
    if (widget.otherLatitude != null && widget.otherLongitude != null) {
      distance = await MapboxService.calculateDistance(
        suggestion.latitude,
        suggestion.longitude,
        widget.otherLatitude!,
        widget.otherLongitude!,
      );
    }

    // Callback with selected location
    widget.onLocationSelected?.call(
      suggestion.displayName,
      suggestion.latitude,
      suggestion.longitude,
      distance,
    );

    // Update map position
    if (_mapboxMap != null) {
      _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(suggestion.longitude, suggestion.latitude)),
          zoom: 16.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        
        // Interactive Map - Always visible like DoorDash
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MapWidget(
              key: ValueKey("mapbox_${widget.isPickup ? 'pickup' : 'delivery'}"),
              onMapCreated: _onMapCreated,
              cameraOptions: CameraOptions(
                center: Point(coordinates: _selectedLocation!),
                zoom: 12.0,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Search Field
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search addresses in Philippines...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _isSearching 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _suggestions = [];
                        // Reset to Metro Manila
                        _selectedLocation = Position(MapboxService.metroManilaLng, MapboxService.metroManilaLat);
                      });
                      if (_mapboxMap != null) {
                        _mapboxMap!.setCamera(
                          CameraOptions(
                            center: Point(coordinates: _selectedLocation!),
                            zoom: 12.0,
                          ),
                        );
                      }
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        // Suggestions list
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, color: AppTheme.primaryBlue),
                  title: Text(
                    suggestion.displayName,
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}