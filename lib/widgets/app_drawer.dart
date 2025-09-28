import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import 'modern_widgets.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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
                    _buildMenuItem(
                      context,
                      icon: Icons.person_outline_rounded,
                      title: 'Edit Profile',
                      subtitle: 'Update your information',
                      onTap: () {
                        Navigator.pop(context);
                        ModernToast.info(
                          context: context,
                          message: 'Profile editing coming soon!',
                        );
                      },
                    ).animate(delay: 100.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.history_rounded,
                      title: 'Order History',
                      subtitle: 'View past deliveries',
                      onTap: () {
                        Navigator.pop(context);
                        ModernToast.info(
                          context: context,
                          message: 'Order history coming soon!',
                        );
                      },
                    ).animate(delay: 150.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.location_on_outlined,
                      title: 'Saved Addresses',
                      subtitle: 'Manage your addresses',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/addresses');
                      },
                    ).animate(delay: 200.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.payment_outlined,
                      title: 'Payment Methods',
                      subtitle: 'Manage payment options',
                      onTap: () {
                        Navigator.pop(context);
                        ModernToast.info(
                          context: context,
                          message: 'Payment settings coming soon!',
                        );
                      },
                    ).animate(delay: 250.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Manage notifications',
                      onTap: () {
                        Navigator.pop(context);
                        ModernToast.info(
                          context: context,
                          message: 'Notification settings coming soon!',
                        );
                      },
                    ).animate(delay: 300.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
                    const SizedBox(height: AppTheme.spacing8),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      subtitle: 'Get help with your orders',
                      onTap: () {
                        Navigator.pop(context);
                        ModernToast.info(
                          context: context,
                          message: 'Support chat coming soon!',
                        );
                      },
                    ).animate(delay: 350.milliseconds).slideX(begin: -0.2).fadeIn(),
                    
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
                    ).animate(delay: 400.milliseconds).scaleX(),
                    
                    _buildMenuItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Sign Out',
                      subtitle: 'Sign out of your account',
                      isDestructive: true,
                      onTap: () => _showSignOutConfirmation(context),
                    ).animate(delay: 450.milliseconds).slideX(begin: -0.2).fadeIn(),
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
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Close drawer
                
                HapticFeedback.mediumImpact();
                
                try {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    context.go('/');
                    ModernToast.success(
                      context: context,
                      message: 'Signed out successfully',
                    );
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
}