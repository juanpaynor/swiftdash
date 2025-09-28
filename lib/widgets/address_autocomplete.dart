import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressAutocomplete extends StatefulWidget {
  final String label;
  final String apiKey;
  final Function(String address, double lat, double lng) onSelected;
  final String? initialValue;

  const AddressAutocomplete({
    super.key,
    required this.label,
    required this.apiKey,
    required this.onSelected,
    this.initialValue,
  });

  @override
  State<AddressAutocomplete> createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<AddressAutocomplete> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;
  DateTime? _lastQueryTime;
  Future<void>? _debounceFuture;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  Future<void> _searchWeb(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    // Debounce logic: only run if 400ms have passed since last input
    _lastQueryTime = DateTime.now();
    _debounceFuture?.ignore();
    _debounceFuture = Future.delayed(const Duration(milliseconds: 400), () async {
      // If another input came in, skip this call
      if (DateTime.now().difference(_lastQueryTime!) < const Duration(milliseconds: 400)) return;
      setState(() => _loading = true);
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=${widget.apiKey}&types=geocode&language=en';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final preds = data['predictions'] as List?;
        setState(() {
          _suggestions = preds
              ?.map((p) => {
                    'description': p['description'],
                    'place_id': p['place_id'],
                  })
              .toList() ?? [];
          _loading = false;
        });
      } else {
        setState(() {
          _suggestions = [];
          _loading = false;
        });
      }
    });
  }

  Future<void> _selectWeb(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=${widget.apiKey}';
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final result = data['result'];
      final loc = result['geometry']['location'];
      final address = result['formatted_address'] ?? suggestion['description'];
      
      widget.onSelected(address, loc['lat'], loc['lng']);
      setState(() {
        _controller.text = address;
        _suggestions = [];
      });
    } else {
      print('DEBUG: AddressAutocomplete API call failed with status: ${resp.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Custom HTTP autocomplete for both platforms
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
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
          onChanged: _searchWeb,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
        if (_suggestions.isNotEmpty)
          ..._suggestions.map((s) => ListTile(
                title: Text(s['description'] ?? ''),
                onTap: () => _selectWeb(s),
              )),
      ],
    );
  }
}
