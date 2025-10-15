import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/modern_colors.dart';

/// Delivery stages for progress tracking
enum DeliveryStage {
  orderConfirmed('Order Confirmed', Icons.check_circle_outline),
  driverAssigned('Driver Assigned', Icons.person_outline),
  goingToPickup('Going to Pickup', Icons.directions_car_outlined),
  atPickup('At Pickup Location', Icons.store_outlined),
  packageCollected('Package Collected', Icons.inventory_2_outlined),
  onTheWay('On The Way', Icons.local_shipping_outlined),
  delivered('Delivered', Icons.check_circle);

  const DeliveryStage(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Get delivery stage from status string
  static DeliveryStage fromStatus(String? status) {
    switch (status) {
      case 'pending':
        return DeliveryStage.orderConfirmed;
      case 'driver_offered':
      case 'driver_assigned':
        return DeliveryStage.driverAssigned;
      case 'going_to_pickup':
        return DeliveryStage.goingToPickup;
      case 'pickup_arrived':
        return DeliveryStage.atPickup;
      case 'package_collected':
        return DeliveryStage.packageCollected;
      case 'going_to_destination':
      case 'at_destination':
      case 'in_transit':
        return DeliveryStage.onTheWay;
      case 'delivered':
        return DeliveryStage.delivered;
      default:
        return DeliveryStage.orderConfirmed;
    }
  }
}

/// Modern vertical progress stepper for delivery tracking
class VerticalProgressStepper extends StatelessWidget {
  final DeliveryStage currentStage;
  final bool showLabels;
  final double width;

  const VerticalProgressStepper({
    Key? key,
    required this.currentStage,
    this.showLabels = false,
    this.width = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      child: Column(
        children: DeliveryStage.values
            .map((stage) => _buildStepperItem(stage))
            .toList(),
      ),
    );
  }

  Widget _buildStepperItem(DeliveryStage stage) {
    final isCompleted = stage.index <= currentStage.index;
    final isCurrent = stage == currentStage;
    final isLast = stage == DeliveryStage.values.last;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Column(
            children: [
              _buildStageIcon(stage, isCompleted, isCurrent),
              
              // Connecting line (if not last item)
              if (!isLast)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 2,
                  height: 32,
                  color: isCompleted 
                      ? ModernColors.primaryBlue 
                      : ModernColors.borderGrey,
                ),
            ],
          ),
          
          // Label (if enabled)
          if (showLabels) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  stage.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: isCompleted || isCurrent 
                        ? ModernColors.darkGrey 
                        : ModernColors.mediumGrey,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageIcon(DeliveryStage stage, bool isCompleted, bool isCurrent) {
    Color backgroundColor;
    Color iconColor;
    Color borderColor;

    if (isCompleted) {
      backgroundColor = ModernColors.primaryBlue;
      iconColor = Colors.white;
      borderColor = ModernColors.primaryBlue;
    } else if (isCurrent) {
      backgroundColor = Colors.white;
      iconColor = ModernColors.primaryBlue;
      borderColor = ModernColors.primaryBlue;
    } else {
      backgroundColor = Colors.white;
      iconColor = ModernColors.lightGrey;
      borderColor = ModernColors.borderGrey;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: isCurrent || isCompleted ? ModernShadows.small : null,
      ),
      child: Icon(
        stage.icon,
        color: iconColor,
        size: 20,
      ),
    );
  }
}

/// Compact horizontal progress indicator
class HorizontalProgressIndicator extends StatelessWidget {
  final DeliveryStage currentStage;
  final double height;

  const HorizontalProgressIndicator({
    Key? key,
    required this.currentStage,
    this.height = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalStages = DeliveryStage.values.length;
    final currentIndex = currentStage.index;
    final progress = (currentIndex + 1) / totalStages;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ModernColors.borderGrey,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: ModernColors.primaryBlue,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// Modern stage indicator with animated transitions
class StageIndicatorCard extends StatelessWidget {
  final DeliveryStage currentStage;
  final String? customMessage;

  const StageIndicatorCard({
    Key? key,
    required this.currentStage,
    this.customMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernColors.accentBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ModernColors.blueAccentLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ModernColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              currentStage.icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentStage.label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ModernColors.darkGrey,
                  ),
                ),
                if (customMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    customMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ModernColors.mediumGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}