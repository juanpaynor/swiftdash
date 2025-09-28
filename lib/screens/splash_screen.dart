import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../constants/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const SplashScreen({required this.onComplete, super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    await _controller.forward();
    _pulseController.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
              Color(0xFFF093FB),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top spacer
              const Spacer(flex: 2),
              
              // Main logo and branding section
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          // Animated logo with pulsing effect
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFFFFF),
                                        Color(0xFFF8FAFC),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(35),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 30,
                                        offset: const Offset(0, 15),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.8),
                                        blurRadius: 10,
                                        offset: const Offset(0, -5),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.delivery_dining_rounded,
                                    size: 70,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // App name with gradient text effect
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFFE5E7EB)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: Text(
                              'SwiftDash',
                              style: GoogleFonts.inter(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1.2,
                                height: 1.0,
                              ),
                            ),
                          )
                            .animate(delay: 600.milliseconds)
                            .fadeIn(duration: 800.milliseconds)
                            .slideY(begin: 0.3, end: 0.0)
                            .then(delay: 200.milliseconds)
                            .shimmer(
                              duration: 2000.milliseconds,
                              colors: [
                                Colors.white.withOpacity(0.6),
                                Colors.white,
                                Colors.white.withOpacity(0.6),
                              ],
                            ),
                          
                          const SizedBox(height: 12),
                          
                          // Tagline with typewriter effect
                          Text(
                            'Lightning Fast • Ultra Reliable',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 0.5,
                            ),
                          )
                            .animate(delay: 1000.milliseconds)
                            .fadeIn(duration: 600.milliseconds)
                            .slideY(begin: 0.2, end: 0.0),
                          
                          const SizedBox(height: 8),
                          
                          // Subtitle
                          Text(
                            'Premium Delivery Experience',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 0.2,
                            ),
                          )
                            .animate(delay: 1200.milliseconds)
                            .fadeIn(duration: 600.milliseconds)
                            .slideY(begin: 0.2, end: 0.0),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const Spacer(flex: 2),
              
              // Bottom loading section
              Column(
                children: [
                  // Loading animation with dots
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      children: [
                        // Outer ring
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.3),
                            ),
                            strokeWidth: 2,
                          ),
                        ),
                        // Inner ring with animation
                        Center(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 3,
                            ).animate(onPlay: (controller) => controller.repeat())
                              .rotate(duration: 2000.milliseconds),
                          ),
                        ),
                      ],
                    ),
                  )
                    .animate(delay: 1400.milliseconds)
                    .fadeIn(duration: 400.milliseconds)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0)),
                  
                  const SizedBox(height: 20),
                  
                  // Loading text
                  Text(
                    'Preparing your experience...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 0.3,
                    ),
                  )
                    .animate(delay: 1600.milliseconds)
                    .fadeIn(duration: 400.milliseconds)
                    .slideY(begin: 0.2, end: 0.0),
                ],
              ),
              
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}