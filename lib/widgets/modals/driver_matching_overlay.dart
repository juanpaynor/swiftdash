import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_theme.dart';

/// Animated driver matching overlay - replaces matching screen
/// Shows pulse animation while searching, success animation when found, failure state with retry options
class DriverMatchingOverlay extends StatefulWidget {
  final VoidCallback? onDriverFound;
  final VoidCallback? onCancel;
  final Duration searchTimeout; // Duration before showing failure state

  const DriverMatchingOverlay({
    Key? key,
    this.onDriverFound,
    this.onCancel,
    this.searchTimeout = const Duration(seconds: 15), // Default 15 seconds
  }) : super(key: key);

  @override
  State<DriverMatchingOverlay> createState() => _DriverMatchingOverlayState();
}

class _DriverMatchingOverlayState extends State<DriverMatchingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _successController;
  late AnimationController _rotationController;
  late AnimationController _glowController;
  
  bool _isMatched = false;
  bool _isFailed = false;
  bool _isSearching = true;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation (searching state) - smoother, slower pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Rotation animation for search icon
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Glow animation for rings
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Fade in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeController.forward();

    // Success animation (when driver found)
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Start timeout timer for failure state
    Future.delayed(widget.searchTimeout, () {
      if (mounted && _isSearching && !_isMatched) {
        _showFailureState();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _successController.dispose();
    _rotationController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void showSuccess() {
    if (_isMatched || _isFailed) return;
    
    setState(() {
      _isMatched = true;
      _isSearching = false;
    });
    
    _pulseController.stop();
    _rotationController.stop();
    _glowController.stop();
    _successController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        widget.onDriverFound?.call();
        _closeOverlay();
      });
    });
  }

  void _showFailureState() {
    if (_isMatched || _isFailed) return;

    setState(() {
      _isFailed = true;
      _isSearching = false;
    });

    _pulseController.stop();
    _rotationController.stop();
    _glowController.stop();
  }

  void _keepSearching() {
    setState(() {
      _isFailed = false;
      _isSearching = true;
    });

    _pulseController.repeat();
    _rotationController.repeat();
    _glowController.repeat(reverse: true);

    // Restart timeout
    Future.delayed(widget.searchTimeout, () {
      if (mounted && _isSearching && !_isMatched) {
        _showFailureState();
      }
    });
  }

  void _tryAgain() {
    _closeOverlay();
    // Caller can reshow the overlay or handle retry logic
  }

  void _closeOverlay() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animation based on state
              if (_isMatched)
                _buildSuccessAnimation()
              else if (_isFailed)
                _buildFailureAnimation()
              else
                _buildSearchingAnimation(),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                _isMatched 
                    ? 'Driver Found!' 
                    : _isFailed
                        ? 'No Drivers Available'
                        : 'Finding a driver...',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _isMatched 
                      ? 'Preparing your delivery details'
                      : _isFailed
                          ? 'All drivers are currently busy. You can keep searching or try again later.'
                          : 'Please wait while we match you with the best driver',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action buttons based on state
              if (_isSearching && !_isFailed && !_isMatched)
                TextButton.icon(
                  onPressed: () {
                    widget.onCancel?.call();
                    _closeOverlay();
                  },
                  icon: const Icon(Icons.close, color: Colors.white70),
                  label: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                )
              else if (_isFailed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Keep Searching button
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _keepSearching,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'Keep Searching',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Try Again button
                    OutlinedButton.icon(
                      onPressed: _tryAgain,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingAnimation() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _rotationController, _glowController]),
      builder: (context, child) {
        final pulseValue = Curves.easeInOut.transform(_pulseController.value);
        final glowValue = Curves.easeInOut.transform(_glowController.value);
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring with enhanced glow
            Container(
              width: 220 + (80 * pulseValue),
              height: 220 + (80 * pulseValue),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00F0FF).withOpacity(
                    (0.6 + 0.3 * glowValue) * (1 - pulseValue),
                  ),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F0FF).withOpacity(
                      0.4 * (1 - pulseValue) * glowValue,
                    ),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            // Middle pulse ring
            Container(
              width: 200 + (40 * pulseValue),
              height: 200 + (40 * pulseValue),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(
                    (0.5 + 0.2 * glowValue) * (1 - pulseValue),
                  ),
                  width: 2.5,
                ),
              ),
            ),
            // Inner static ring
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
            // Center circle with rotating icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00F0FF).withOpacity(0.8 + 0.2 * glowValue),
                    AppTheme.primaryBlue.withOpacity(0.9 + 0.1 * glowValue),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F0FF).withOpacity(0.5 + 0.3 * glowValue),
                    blurRadius: 25,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: _rotationController.value * 2 * math.pi,
                child: const Icon(
                  Icons.near_me,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFailureAnimation() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.errorColor.withOpacity(0.2),
        border: Border.all(
          color: AppTheme.errorColor,
          width: 3,
        ),
      ),
      child: const Icon(
        Icons.error_outline,
        size: 64,
        color: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return AnimatedBuilder(
      animation: _successController,
      builder: (context, child) {
        final scale = Curves.elasticOut.transform(_successController.value);
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Burst effect
            if (_successController.value > 0.3)
              ...List.generate(8, (index) {
                final angle = (index / 8) * 2 * math.pi;
                final distance = 80 * (_successController.value - 0.3) / 0.7;
                
                return Transform.translate(
                  offset: Offset(
                    math.cos(angle) * distance,
                    math.sin(angle) * distance,
                  ),
                  child: Opacity(
                    opacity: 1 - ((_successController.value - 0.3) / 0.7),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                );
              }),
            // Success circle
            Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.successColor,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.successColor.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Show driver matching overlay
Future<void> showDriverMatchingOverlay({
  required BuildContext context,
  VoidCallback? onCancel,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) {
      return DriverMatchingOverlay(
        onCancel: onCancel,
        onDriverFound: () {
          // Handled by caller
        },
      );
    },
  );
}
