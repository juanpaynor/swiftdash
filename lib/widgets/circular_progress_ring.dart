import 'dart:math';
import 'package:flutter/material.dart';
import 'animated_status_banner.dart';

/// Wolt-inspired circular progress ring for delivery tracking
/// Features:
/// - Smooth circular progress animation
/// - Blue gradient color scheme
/// - Stage name in center (no icons)
/// - Medium thickness ring
class CircularProgressRing extends StatefulWidget {
  final DeliveryStage currentStage;
  final double size;
  final String? eta;

  const CircularProgressRing({
    super.key,
    required this.currentStage,
    this.size = 220,  // Increased from 180
    this.eta,
  });

  @override
  State<CircularProgressRing> createState() => _CircularProgressRingState();
}

class _CircularProgressRingState extends State<CircularProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _targetProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: _targetProgress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _updateProgress();
  }

  @override
  void didUpdateWidget(CircularProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStage != widget.currentStage) {
      _updateProgress();
    }
  }

  void _updateProgress() {
    final newProgress = _getProgressValue(widget.currentStage);
    setState(() {
      _targetProgress = newProgress;
    });

    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: _targetProgress,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getProgressValue(DeliveryStage stage) {
    // Must match animated_status_banner.dart progress values
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

  String _getStageName(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.orderConfirmed:
        return 'Confirmed';
      case DeliveryStage.driverAssigned:
        return 'Driver\nAssigned';
      case DeliveryStage.goingToPickup:
        return 'Going to\nPickup';
      case DeliveryStage.atPickup:
        return 'At Pickup';
      case DeliveryStage.packageCollected:
        return 'Package\nCollected';
      case DeliveryStage.onTheWay:
        return 'On the Way';
      case DeliveryStage.delivered:
        return 'Delivered';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E4A9B).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated progress ring
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _CircularProgressPainter(
                  progress: _progressAnimation.value,
                  strokeWidth: 12,
                ),
              );
            },
          ),

          // Center content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stage name
                Text(
                  _getStageName(widget.currentStage),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                    height: 1.2,
                  ),
                ),

                // Optional ETA display
                if (widget.eta != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.eta!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E4A9B).withOpacity(0.7),
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

/// Custom painter for the circular progress ring
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track (light gray)
    final backgroundPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc (blue gradient)
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      
      // Create gradient shader
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + (2 * pi * progress),
        colors: const [
          Color(0xFF2E4A9B), // Dark blue
          Color(0xFF1DA1F2), // Light blue
        ],
        tileMode: TileMode.clamp,
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw progress arc (starts from top, goes clockwise)
      canvas.drawArc(
        rect,
        -pi / 2, // Start from top
        2 * pi * progress, // Sweep angle based on progress
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
