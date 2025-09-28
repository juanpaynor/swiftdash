import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

class MapboxAddressPicker extends StatelessWidget {
  final String label;
  final Function(String address, double latitude, double longitude, double? distance, LatLng? otherLocation) onLocationSelected;
  final String? initialAddress;
  final LatLng? otherLocation;
  final bool isPickup;

  const MapboxAddressPicker({
    super.key,
    required this.label,
    required this.onLocationSelected,
    this.initialAddress,
    this.otherLocation,
    required this.isPickup,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: initialAddress ?? '',
          decoration: InputDecoration(
            labelText: '$label (Web Placeholder)',
            prefixIcon: const Icon(Icons.map_outlined),
          ),
          readOnly: true,
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Mapbox web build is not available with the current package constraints.\n'
              'Please run on Android, or switch provider to Google for web temporarily.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
