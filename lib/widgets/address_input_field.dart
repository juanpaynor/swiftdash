import 'dart:async';
import 'package:flutter/material.dart';
import '../services/hybrid_address_service.dart'; // NEW: Use hybrid service
import '../constants/app_theme.dart';

class AddressInputField extends StatefulWidget {
  final String label;
  final String hintText;
  final String? initialAddress;
  final Function(String address, double lat, double lng)? onLocationSelected;
  final Function(UnifiedDeliveryAddress)? onDeliveryAddressSelected; // UPDATED: Use unified model
  final IconData icon;

  const AddressInputField({
    super.key,
    required this.label,
    required this.hintText,
    this.initialAddress,
    this.onLocationSelected,
    this.onDeliveryAddressSelected, // NEW: Optional callback for exact delivery address
    this.icon = Icons.location_on,
  });

  @override
  State<AddressInputField> createState() => _AddressInputFieldState();
}

class _AddressInputFieldState extends State<AddressInputField> {
  final TextEditingController _controller = TextEditingController();
  List<UnifiedAddressSuggestion> _suggestions = []; // UPDATED: Use unified suggestions
  bool _isSearching = false;
  bool _showSuggestions = false;
  Timer? _debounceTimer; // OPTIMIZATION: Add debouncing

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialAddress ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel(); // Clean up timer
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // OPTIMIZATION: Cancel previous timer to debounce API calls
    _debounceTimer?.cancel();
    
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

    // OPTIMIZATION: Wait 500ms before making API call (debouncing)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      try {
        final suggestions = await HybridAddressService.getAddressSuggestions(value); // UPDATED: Use hybrid service
        if (mounted) {
          setState(() {
            _suggestions = suggestions;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  void _selectSuggestion(UnifiedAddressSuggestion suggestion) async { // UPDATED: Use unified suggestion
    setState(() {
      _controller.text = suggestion.displayName;
      _suggestions = [];
      _showSuggestions = false;
    });

    // Notify parent about the selected location (basic callback)
    widget.onLocationSelected?.call(
      suggestion.displayName,
      suggestion.latitude,
      suggestion.longitude,
    );

    // NEW: Get exact delivery address details if callback is provided
    if (widget.onDeliveryAddressSelected != null) {
      try {
        setState(() => _isSearching = true);
        
        // Get precise delivery address details using hybrid service
        final deliveryAddress = await HybridAddressService.getExactDeliveryAddress(suggestion); // UPDATED: Use hybrid service
        
        if (deliveryAddress != null && mounted) {
          widget.onDeliveryAddressSelected!(deliveryAddress);
          
          // Update the display with more precise address if available
          if (deliveryAddress.deliveryLabel.isNotEmpty) {
            setState(() {
              _controller.text = deliveryAddress.deliveryLabel;
            });
          }
        }
      } catch (e) {
        print('Error getting exact delivery address: $e');
      } finally {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    }
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
                    _getIconForSuggestion(suggestion),
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  title: Text(
                    suggestion.mainText ?? suggestion.displayName,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: suggestion.secondaryText != null && suggestion.secondaryText!.isNotEmpty
                      ? Text(
                          suggestion.secondaryText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : null,
                  onTap: () => _selectSuggestion(suggestion),
                  dense: true,
                );
              },
            ),
          ),
      ],
    );
  }

  /// UPDATED: Get appropriate icon based on suggestion type
  IconData _getIconForSuggestion(UnifiedAddressSuggestion suggestion) {
    final iconType = suggestion.iconType;
    
    switch (iconType) {
      case 'business':
        return Icons.business;
      case 'road':
        return Icons.route;
      case 'intersection':
        return Icons.traffic;
      case 'home':
        return Icons.home;
      default:
        return Icons.location_on;
    }
  }
}