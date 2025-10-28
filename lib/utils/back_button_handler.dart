import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Smart back button handler that prevents accidental app exits
/// and provides better navigation flow
class SmartBackHandler extends StatelessWidget {
  final Widget child;
  final String? currentRoute;
  final VoidCallback? onWillPop;
  final bool showExitDialog;

  const SmartBackHandler({
    super.key,
    required this.child,
    this.currentRoute,
    this.onWillPop,
    this.showExitDialog = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Execute custom callback if provided
        if (onWillPop != null) {
          onWillPop!();
          return;
        }

        // Handle back navigation based on current route
        await _handleBackNavigation(context);
      },
      child: child,
    );
  }

  /// Handle back navigation with smart routing
  Future<void> _handleBackNavigation(BuildContext context) async {
    final currentLocation = GoRouterState.of(context).uri.toString();
    
    // Define navigation hierarchy - NEVER exit the app
    if (currentLocation.startsWith('/tracking/')) {
      // From tracking screen, go to location selection
      context.go('/location-selection');
    } else if (currentLocation == '/matching') {
      // From matching screen, go to location selection (delivery is created)
      context.go('/location-selection');
    } else if (currentLocation == '/order-summary') {
      // From order summary, go back to location selection
      context.pop();
    } else if (currentLocation == '/location-selection') {
      // From location selection (home), DO NOT EXIT - just stay here
      // User can use app drawer to navigate elsewhere or press back again (stays on same screen)
      return;
    } else if (currentLocation == '/addresses') {
      // From addresses, go to location selection
      context.go('/location-selection');
    } else if (currentLocation == '/profile') {
      // From profile, go to location selection
      context.go('/location-selection');
    } else if (currentLocation == '/order-history') {
      // From order history, go to location selection
      context.go('/location-selection');
    } else if (currentLocation == '/saved-addresses') {
      // From saved addresses, go to location selection
      context.go('/location-selection');
    } else if (currentLocation == '/scheduled-deliveries') {
      // From scheduled deliveries, go to location selection
      context.go('/location-selection');
    } else if (currentLocation == '/home' || currentLocation == '/create-delivery') {
      // Redirect old routes to location selection
      context.go('/location-selection');
    } else if (currentLocation == '/' || currentLocation == '/signup') {
      // From login/signup, go to location selection (if somehow user pressed back)
      context.go('/location-selection');
    } else {
      // Default: try to pop, or go to location selection
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/location-selection');
      }
    }
  }


}

/// Mixin for screens that need custom back button handling
mixin BackButtonHandlerMixin<T extends StatefulWidget> on State<T> {
  bool _isHandlingBack = false;

  /// Override this method to provide custom back button behavior
  Future<bool> onWillPop() async {
    return true; // Allow back navigation by default
  }

  /// Call this in your screen's build method to wrap it with back handling
  Widget buildWithBackHandler(Widget child, {bool showExitDialog = false}) {
    return SmartBackHandler(
      showExitDialog: showExitDialog,
      onWillPop: _handleBackButton,
      child: child,
    );
  }

  /// Internal back button handler
  void _handleBackButton() async {
    if (_isHandlingBack) return;
    
    _isHandlingBack = true;
    try {
      final shouldPop = await onWillPop();
      if (shouldPop && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      _isHandlingBack = false;
    }
  }
}

/// Extension to make GoRouter navigation more convenient
extension GoRouterExtension on BuildContext {
  /// Navigate to location selection screen (new home)
  void goHome() => go('/location-selection');
  
  /// Navigate to tracking screen
  void goToTracking(String deliveryId) => go('/tracking/$deliveryId');
  
  /// Navigate to create delivery flow (redirects to location selection)
  void goToCreateDelivery() => go('/location-selection');
  
  /// Navigate to addresses
  void goToAddresses() => go('/addresses');
  
  /// Navigate to profile
  void goToProfile() => go('/profile');
  
  /// Navigate to login
  void goToLogin() => go('/');
  
  /// Safe pop that goes to location selection if can't pop
  void safePop() {
    if (canPop()) {
      pop();
    } else {
      go('/location-selection');
    }
  }
}