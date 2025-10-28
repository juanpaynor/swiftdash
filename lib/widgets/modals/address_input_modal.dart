import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_theme.dart';
import '../../services/hybrid_address_service.dart';
import '../../models/saved_address.dart';
import '../address_input_field.dart';
import '../save_address_dialog.dart';

/// Full-screen address input modal - Angkas style
/// Wraps existing AddressInputField with full-screen presentation
class AddressInputModal extends StatefulWidget {
  final String title; // "Enter Pickup Address" or "Enter Delivery Address"
  final String? initialAddress;
  final List<SavedAddress>? savedAddresses;

  const AddressInputModal({
    Key? key,
    required this.title,
    this.initialAddress,
    this.savedAddresses,
  }) : super(key: key);

  @override
  State<AddressInputModal> createState() => _AddressInputModalState();
}

class _AddressInputModalState extends State<AddressInputModal>
    with SingleTickerProviderStateMixin {
  UnifiedDeliveryAddress? _selectedAddress;
  bool _saveAddress = false; // Checkbox state
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation setup (400ms slide-up)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onAddressSelected(UnifiedDeliveryAddress address) {
    setState(() {
      _selectedAddress = address;
    });
  }

  void _onConfirm() async {
    if (_selectedAddress != null) {
      // Save address if checkbox is checked
      if (_saveAddress) {
        await _saveAddressQuietly();
      }
      
      // Close modal and return address
      Navigator.of(context).pop(_selectedAddress);
    }
  }

  void _closeModal() {
    _animationController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AddressInputField(
                        label: widget.title,
                        hintText: 'Search for address...',
                        initialAddress: widget.initialAddress,
                        savedAddresses: widget.savedAddresses,
                        icon: Icons.search,
                        onDeliveryAddressSelected: _onAddressSelected,
                        onSavedAddressSelected: (savedAddress) {
                          // Convert SavedAddress to UnifiedDeliveryAddress
                          final unifiedAddress = UnifiedDeliveryAddress(
                            fullAddress: savedAddress.fullAddress,
                            latitude: savedAddress.latitude,
                            longitude: savedAddress.longitude,
                            types: [],
                            isFromGoogle: false,
                            sourceService: 'Saved Address',
                          );
                          _onAddressSelected(unifiedAddress);
                        },
                      ),
                      const Spacer(),
                      if (_selectedAddress != null) ...[
                        _buildSaveCheckbox(),
                        const SizedBox(height: 16),
                        _buildConfirmButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textInverse,
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textInverse),
              onPressed: _closeModal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onConfirm,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              'Confirm Address',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textInverse,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveAddressButton() {
    return Container(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _onSaveAddress,
        icon: const Icon(Icons.bookmark_add_outlined, size: 20),
        label: const Text('Save this address'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryBlue,
          side: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _saveAddress = !_saveAddress;
        });
        if (_saveAddress) {
          HapticFeedback.lightImpact();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _saveAddress 
              ? AppTheme.primaryBlue.withOpacity(0.1) 
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _saveAddress 
                ? AppTheme.primaryBlue 
                : AppTheme.borderColor,
            width: _saveAddress ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: _saveAddress ? AppTheme.primaryGradient : null,
                color: _saveAddress ? null : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _saveAddress ? Colors.transparent : AppTheme.borderColor,
                  width: 2,
                ),
              ),
              child: _saveAddress
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save this address',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _saveAddress 
                          ? AppTheme.primaryBlue 
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Quick access for future bookings',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.bookmark_add_outlined,
              color: _saveAddress 
                  ? AppTheme.primaryBlue 
                  : AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAddressQuietly() async {
    if (_selectedAddress == null) return;

    try {
      final result = await showDialog<SavedAddress>(
        context: context,
        builder: (context) => SaveAddressDialog(
          address: _selectedAddress!.fullAddress,
          latitude: _selectedAddress!.latitude,
          longitude: _selectedAddress!.longitude,
          houseNumber: _selectedAddress!.houseNumber,
          street: _selectedAddress!.street,
          barangay: _selectedAddress!.barangay,
          city: _selectedAddress!.city,
          province: _selectedAddress!.province,
        ),
      );

      if (result != null && mounted) {
        // Show brief success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${result.displayName} saved'),
            backgroundColor: AppTheme.primaryBlue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Silently fail - don't block the user
      debugPrint('Error saving address: $e');
    }
  }

  Future<void> _onSaveAddress() async {
    if (_selectedAddress == null) return;

    HapticFeedback.lightImpact();
    
    final result = await showDialog<SavedAddress>(
      context: context,
      builder: (context) => SaveAddressDialog(
        address: _selectedAddress!.fullAddress,
        latitude: _selectedAddress!.latitude,
        longitude: _selectedAddress!.longitude,
        houseNumber: _selectedAddress!.houseNumber,
        street: _selectedAddress!.street,
        barangay: _selectedAddress!.barangay,
        city: _selectedAddress!.city,
        province: _selectedAddress!.province,
      ),
    );

    if (result != null && mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.displayName} saved!'),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Show address input modal
Future<UnifiedDeliveryAddress?> showAddressInputModal({
  required BuildContext context,
  required String title,
  String? initialAddress,
  List<SavedAddress>? savedAddresses,
}) {
  return Navigator.of(context).push<UnifiedDeliveryAddress>(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddressInputModal(
          title: title,
          initialAddress: initialAddress,
          savedAddresses: savedAddresses,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      opaque: false,
      barrierColor: Colors.black54,
    ),
  );
}
