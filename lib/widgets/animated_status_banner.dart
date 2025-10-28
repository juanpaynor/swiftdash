import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum DeliveryStage {
  orderConfirmed,
  driverAssigned,
  goingToPickup,
  atPickup,
  packageCollected,
  onTheWay,
  delivered,
}

class AnimatedStatusBanner extends StatefulWidget {
  final DeliveryStage currentStage;

  const AnimatedStatusBanner({
    super.key,
    required this.currentStage,
  });

  @override
  State<AnimatedStatusBanner> createState() => _AnimatedStatusBannerState();
}

class _AnimatedStatusBannerState extends State<AnimatedStatusBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getStatusMessage(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.orderConfirmed:
        return "Your order has been confirmed";
      case DeliveryStage.driverAssigned:
        return "Driver is on the way to pickup";
      case DeliveryStage.goingToPickup:
        return "Driver heading to pickup location";
      case DeliveryStage.atPickup:
        return "Driver has arrived at pickup";
      case DeliveryStage.packageCollected:
        return "Driver has your package!";
      case DeliveryStage.onTheWay:
        return "Driver heading to you now";
      case DeliveryStage.delivered:
        return "Package delivered! Enjoy! 🎉";
    }
  }

  IconData _getStageIcon(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.orderConfirmed:
        return Icons.check_circle;
      case DeliveryStage.driverAssigned:
        return Icons.person_pin_circle;
      case DeliveryStage.goingToPickup:
        return Icons.directions_car;
      case DeliveryStage.atPickup:
        return Icons.store;
      case DeliveryStage.packageCollected:
        return Icons.inventory_2;
      case DeliveryStage.onTheWay:
        return Icons.local_shipping;
      case DeliveryStage.delivered:
        return Icons.celebration;
    }
  }

  Color _getStageColor(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.orderConfirmed:
        return const Color(0xFF4CAF50);
      case DeliveryStage.driverAssigned:
        return const Color(0xFF2196F3);
      case DeliveryStage.goingToPickup:
        return const Color(0xFF2196F3);
      case DeliveryStage.atPickup:
        return const Color(0xFFFF9800);
      case DeliveryStage.packageCollected:
        return const Color(0xFF9C27B0);
      case DeliveryStage.onTheWay:
        return const Color(0xFF4CAF50);
      case DeliveryStage.delivered:
        return const Color(0xFF4CAF50);
    }
  }

  double _getProgressValue(DeliveryStage stage) {
    // Weighted progress based on actual delivery importance
    switch (stage) {
      case DeliveryStage.orderConfirmed:
        return 0.0;   // 0% - Order just placed
      case DeliveryStage.driverAssigned:
        return 0.10;  // 10% - Driver found and accepted
      case DeliveryStage.goingToPickup:
        return 0.30;  // 30% - Driver traveling to pickup location
      case DeliveryStage.atPickup:
        return 0.40;  // 40% - Driver arrived at pickup
      case DeliveryStage.packageCollected:
        return 0.50;  // 50% - Halfway! Package secured
      case DeliveryStage.onTheWay:
        return 0.80;  // 80% - Actively delivering to you
      case DeliveryStage.delivered:
        return 1.0;   // 100% - Complete!
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageColor = _getStageColor(widget.currentStage);
    final progressValue = _getProgressValue(widget.currentStage);
    final isDelivered = widget.currentStage == DeliveryStage.delivered;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            stageColor.withOpacity(0.15),
            stageColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stageColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Animated pulsing icon
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isDelivered ? 1.0 : _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: stageColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: stageColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getStageIcon(widget.currentStage),
                        color: stageColor,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              // Status message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Update',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getStatusMessage(widget.currentStage),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    '${(progressValue * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: stageColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      // Background
                      Container(
                        width: double.infinity,
                        color: Colors.black.withOpacity(0.08),
                      ),
                      // Animated progress
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        width: MediaQuery.of(context).size.width * progressValue,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              stageColor,
                              stageColor.withOpacity(0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: stageColor.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
