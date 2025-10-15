import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swiftdash/models/vehicle_type.dart';
import 'package:swiftdash/screens/home_screen.dart';
import 'package:swiftdash/screens/login_screen.dart';
import 'package:swiftdash/screens/signup_screen.dart';
import 'package:swiftdash/screens/tracking_screen.dart';
import 'package:swiftdash/screens/addresses_screen.dart';
import 'package:swiftdash/screens/vehicle_selection_screen.dart';
import 'package:swiftdash/screens/location_selection_screen.dart';
import 'package:swiftdash/screens/delivery_contacts_screen.dart';
import 'package:swiftdash/screens/order_summary_screen.dart';
import 'package:swiftdash/screens/matching_screen.dart';
import 'package:swiftdash/screens/profile_edit_screen.dart';
import 'package:swiftdash/screens/saved_addresses_screen.dart';
import 'package:swiftdash/screens/scheduled_deliveries_screen.dart';

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
      redirect: (context, state) {
        // General tracking route should redirect to home since it needs a deliveryId
        return '/home';
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
      path: '/delivery-contacts',
      builder: (BuildContext context, GoRouterState state) {
        final data = state.extra as Map<String, dynamic>;
        return DeliveryContactsScreen(
          selectedVehicleType: data['selectedVehicleType'] as VehicleType,
          locationData: data['locationData'] as Map<String, dynamic>,
        );
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
  ],
);
