import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../models/delivery.dart';
import 'modern_widgets.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? _activeDeliveryId;
  String? _activeDeliveryStatus;
  bool _isLoadingActiveDelivery = true;

  @override
  void initState() {
    super.initState();
    _checkForActiveDelivery();
  }

  Future<void> _checkForActiveDelivery() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoadingActiveDelivery = false);
        return;
      }

      // Check for active delivery (any status except completed, cancelled, or failed)
      final response = await Supabase.instance.client
          .from('deliveries')
          .select('id, status')
          .eq('customer_id', user.id)
          .not('status', 'in', '(completed,cancelled,failed)')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _activeDeliveryId = response['id'] as String;
          _activeDeliveryStatus = response['status'] as String;
          _isLoadingActiveDelivery = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingActiveDelivery = false);
      }
    } catch (e) {
      debugPrint('Error checking for active delivery: $e');
      if (mounted) {
        setState(() => _isLoadingActiveDelivery = false);
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
      case 'finding_driver':
        return 'Finding driver...';
      case 'driver_offered':
        return 'Driver found!';
      case 'driver_assigned':
        return 'Driver assigned';
      case 'driver_en_route':
        return 'Driver on the way';
      case 'arrived_at_pickup':
        return 'Driver arrived';
      case 'picked_up':
        return 'Package picked up';
      case 'in_transit':
        return 'In transit';
      case 'arrived_at_dropoff':
        return 'Arriving soon';
      default:
        return 'In progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 
                    user?.email?.split('@')[0] ?? 'User';
    final userEmail = user?.email ?? '';

    return Drawer(
      backgroundColor: AppTheme.backgroundColor,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header
              _buildDrawerHeader(userName, userEmail)
                .animate()
                .fadeIn(duration: 300.milliseconds)
                .slideX(begin: -0.2),
              
              const SizedBox(height: AppTheme.spacing20),
              
              // Menu Items
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                  children: [
                    // ACTIVE DELIVERY (if exists) - Prominent at top
                    if (!_isLoadingActiveDelivery && _activeDeliveryId != null) ...[
                      _buildActiveDeliveryCard(context)
                        .animate()
                        .shimmer(duration: 1500.milliseconds, color: AppTheme.primaryBlue.withOpacity(0.2))
                        .fadeIn(duration: 300.milliseconds),
                      
                      const SizedBox(height: AppTheme.spacing16),
                      
                      // Divider
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.dividerColor.withOpacity(0.0),
                              AppTheme.dividerColor,
                              AppTheme.dividerColor.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacing8),
                    ],
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.history_rounded,
                      title: 'Order History',
                      subtitle: 'View your past deliveries',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/order-history');
                      },
                    ).animate(delay: 50.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.local_shipping_rounded,
                      title: 'Track Order',
                      subtitle: 'Track your active deliveries',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/order-history'); // Go to order history with Active tab
                      },
                    ).animate(delay: 75.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.schedule_rounded,
                      title: 'Scheduled Orders',
                      subtitle: 'View your scheduled deliveries',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/scheduled-deliveries');
                      },
                    ).animate(delay: 100.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.location_on_outlined,
                      title: 'My Addresses',
                      subtitle: 'Manage saved addresses',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/saved-addresses');
                      },
                    ).animate(delay: 125.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.report_problem_outlined,
                      title: 'Report an Issue',
                      subtitle: 'Report a problem with a delivery',
                      onTap: () {
                        Navigator.pop(context);
                        ModernToast.info(
                          context: context,
                          message: 'Issue reporting coming soon!',
                        );
                      },
                    ).animate(delay: 150.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing20),
                    
                    // Divider
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.dividerColor.withOpacity(0.0),
                            AppTheme.dividerColor,
                            AppTheme.dividerColor.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ).animate(delay: 175.milliseconds).scaleX(),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.person_outline_rounded,
                      title: 'View Profile',
                      subtitle: 'View and edit your profile',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/profile-edit');
                      },
                    ).animate(delay: 200.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_outlined,
                      title: 'Account Settings',
                      subtitle: 'Manage your account preferences',
                      onTap: () {
                        Navigator.pop(context);
                        _showAccountSettings(context);
                      },
                    ).animate(delay: 225.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing20),
                    
                    // Divider
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.dividerColor.withOpacity(0.0),
                            AppTheme.dividerColor,
                            AppTheme.dividerColor.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ).animate(delay: 250.milliseconds).scaleX(),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      subtitle: 'Sign out of your account',
                      isDestructive: true,
                      onTap: () => _showSignOutConfirmation(context),
                    ).animate(delay: 275.milliseconds).slideX(begin: -0.2).fadeIn(),
                  ],
                ),
              ),
              
              // App Version Footer
              _buildVersionFooter()
                .animate(delay: 500.milliseconds)
                .fadeIn()
                .slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDeliveryCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
            context.go('/tracking/$_activeDeliveryId');
          },
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Delivery',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getStatusText(_activeDeliveryStatus!),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.track_changes_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to track delivery',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(String userName, String userEmail) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacing16),
          
          // User Name
          Text(
            userName,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // User Email
          Text(
            userEmail,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(
              color: AppTheme.dividerColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDestructive 
                      ? AppTheme.errorLight
                      : AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive 
                      ? AppTheme.errorColor
                      : AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacing16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive 
                            ? AppTheme.errorColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionFooter() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing12,
                  vertical: AppTheme.spacing6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      color: AppTheme.primaryBlue,
                      size: 16,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      'SwiftDash',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Version 1.0.0',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
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
                  Icons.logout_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                'Sign Out',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out of your account?',
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
                'Cancel',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                
                // Close dialog first
                Navigator.of(context).pop();
                
                // Close drawer (go back from drawer)
                Navigator.of(context).pop();
                
                try {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    // Navigate to login
                    context.go('/');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ModernToast.error(
                      context: context,
                      message: 'Error signing out: $e',
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
                'Sign Out',
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

  void _showAccountSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radius28),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing20),
              child: Row(
                children: [
                  Text(
                    'Account Settings',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            
            // Settings options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
                children: [
                  _buildSettingsItem(
                    context,
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage push notifications',
                    onTap: () {
                      ModernToast.info(
                        context: context,
                        message: 'Notification settings coming soon!',
                      );
                    },
                  ),
                  
                  _buildSettingsItem(
                    context,
                    icon: Icons.security_outlined,
                    title: 'Privacy & Security',
                    subtitle: 'Manage your privacy settings',
                    onTap: () {
                      ModernToast.info(
                        context: context,
                        message: 'Privacy settings coming soon!',
                      );
                    },
                  ),
                  
                  _buildSettingsItem(
                    context,
                    icon: Icons.language_outlined,
                    title: 'Language',
                    subtitle: 'English (Philippines)',
                    onTap: () {
                      ModernToast.info(
                        context: context,
                        message: 'Language selection coming soon!',
                      );
                    },
                  ),
                  
                  _buildSettingsItem(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'Get help and contact support',
                    onTap: () {
                      ModernToast.info(
                        context: context,
                        message: 'Support chat coming soon!',
                      );
                    },
                  ),
                  
                  _buildSettingsItem(
                    context,
                    icon: Icons.info_outline_rounded,
                    title: 'About SwiftDash',
                    subtitle: 'Version 1.0.0',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'SwiftDash',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2025 SwiftDash. All rights reserved.',
                        children: [
                          const Text('Lightning Fast • Ultra Reliable\nPremium Delivery Experience'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryBlue,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textTertiary,
        size: 20,
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}