import 'package:flutter/material.dart';
import '../services/mapbox_service.dart';
import '../constants/app_theme.dart';

class AddressInputField extends StatefulWidget {
  final String label;
  final String hintText;
  final String? initialAddress;
  final Function(String address, double lat, double lng)? onLocationSelected;
  final IconData icon;

  const AddressInputField({
    super.key,
    required this.label,
    required this.hintText,
    this.initialAddress,
    this.onLocationSelected,
    this.icon = Icons.location_on,
  });

  @override
  State<AddressInputField> createState() => _AddressInputFieldState();
}

class _AddressInputFieldState extends State<AddressInputField> {
  final TextEditingController _controller = TextEditingController();
  List<MapboxGeocodeSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialAddress ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) async {
    if (value.length < 3) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSuggestions = true;
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

  void _selectSuggestion(MapboxGeocodeSuggestion suggestion) {
    setState(() {
      _controller.text = suggestion.displayName;
      _suggestions = [];
      _showSuggestions = false;
    });

    // Notify parent about the selected location
    widget.onLocationSelected?.call(
      suggestion.displayName,
      suggestion.latitude,
      suggestion.longitude,
    );
  }

  void _clearInput() {
    _controller.clear();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        
        // Input field
        TextField(
          controller: _controller,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(widget.icon, color: AppTheme.primaryBlue),
            suffixIcon: _isSearching 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearInput,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        
        // Suggestions list
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  title: Text(
                    suggestion.displayName,
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                  dense: true,
                );
              },
            ),
          ),
      ],
    );
  }
}