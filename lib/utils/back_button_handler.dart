import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    
    // Define navigation hierarchy
    if (currentLocation.startsWith('/tracking/')) {
      // From tracking screen, go to home
      context.go('/home');
    } else if (currentLocation == '/matching') {
      // From matching screen, go to home (delivery is created)
      context.go('/home');
    } else if (currentLocation == '/order-summary') {
      // From order summary, go back to location selection
      context.pop();
    } else if (currentLocation == '/location-selection') {
      // From location selection, go back to vehicle selection
      context.pop();
    } else if (currentLocation == '/create-delivery') {
      // From vehicle selection, go to home
      context.go('/home');
    } else if (currentLocation == '/addresses') {
      // From addresses, go to home
      context.go('/home');
    } else if (currentLocation == '/profile') {
      // From profile, go to home
      context.go('/home');
    } else if (currentLocation == '/home') {
      // From home screen, show exit confirmation if enabled
      if (showExitDialog) {
        _showExitConfirmation(context);
      }
    } else if (currentLocation == '/' || currentLocation == '/signup') {
      // From login/signup, exit app
      _exitApp();
    } else {
      // Default: try to pop, or go to home
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  /// Show exit confirmation dialog
  Future<void> _showExitConfirmation(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.orange),
              SizedBox(width: 8),
              Text('Exit SwiftDash?'),
            ],
          ),
          content: const Text(
            'Are you sure you want to exit the app?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      _exitApp();
    }
  }

  /// Exit the application
  void _exitApp() {
    // On Android, this will move the app to background
    // On iOS, this is not allowed and will be ignored
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
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
  /// Navigate to home screen
  void goHome() => go('/home');
  
  /// Navigate to tracking screen
  void goToTracking(String deliveryId) => go('/tracking/$deliveryId');
  
  /// Navigate to create delivery flow
  void goToCreateDelivery() => go('/create-delivery');
  
  /// Navigate to addresses
  void goToAddresses() => go('/addresses');
  
  /// Navigate to profile
  void goToProfile() => go('/profile');
  
  /// Navigate to login
  void goToLogin() => go('/');
  
  /// Safe pop that goes to home if can't pop
  void safePop() {
    if (canPop()) {
      pop();
    } else {
      goHome();
    }
  }
}