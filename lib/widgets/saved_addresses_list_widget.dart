import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_theme.dart';
import '../models/saved_address.dart';

/// Widget to display saved addresses in a scrollable horizontal list
/// Shows at the top of address input search results
class SavedAddressesListWidget extends StatelessWidget {
  final List<SavedAddress> savedAddresses;
  final Function(SavedAddress) onAddressTap;
  final Function(SavedAddress)? onAddressLongPress;

  const SavedAddressesListWidget({
    super.key,
    required this.savedAddresses,
    required this.onAddressTap,
    this.onAddressLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (savedAddresses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Saved Places',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Horizontal scrollable list
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: savedAddresses.length,
            itemBuilder: (context, index) {
              final address = savedAddresses[index];
              return _SavedAddressCard(
                address: address,
                onTap: () => onAddressTap(address),
                onLongPress: onAddressLongPress != null 
                    ? () => onAddressLongPress!(address)
                    : null,
              );
            },
          ),
        ),

        // Divider
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(height: 1, color: AppTheme.borderColor),
        ),
      ],
    );
  }
}

/// Individual saved address card
class _SavedAddressCard extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SavedAddressCard({
    required this.address,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji
            Text(
              address.emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 6),
            
            // Label
            Text(
              address.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Short address
            if (address.shortAddress.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                address.shortAddress,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vertical list variant for showing saved addresses in search results
class SavedAddressesVerticalList extends StatelessWidget {
  final List<SavedAddress> savedAddresses;
  final Function(SavedAddress) onAddressTap;
  final Function(SavedAddress)? onAddressLongPress;
  final String? searchQuery;

  const SavedAddressesVerticalList({
    super.key,
    required this.savedAddresses,
    required this.onAddressTap,
    this.onAddressLongPress,
    this.searchQuery,
  });

  List<SavedAddress> get _filteredAddresses {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return savedAddresses;
    }

    final query = searchQuery!.toLowerCase();
    return savedAddresses.where((address) {
      return address.label.toLowerCase().contains(query) ||
          address.fullAddress.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAddresses;
    
    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.bookmark,
                size: 16,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                'Saved Places',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        // List items
        ...filtered.map((address) => _SavedAddressListTile(
          address: address,
          onTap: () => onAddressTap(address),
          onLongPress: onAddressLongPress != null 
              ? () => onAddressLongPress!(address)
              : null,
          searchQuery: searchQuery,
        )),

        // Divider after saved addresses
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(height: 1, color: AppTheme.borderColor),
        ),
      ],
    );
  }
}

/// List tile for vertical saved address display
class _SavedAddressListTile extends StatelessWidget {
  final SavedAddress address;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? searchQuery;

  const _SavedAddressListTile({
    required this.address,
    required this.onTap,
    this.onLongPress,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Emoji icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  address.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Address details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label
                  Text(
                    address.label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  
                  // Full address
                  Text(
                    address.fullAddress,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Indicator
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
