import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/modern_colors.dart';

/// Modern floating card for delivery tracking focus area
class ModernFloatingCard extends StatelessWidget {
  final String eta;
  final String arrivalTime;
  final String? driverName;
  final double? driverRating;
  final String? vehicleInfo;
  final String? plateNumber;
  final String? driverPhotoUrl;
  final VoidCallback? onCallDriver;
  final VoidCallback? onMessageDriver;
  final String? deliveryStatus;
  final Widget? additionalContent;

  const ModernFloatingCard({
    Key? key,
    required this.eta,
    required this.arrivalTime,
    this.driverName,
    this.driverRating,
    this.vehicleInfo,
    this.plateNumber,
    this.driverPhotoUrl,
    this.onCallDriver,
    this.onMessageDriver,
    this.deliveryStatus,
    this.additionalContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ModernColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ModernShadows.large,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildETASection(),
            if (driverName != null) ...[
              const SizedBox(height: 20),
              _buildDriverSection(),
            ],
            if (additionalContent != null) ...[
              const SizedBox(height: 16),
              additionalContent!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildETASection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ModernColors.accentBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ModernColors.blueAccentLight,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Main ETA display
          Text(
            'Arriving in $eta',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ModernColors.darkGrey,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 4),
          
          // Estimated arrival time
          Text(
            'Estimated Arrival: $arrivalTime',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ModernColors.mediumGrey,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Status message if provided
          if (deliveryStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              _getStatusMessage(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ModernColors.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverSection() {
    return Row(
      children: [
        // Driver avatar
        _buildDriverAvatar(),
        
        const SizedBox(width: 16),
        
        // Driver details
        Expanded(
          child: _buildDriverDetails(),
        ),
        
        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildDriverAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ModernColors.blueAccentMedium,
          width: 2,
        ),
        boxShadow: ModernShadows.small,
      ),
      child: CircleAvatar(
        radius: 26,
        backgroundImage: driverPhotoUrl != null && driverPhotoUrl!.isNotEmpty
            ? NetworkImage(driverPhotoUrl!)
            : null,
        backgroundColor: ModernColors.veryLightGrey,
        child: driverPhotoUrl == null || driverPhotoUrl!.isEmpty
            ? Icon(
                Icons.person,
                color: ModernColors.lightGrey,
                size: 28,
              )
            : null,
      ),
    );
  }

  Widget _buildDriverDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Driver name and rating
        Row(
          children: [
            Expanded(
              child: Text(
                driverName ?? 'Driver',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ModernColors.darkGrey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (driverRating != null) ...[
              const SizedBox(width: 8),
              _buildRatingBadge(),
            ],
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Vehicle information
        if (vehicleInfo != null || plateNumber != null)
          Text(
            _buildVehicleText(),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ModernColors.mediumGrey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildRatingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ModernColors.blueAccentLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            size: 12,
            color: ModernColors.primaryBlue,
          ),
          const SizedBox(width: 2),
          Text(
            driverRating!.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ModernColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onMessageDriver != null)
          _buildActionButton(
            icon: Icons.message,
            onPressed: onMessageDriver!,
            isPrimary: false,
          ),
        if (onCallDriver != null && onMessageDriver != null)
          const SizedBox(width: 8),
        if (onCallDriver != null)
          _buildActionButton(
            icon: Icons.phone,
            onPressed: onCallDriver!,
            isPrimary: true,
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isPrimary ? ModernColors.primaryBlue : ModernColors.veryLightGrey,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isPrimary ? ModernShadows.blueGlow : ModernShadows.small,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isPrimary ? Colors.white : ModernColors.mediumGrey,
          size: 20,
        ),
        onPressed: onPressed,
      ),
    );
  }

  String _buildVehicleText() {
    final parts = <String>[];
    if (vehicleInfo != null && vehicleInfo!.isNotEmpty) {
      parts.add(vehicleInfo!);
    }
    if (plateNumber != null && plateNumber!.isNotEmpty) {
      parts.add(plateNumber!);
    }
    return parts.join(' • ');
  }

  String _getStatusMessage() {
    switch (deliveryStatus) {
      case 'driver_assigned':
        return 'Driver is preparing for pickup';
      case 'going_to_pickup':
        return 'Driver is heading to pickup location';
      case 'pickup_arrived':
        return 'Driver has arrived at pickup';
      case 'package_collected':
        return 'Package collected, heading your way';
      case 'going_to_destination':
        return 'Driver is on the way to you';
      case 'at_destination':
        return 'Driver has arrived at your location';
      default:
        return 'Live tracking active';
    }
  }
}

/// Compact ETA card for minimal display
class CompactETACard extends StatelessWidget {
  final String eta;
  final String? status;
  final IconData? statusIcon;

  const CompactETACard({
    Key? key,
    required this.eta,
    this.status,
    this.statusIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ModernColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernShadows.medium,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusIcon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ModernColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                statusIcon,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ETA: $eta',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ModernColors.darkGrey,
                ),
              ),
              if (status != null) ...[
                const SizedBox(height: 2),
                Text(
                  status!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ModernColors.mediumGrey,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}