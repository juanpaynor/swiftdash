import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swiftdash/models/vehicle_type.dart';
import 'package:swiftdash/screens/login_screen.dart';
import 'package:swiftdash/screens/signup_screen.dart';
import 'package:swiftdash/screens/tracking_screen.dart';
import 'package:swiftdash/screens/addresses_screen.dart';
import 'package:swiftdash/screens/location_selection_screen.dart';
import 'package:swiftdash/screens/matching_screen.dart';
import 'package:swiftdash/screens/profile_edit_screen.dart';
import 'package:swiftdash/screens/saved_addresses_screen.dart';
import 'package:swiftdash/screens/scheduled_deliveries_screen.dart';
import 'package:swiftdash/screens/order_history_screen.dart';
import 'package:swiftdash/screens/delivery_completion_screen.dart';
import 'package:swiftdash/screens/delivery_receipt_screen.dart';
import 'package:swiftdash/models/delivery.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    final isLoggingIn = state.uri.toString() == '/' || state.uri.toString() == '/signup';
    
    // If not authenticated and trying to access protected routes, redirect to login
    if (!isAuthenticated && !isLoggingIn) {
      return '/';
    }
    
    // If authenticated and on login/signup, redirect to location selection (new home)
    if (isAuthenticated && isLoggingIn) {
      return '/location-selection';
    }
    
    return null;
  },
  routes: <GoRoute>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/signup',
      builder: (BuildContext context, GoRouterState state) {
        return const SignUpScreen();
      },
    ),
    GoRoute(
      path: '/home',
      redirect: (context, state) {
        // Redirect old home screen to new location selection screen
        return '/location-selection';
      },
    ),
    GoRoute(
      path: '/tracking',
      redirect: (context, state) {
        // Handle legacy tracking links - try to extract deliveryId from query params
        final deliveryId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['deliveryId'];
        if (deliveryId != null && deliveryId.isNotEmpty) {
          return '/tracking/$deliveryId';
        }
        // No deliveryId provided, redirect to location selection
        return '/location-selection';
      },
    ),
    GoRoute(
      path: '/tracking/:deliveryId',
      builder: (BuildContext context, GoRouterState state) {
        final deliveryId = state.pathParameters['deliveryId']!;
        return TrackingScreen(deliveryId: deliveryId);
      },
    ),
    GoRoute(
      path: '/addresses',
      builder: (BuildContext context, GoRouterState state) {
        return const AddressesScreen();
      },
    ),
    GoRoute(
      path: '/create-delivery',
      redirect: (context, state) {
        // Redirect old vehicle selection screen to new location selection screen
        return '/location-selection';
      },
    ),
    GoRoute(
      path: '/location-selection',
      builder: (BuildContext context, GoRouterState state) {
        final vehicleType = state.extra as VehicleType?;
        return LocationSelectionScreen(selectedVehicleType: vehicleType);
      },
    ),
    GoRoute(
      path: '/matching/:deliveryId',
      builder: (BuildContext context, GoRouterState state) {
        final deliveryId = state.pathParameters['deliveryId']!;
        return MatchingScreen(deliveryId: deliveryId);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfileEditScreen();
      },
    ),
    GoRoute(
      path: '/profile-edit',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfileEditScreen();
      },
    ),
    GoRoute(
      path: '/active-deliveries',
      builder: (BuildContext context, GoRouterState state) {
        return const OrderHistoryScreen(); // Show all orders with Active tab
      },
    ),
    GoRoute(
      path: '/saved-addresses',
      builder: (BuildContext context, GoRouterState state) {
        return const SavedAddressesScreen();
      },
    ),
    GoRoute(
      path: '/scheduled-deliveries',
      builder: (BuildContext context, GoRouterState state) {
        return const ScheduledDeliveriesScreen();
      },
    ),
    GoRoute(
      path: '/order-history',
      builder: (BuildContext context, GoRouterState state) {
        return const OrderHistoryScreen();
      },
    ),
    GoRoute(
      path: '/completion',
      builder: (BuildContext context, GoRouterState state) {
        final delivery = state.extra as Delivery;
        return DeliveryCompletionScreen(delivery: delivery);
      },
    ),
    GoRoute(
      path: '/receipt',
      builder: (BuildContext context, GoRouterState state) {
        final delivery = state.extra as Delivery;
        return DeliveryReceiptScreen(delivery: delivery);
      },
    ),
  ],
);
