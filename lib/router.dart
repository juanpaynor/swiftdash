import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/models/vehicle_type.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/login_screen.dart';
import 'package:myapp/screens/signup_screen.dart';
import 'package:myapp/screens/tracking_screen.dart';
import 'package:myapp/screens/addresses_screen.dart';
import 'package:myapp/screens/vehicle_selection_screen.dart';
import 'package:myapp/screens/location_selection_screen.dart';
import 'package:myapp/screens/order_summary_screen.dart';
import 'package:myapp/screens/matching_screen.dart';
import 'package:myapp/screens/profile_edit_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;
    final isLoggingIn = state.uri.toString() == '/' || state.uri.toString() == '/signup';
    
    // If not authenticated and trying to access protected routes, redirect to login
    if (!isAuthenticated && !isLoggingIn) {
      return '/';
    }
    
    // If authenticated and on login/signup, redirect to home
    if (isAuthenticated && isLoggingIn) {
      return '/home';
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
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: '/tracking',
      builder: (BuildContext context, GoRouterState state) {
        return const TrackingScreen();
      },
    ),
    GoRoute(
      path: '/tracking/:deliveryId',
      builder: (BuildContext context, GoRouterState state) {
        // For now, just redirect to general tracking screen
        // TODO: Create a specific delivery tracking screen
        return const TrackingScreen();
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
      builder: (BuildContext context, GoRouterState state) {
        return const VehicleSelectionScreen();
      },
    ),
    GoRoute(
      path: '/location-selection',
      builder: (BuildContext context, GoRouterState state) {
        final vehicleType = state.extra as VehicleType;
        return LocationSelectionScreen(selectedVehicleType: vehicleType);
      },
    ),
    GoRoute(
      path: '/order-summary',
      builder: (BuildContext context, GoRouterState state) {
        final orderData = state.extra as Map<String, dynamic>;
        return OrderSummaryScreen(orderData: orderData);
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
  ],
);
