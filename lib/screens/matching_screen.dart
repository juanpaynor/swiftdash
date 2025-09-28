import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_theme.dart';
import '../widgets/modern_widgets.dart';
import '../models/delivery.dart';

class MatchingScreen extends StatefulWidget {
  final String deliveryId;
  
  const MatchingScreen({
    super.key,
    required this.deliveryId,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _searchController;
  late AnimationController _progressController;
  
  Delivery? _delivery;
  String _currentMessage = "Looking for available drivers...";
  int _searchStep = 0;
  
  final List<String> _searchMessages = [
    "Looking for available drivers...",
    "Checking driver locations...", 
    "Finding the best match...",
    "Contacting nearby drivers...",
    "Almost there! Finalizing match...",
  ];

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _searchController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _progressController = AnimationController(
      duration: const Duration(seconds: 15), // Total estimated matching time
      vsync: this,
    );
    
    _loadDeliveryDetails();
    _startSearchAnimation();
    _progressController.forward();
    
    // Listen for delivery updates
    _listenForDriverMatch();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startSearchAnimation() {
    // Cycle through search messages
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _searchStep = (_searchStep + 1) % _searchMessages.length;
        _currentMessage = _searchMessages[_searchStep];
      });
      
      // Stop after going through all messages once
      if (_searchStep == _searchMessages.length - 1) {
        timer.cancel();
      }
    });
  }

  Future<void> _loadDeliveryDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('deliveries')
          .select('''
            *,
            vehicle_types (*)
          ''')
          .eq('id', widget.deliveryId)
          .single();
          
      setState(() {
        _delivery = Delivery.fromJson(response);
      });
    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error loading delivery details: $e',
        );
        context.go('/home');
      }
    }
  }

  void _listenForDriverMatch() {
    // Listen for real-time updates on the delivery
    Supabase.instance.client
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('id', widget.deliveryId)
        .listen((data) {
          if (data.isNotEmpty) {
            final delivery = Delivery.fromJson(data.first);
            if (delivery.status != 'pending') {
              // Driver has been matched!
              _onDriverMatched(delivery);
            }
          }
        });
  }

  void _onDriverMatched(Delivery delivery) {
    HapticFeedback.heavyImpact();
    
    // Show success animation then navigate
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildMatchFoundDialog(delivery),
    ).then((_) {
      // Navigate to tracking screen
      context.go('/tracking/${delivery.id}');
    });
  }

  Widget _buildMatchFoundDialog(Delivery delivery) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radius24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowDark,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ).animate().scale(delay: 200.milliseconds),
            
            const SizedBox(height: AppTheme.spacing20),
            
            Text(
              'Driver Found!',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ).animate(delay: 400.milliseconds).fadeIn().slideY(begin: 0.2),
            
            const SizedBox(height: AppTheme.spacing12),
            
            Text(
              'Your driver is on the way to pickup location',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 600.milliseconds).fadeIn().slideY(begin: 0.2),
            
            const SizedBox(height: AppTheme.spacing24),
            
            ModernButton(
              text: 'Track Delivery',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              icon: Icons.location_on_rounded,
            ).animate(delay: 800.milliseconds).fadeIn().slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with cancel option
              _buildHeader(),
              
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacing20),
                  child: Column(
                    children: [
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Animated search indicator
                      _buildSearchIndicator(),
                      
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Status message
                      _buildStatusMessage(),
                      
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Progress indicator
                      _buildProgressIndicator(),
                      
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Delivery summary
                      if (_delivery != null) _buildDeliverySummary(),
                      
                      const SizedBox(height: AppTheme.spacing40),
                      
                      // Tips while waiting
                      _buildWaitingTips(),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing20,
        vertical: AppTheme.spacing16,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: () {
                // Show confirmation dialog
                _showCancelDialog();
              },
            ),
          ),
          
          const SizedBox(width: AppTheme.spacing16),
          
          Expanded(
            child: Text(
              'Finding Your Driver',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: -0.2).fadeIn();
  }

  Widget _buildSearchIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3 * _pulseController.value),
                blurRadius: 40 + (20 * _pulseController.value),
                spreadRadius: 10 * _pulseController.value,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _searchController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _searchController.value * 2 * 3.14159,
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                );
              },
            ),
          ),
        );
      },
    ).animate().scale(delay: 200.milliseconds);
  }

  Widget _buildStatusMessage() {
    return Column(
      children: [
        Text(
          _currentMessage,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn().slideY(begin: 0.2),
        
        const SizedBox(height: AppTheme.spacing12),
        
        Text(
          'This usually takes 1-3 minutes',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ).animate(delay: 200.milliseconds).fadeIn(),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressController.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: AppTheme.spacing12),
        
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            final percentage = (_progressController.value * 100).round();
            return Text(
              '$percentage% Complete',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            );
          },
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildDeliverySummary() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Delivery Request',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Request #${widget.deliveryId.substring(0, 8)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing20),
          const Divider(color: AppTheme.dividerColor),
          const SizedBox(height: AppTheme.spacing16),
          
          _buildLocationRow(
            icon: Icons.radio_button_checked,
            iconColor: AppTheme.successColor,
            label: 'Pickup',
            address: _delivery!.pickupAddress,
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: AppTheme.errorColor,
            label: 'Delivery',
            address: _delivery!.deliveryAddress,
          ),
          
          const SizedBox(height: AppTheme.spacing20),
          const Divider(color: AppTheme.dividerColor),
          const SizedBox(height: AppTheme.spacing16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Price',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '\$${_delivery!.totalPrice.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: AppTheme.spacing8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Text(
            address,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingTips() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppTheme.warningColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                'While You Wait',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          _buildTipItem('📱 You\'ll get notified when a driver accepts'),
          _buildTipItem('🚗 Driver will head to pickup location first'),
          _buildTipItem('📍 You can track the delivery in real-time'),
          _buildTipItem('💬 Contact your driver through the app'),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        title: Text(
          'Cancel Request?',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this delivery request? This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: Text(
              'Keep Waiting',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          ModernButton(
            text: 'Cancel Request',
            onPressed: () async {
              if (context.canPop()) {
                context.pop();
              }
              await _cancelDelivery();
            },
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  Future<void> _cancelDelivery() async {
    try {
      await Supabase.instance.client
          .from('deliveries')
          .update({'status': 'cancelled'})
          .eq('id', widget.deliveryId);
          
      if (mounted) {
        ModernToast.success(
          context: context,
          message: 'Delivery request cancelled',
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(
          context: context,
          message: 'Error cancelling delivery: $e',
        );
      }
    }
  }
}