import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../constants/modern_colors.dart';

/// Modern clean navigation bar for tracking screen
class ModernTopNavigationBar extends StatelessWidget {
  final String orderNumber;
  final VoidCallback? onBackPressed;
  final VoidCallback? onHelpPressed;
  final Widget? customTitle;
  final List<Widget>? additionalActions;

  const ModernTopNavigationBar({
    Key? key,
    required this.orderNumber,
    this.onBackPressed,
    this.onHelpPressed,
    this.customTitle,
    this.additionalActions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: ModernColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernShadows.medium,
      ),
      child: Row(
        children: [
          // Back button
          _buildNavigationButton(
            icon: Icons.arrow_back_ios,
            onPressed: onBackPressed ?? () => context.go('/home'),
          ),
          
          const SizedBox(width: 16),
          
          // Title section
          Expanded(
            child: customTitle ?? _buildDefaultTitle(),
          ),
          
          // Additional actions
          if (additionalActions != null) ...[
            const SizedBox(width: 12),
            ...additionalActions!.map((action) => 
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: action,
              )
            ),
          ],
          
          // Help button
          const SizedBox(width: 16),
          _buildNavigationButton(
            icon: Icons.help_outline,
            onPressed: onHelpPressed ?? () => _showHelpDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultTitle() {
    return Text(
      'Order #${_formatOrderNumber(orderNumber)}',
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ModernColors.darkGrey,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ModernColors.accentBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: ModernColors.darkGrey,
          size: 18,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  String _formatOrderNumber(String orderNumber) {
    // Take first 8 characters and make uppercase
    return orderNumber.length > 8 
        ? orderNumber.substring(0, 8).toUpperCase()
        : orderNumber.toUpperCase();
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Need Help?',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ModernColors.darkGrey,
          ),
        ),
        content: Text(
          'Contact our support team for assistance with your delivery.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: ModernColors.mediumGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: ModernColors.mediumGrey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement contact support
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Contact Support',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact floating header for minimal space usage
class CompactFloatingHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final Widget? trailing;

  const CompactFloatingHeader({
    Key? key,
    required this.title,
    this.onBackPressed,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ModernColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: ModernShadows.small,
      ),
      child: Row(
        children: [
          // Back button
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ModernColors.accentBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: ModernColors.darkGrey,
                size: 14,
              ),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Title
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ModernColors.darkGrey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Trailing widget
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Status indicator chip for navigation bar
class StatusIndicatorChip extends StatelessWidget {
  final String status;
  final Color? color;
  final IconData? icon;

  const StatusIndicatorChip({
    Key? key,
    required this.status,
    this.color,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? ModernColors.primaryBlue;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: effectiveColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: effectiveColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button for navigation bar
class NavigationActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool isActive;

  const NavigationActionButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? ModernColors.primaryBlue;
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? effectiveColor : ModernColors.accentBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive ? ModernShadows.small : null,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isActive ? Colors.white : ModernColors.darkGrey,
          size: 18,
        ),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}