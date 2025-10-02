import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../constants/app_theme.dart';
import '../widgets/modern_widgets.dart';
import '../widgets/app_drawer.dart';
import '../services/delivery_service.dart';
import '../models/delivery.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  final PageController _pageController = PageController();
  int _currentPromoIndex = 0;
  
  List<Delivery> _recentDeliveries = [];
  bool _isLoadingDeliveries = true;
  RealtimeChannel? _deliveriesChannel;
  StreamSubscription<List<Map<String, dynamic>>>? _deliveriesSub;
  
  // Add GlobalKey for Scaffold to properly control drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AppTheme.animationMedium,
      vsync: this,
    );
    _slideController = AnimationController(
      duration: AppTheme.animationSlow,
      vsync: this,
    );
    
    _fadeController.forward();
    _slideController.forward();
    _loadRecentDeliveries();
    // _testEdgeFunctions(); // Commented out - functions not deployed yet

    // Subscribe to realtime updates for the current user's deliveries
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      _deliveriesChannel = Supabase.instance.client
          .channel('public:deliveries_user_${currentUser.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deliveries',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_id',
              value: currentUser.id,
            ),
            callback: (payload) async {
              if (mounted) {
                await _loadRecentDeliveries();
              }
            },
          )
          .subscribe();
    }

    // Subscribe to realtime updates so the recent deliveries section refreshes instantly
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _deliveriesSub = Supabase.instance.client
          .from('deliveries')
          .stream(primaryKey: ['id'])
          .eq('customer_id', user.id)
          .listen((event) {
        // Any insert/update/delete triggers a refresh
        _loadRecentDeliveries();
      });
    }
  }

  Future<void> _loadRecentDeliveries() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final deliveries = await DeliveryService.getUserDeliveries(user.id, excludeCancelled: true);
        setState(() {
          _recentDeliveries = deliveries.take(3).toList(); // Show only latest 3
          _isLoadingDeliveries = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingDeliveries = false;
      });
    }
  }

  @override
  void dispose() {
    try { _deliveriesChannel?.unsubscribe(); } catch (_) {}
    _fadeController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    _deliveriesSub?.cancel();
    _deliveriesSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 
                    user?.email?.split('@')[0] ?? 'User';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Custom App Bar
            SliverToBoxAdapter(
              child: _buildHeader(userName),
            ),
            
            // Promo Cards Carousel
            SliverToBoxAdapter(
              child: _buildPromoCarousel(),
            ),
            
            // Quick Actions Grid
            SliverToBoxAdapter(
              child: _buildQuickActions(),
            ),
            
            // Recent Activity Section
            SliverToBoxAdapter(
              child: _buildRecentActivity(),
            ),
            
            // Features Section
            SliverToBoxAdapter(
              child: _buildFeaturesGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: ModernFAB(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.go('/create-delivery');
        },
        icon: Icons.add_rounded,
        heroTag: "home_fab",
      ).animate().scale(delay: 800.milliseconds),
    );
  }

  Widget _buildHeader(String userName) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Menu Button (for drawer)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _scaffoldKey.currentState?.openDrawer();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.shadowLight,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                ),
              ).animate().scale(delay: 200.milliseconds),
              
              const SizedBox(width: AppTheme.spacing16),
              
              // Welcome Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      userName,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.milliseconds).slideX(begin: 0.2),
              
              // Notification Button Only
              _buildHeaderButton(Icons.notifications_none_rounded, () {
                ModernToast.info(
                  context: context,
                  message: 'No new notifications',
                );
              }).animate().fadeIn(delay: 400.milliseconds),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing24),
          
          // Search Bar
          GestureDetector(
            onTap: () {
              ModernToast.info(
                context: context,
                message: 'Search feature coming soon!',
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
                vertical: AppTheme.spacing16,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radius16),
                border: Border.all(
                  color: AppTheme.dividerColor.withOpacity(0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadowLight,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: AppTheme.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    'Search for deliveries, addresses...',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 500.milliseconds).slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: AppTheme.dividerColor.withOpacity(0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowLight,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: AppTheme.textSecondary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildPromoCarousel() {
    final promoData = [
      {
        'title': 'Track Live',
        'subtitle': 'Real-time updates',
        'gradient': const LinearGradient(
          colors: [Color(0xFF00D2D3), Color(0xFF54A0FF)],
        ),
        'icon': Icons.location_on_rounded,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
      height: 160,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPromoIndex = index;
                });
              },
              itemCount: promoData.length,
              itemBuilder: (context, index) {
                final promo = promoData[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
                  decoration: BoxDecoration(
                    gradient: promo['gradient'] as LinearGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radius20),
                    boxShadow: [
                      BoxShadow(
                        color: (promo['gradient'] as LinearGradient).colors.first.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                promo['title'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                promo['subtitle'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radius16),
                          ),
                          child: Icon(
                            promo['icon'] as IconData,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Page indicators
          const SizedBox(height: AppTheme.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              promoData.length,
              (index) => Container(
                width: index == _currentPromoIndex ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: index == _currentPromoIndex 
                      ? AppTheme.primaryBlue 
                      : AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 600.milliseconds),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Request Delivery',
                  Icons.local_shipping_rounded,
                  AppTheme.primaryGradient,
                  () {
                    HapticFeedback.mediumImpact();
                    context.go('/create-delivery');
                  },
                ).animate().slideX(delay: 700.milliseconds, begin: -0.2),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: _buildQuickActionCard(
                  'Track Order',
                  Icons.location_on_rounded,
                  const LinearGradient(
                    colors: [Color(0xFF00D2D3), Color(0xFF54A0FF)],
                  ),
                  () {
                    HapticFeedback.lightImpact();
                    context.go('/tracking');
                  },
                ).animate().slideX(delay: 750.milliseconds, begin: 0.2),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing12),
          
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'My Addresses',
                  Icons.location_city_rounded,
                  AppTheme.primaryGradient, // Changed from red to blue gradient
                  () {
                    HapticFeedback.lightImpact();
                    context.go('/addresses');
                  },
                ).animate().slideX(delay: 800.milliseconds, begin: -0.2),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: _buildQuickActionCard(
                  'Order History',
                  Icons.history_rounded,
                  const LinearGradient(
                    colors: [Color(0xFF4834D4), Color(0xFF667EEA)],
                  ),
                  () {
                    ModernToast.info(
                      context: context,
                      message: 'Order history coming soon!',
                    );
                  },
                ).animate().slideX(delay: 850.milliseconds, begin: 0.2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              TextButton(
                onPressed: () {
                  ModernToast.info(
                    context: context,
                    message: 'Order history coming soon!',
                  );
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          if (_isLoadingDeliveries)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppTheme.spacing20),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                ),
              ),
            )
          else if (_recentDeliveries.isEmpty)
            ModernCard(
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.infoLight,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: AppTheme.infoColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No recent deliveries',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your delivery history will appear here',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 900.milliseconds).slideY(begin: 0.2)
          else
            Column(
              children: _recentDeliveries.asMap().entries.map((entry) {
                final index = entry.key;
                final delivery = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < _recentDeliveries.length - 1 ? AppTheme.spacing12 : 0),
                  child: _buildDeliveryCard(delivery),
                ).animate(delay: (900 + index * 100).milliseconds).fadeIn().slideY(begin: 0.2);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why Choose SwiftDash?',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  'Real-time Tracking',
                  Icons.my_location_rounded,
                  AppTheme.successColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: _buildFeatureCard(
                  'Secure Payments',
                  Icons.security_rounded,
                  AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing12),
          
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  '24/7 Support',
                  Icons.headset_mic_rounded,
                  AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: _buildFeatureCard(
                  'Fast Delivery',
                  Icons.speed_rounded,
                  AppTheme.accentCyan,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacing40),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: AppTheme.dividerColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1000.milliseconds).slideY(begin: 0.2);
  }

  Widget _buildDeliveryCard(Delivery delivery) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (delivery.status) {
      case 'pending':
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.schedule_rounded;
        statusText = 'Finding Driver';
        break;
      case 'accepted':
        statusColor = AppTheme.infoColor;
        statusIcon = Icons.person_rounded;
        statusText = 'Driver Assigned';
        break;
      case 'picked_up':
        statusColor = AppTheme.primaryBlue;
        statusIcon = Icons.local_shipping_rounded;
        statusText = 'On the Way';
        break;
      case 'delivered':
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle_rounded;
        statusText = 'Delivered';
        break;
      case 'cancelled':
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel_rounded;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = AppTheme.textTertiary;
        statusIcon = Icons.help_rounded;
        statusText = delivery.status;
    }

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Delivery #${delivery.id.substring(0, 8).toUpperCase()}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing8,
                            vertical: AppTheme.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radius8),
                          ),
                          child: Text(
                            statusText,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${delivery.pickupAddress} → ${delivery.deliveryAddress}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateTime(delivery.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textTertiary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '₱${delivery.totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successColor,
                    ),
                  ),
                  if (delivery.status == 'pending')
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.spacing8),
                      child: GestureDetector(
                        onTap: () => _showCancelDeliveryDialog(delivery),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacing4),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(AppTheme.radius4),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    )
                  else if (delivery.status == 'delivered' || delivery.status == 'cancelled')
                    Padding(
                      padding: const EdgeInsets.only(left: AppTheme.spacing8),
                      child: GestureDetector(
                        onTap: () => _showDeleteDeliveryDialog(delivery),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacing4),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(AppTheme.radius4),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showCancelDeliveryDialog(Delivery delivery) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius20),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                'Cancel Delivery',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to cancel this delivery? This action cannot be undone.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Keep Delivery',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  await DeliveryService.cancelDelivery(delivery.id);
                  
                  if (mounted) {
                    HapticFeedback.mediumImpact();
                    ModernToast.success(
                      context: context,
                      message: 'Delivery cancelled successfully',
                    );
                    // Force immediate UI refresh by removing the item from the list
                    setState(() {
                      _recentDeliveries.removeWhere((d) => d.id == delivery.id);
                    });
                    // Also refresh from database to ensure consistency
                    await _loadRecentDeliveries();
                  }
                } catch (e) {
                  if (mounted) {
                    ModernToast.error(
                      context: context,
                      message: 'Error cancelling delivery: $e',
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              child: Text(
                'Cancel Delivery',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDeliveryDialog(Delivery delivery) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius20),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                'Delete Delivery',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to permanently delete this delivery record? This action cannot be undone.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Keep Record',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                try {
                  await DeliveryService.deleteDelivery(delivery.id);
                  
                  if (mounted) {
                    HapticFeedback.mediumImpact();
                    ModernToast.success(
                      context: context,
                      message: 'Delivery record deleted successfully',
                    );
                    // Force immediate UI refresh by removing the item from the list
                    setState(() {
                      _recentDeliveries.removeWhere((d) => d.id == delivery.id);
                    });
                    // Also refresh from database to ensure consistency
                    await _loadRecentDeliveries();
                  }
                } catch (e) {
                  if (mounted) {
                    ModernToast.error(
                      context: context,
                      message: 'Error deleting delivery: $e',
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              child: Text(
                'Delete Permanently',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
