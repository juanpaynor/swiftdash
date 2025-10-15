import 'dart:async';
import 'package:flutter/material.dart';
import '../services/hybrid_address_service.dart'; // NEW: Use hybrid service
import '../models/saved_address.dart';
import '../constants/app_theme.dart';

class AddressInputField extends StatefulWidget {
  final String label;
  final String hintText;
  final String? initialAddress;
  final Function(String address, double lat, double lng)? onLocationSelected;
  final Function(UnifiedDeliveryAddress)? onDeliveryAddressSelected; // UPDATED: Use unified model
  final Function(SavedAddress)? onSavedAddressSelected; // NEW: Callback for saved address
  final List<SavedAddress>? savedAddresses; // NEW: List of saved addresses
  final IconData icon;

  const AddressInputField({
    super.key,
    required this.label,
    required this.hintText,
    this.initialAddress,
    this.onLocationSelected,
    this.onDeliveryAddressSelected, // NEW: Optional callback for exact delivery address
    this.onSavedAddressSelected, // NEW: Optional callback for saved addresses
    this.savedAddresses, // NEW: Optional saved addresses list
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
    // NOTE: Google Places suggestions have (0,0) coordinates by design
    // Real coordinates come from Place Details API call below
    // Only validate if suggestion is from Mapbox (which has coordinates)
    if (!suggestion.isGooglePlace && suggestion.latitude == 0.0 && suggestion.longitude == 0.0) {
      print('⚠️ WARNING: Non-Google suggestion has invalid coordinates (0.0, 0.0)');
      print('  Display name: ${suggestion.displayName}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected location has invalid coordinates. Please try a different address.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return; // Don't select this suggestion
    }

    print('✅ Valid suggestion selected:');
    print('  Address: ${suggestion.displayName}');
    print('  Is Google Place: ${suggestion.isGooglePlace}');
    if (!suggestion.isGooglePlace) {
      print('  Coordinates: (${suggestion.latitude}, ${suggestion.longitude})');
    } else {
      print('  Coordinates: Will be fetched from Place Details API');
    }

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
          // Validate coordinates from delivery address
          if (deliveryAddress.latitude == 0.0 && deliveryAddress.longitude == 0.0) {
            print('⚠️ WARNING: Delivery address has invalid coordinates (0.0, 0.0)');
            print('  This usually means Google Place Details API failed');
            print('  Falling back to suggestion coordinates: (${suggestion.latitude}, ${suggestion.longitude})');
            
            // If suggestion also has 0,0, show error
            if (suggestion.latitude == 0.0 && suggestion.longitude == 0.0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to get coordinates for this location. Please try a different address.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              return;
            }
            
            // Use suggestion coordinates as fallback
            final fallbackAddress = UnifiedDeliveryAddress(
              fullAddress: deliveryAddress.fullAddress.isNotEmpty ? deliveryAddress.fullAddress : suggestion.displayName,
              latitude: suggestion.latitude,
              longitude: suggestion.longitude,
              name: deliveryAddress.name,
              houseNumber: deliveryAddress.houseNumber,
              street: deliveryAddress.street,
              barangay: deliveryAddress.barangay,
              city: deliveryAddress.city,
              province: deliveryAddress.province,
              postalCode: deliveryAddress.postalCode,
              sourceService: suggestion.sourceService,
              types: deliveryAddress.types,
              isFromGoogle: deliveryAddress.isFromGoogle,
            );
            
            widget.onDeliveryAddressSelected!(fallbackAddress);
          } else {
            // Coordinates are valid, use them
            print('✅ Delivery address has valid coordinates: (${deliveryAddress.latitude}, ${deliveryAddress.longitude})');
            widget.onDeliveryAddressSelected!(deliveryAddress);
          }
          
          // Update the display with more precise address if available
          if (deliveryAddress.deliveryLabel.isNotEmpty) {
            setState(() {
              _controller.text = deliveryAddress.deliveryLabel;
            });
          }
        } else {
          print('⚠️ WARNING: getExactDeliveryAddress returned null');
          print('  Using suggestion coordinates as fallback');
          
          // If no delivery address returned, create one from suggestion
          if (suggestion.latitude != 0.0 || suggestion.longitude != 0.0) {
            final fallbackAddress = UnifiedDeliveryAddress(
              fullAddress: suggestion.displayName,
              latitude: suggestion.latitude,
              longitude: suggestion.longitude,
              sourceService: suggestion.sourceService,
              types: suggestion.types,
              isFromGoogle: suggestion.isGooglePlace,
            );
            widget.onDeliveryAddressSelected!(fallbackAddress);
          }
        }
      } catch (e) {
        print('Error getting exact delivery address: $e');
        print('Using suggestion coordinates as fallback');
        
        // On error, try to use suggestion coordinates if valid
        if (suggestion.latitude != 0.0 || suggestion.longitude != 0.0) {
          final fallbackAddress = UnifiedDeliveryAddress(
            fullAddress: suggestion.displayName,
            latitude: suggestion.latitude,
            longitude: suggestion.longitude,
            sourceService: suggestion.sourceService,
            types: suggestion.types,
            isFromGoogle: suggestion.isGooglePlace,
          );
          widget.onDeliveryAddressSelected!(fallbackAddress);
        }
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
        if (_showSuggestions)
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Saved addresses section (shown first)
                if (widget.savedAddresses != null && widget.savedAddresses!.isNotEmpty && _controller.text.length >= 2)
                  ..._buildSavedAddressesList(),
                
                // Regular autocomplete suggestions
                if (_suggestions.isNotEmpty)
                  ListView.builder(
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
              ],
            ),
          ),
      ],
    );
  }

  /// Build saved addresses list (shown first in suggestions)
  List<Widget> _buildSavedAddressesList() {
    if (widget.savedAddresses == null || widget.savedAddresses!.isEmpty) {
      return [];
    }

    final query = _controller.text.toLowerCase();
    final filteredSaved = widget.savedAddresses!.where((address) {
      return address.label.toLowerCase().contains(query) ||
          address.fullAddress.toLowerCase().contains(query);
    }).toList();

    if (filteredSaved.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.bookmark, size: 14, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            Text(
              'Saved Places',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
      ...filteredSaved.map((address) {
        return ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                address.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          title: Text(
            address.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            address.fullAddress,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            if (widget.onSavedAddressSelected != null) {
              widget.onSavedAddressSelected!(address);
              _controller.text = address.fullAddress;
              setState(() {
                _showSuggestions = false;
              });
            }
          },
          dense: true,
        );
      }),
      const Divider(height: 1),
    ];
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