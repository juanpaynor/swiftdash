import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';

/// Global app state provider for user authentication and core data
/// Manages user session, profile, and app-wide state
class AppStateProvider extends ChangeNotifier {
  // Private state
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Getters
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;

  /// Initialize the provider and listen to auth changes
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);
    
    try {
      // Get current user
      _currentUser = Supabase.instance.client.auth.currentUser;
      
      // Load user profile if authenticated
      if (_currentUser != null) {
        await _loadUserProfile();
      }

      // Listen to auth state changes
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        _handleAuthStateChange(data.session?.user, data.event);
      });

      _isInitialized = true;
    } catch (e) {
      _setError('Failed to initialize app: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Handle authentication state changes
  void _handleAuthStateChange(User? user, AuthChangeEvent event) {
    _currentUser = user;
    
    switch (event) {
      case AuthChangeEvent.signedIn:
        _loadUserProfile();
        _clearError();
        break;
      case AuthChangeEvent.signedOut:
        _userProfile = null;
        _clearError();
        break;
      case AuthChangeEvent.userUpdated:
        if (_currentUser != null) {
          _loadUserProfile();
        }
        break;
      default:
        break;
    }
    
    notifyListeners();
  }

  /// Load user profile data
  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;

    try {
      _userProfile = await AuthService.getUserProfile(_currentUser!.id);
    } catch (e) {
      debugPrint('Failed to load user profile: $e');
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await AuthService.signOut();
      // Auth state change listener will handle cleanup
    } catch (e) {
      _setError('Failed to sign out: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) return;

    _setLoading(true);
    try {
      // Update profile in database
      await Supabase.instance.client
          .from('user_profiles')
          .update(updates)
          .eq('id', _currentUser!.id);

      // Reload profile
      await _loadUserProfile();
      _clearError();
    } catch (e) {
      _setError('Failed to update profile: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Utility methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Provider for home screen state management
class HomeStateProvider extends ChangeNotifier {
  List<Delivery> _recentDeliveries = [];
  bool _isLoadingDeliveries = false;
  String? _deliveryError;
  
  // Getters
  List<Delivery> get recentDeliveries => _recentDeliveries;
  bool get isLoadingDeliveries => _isLoadingDeliveries;
  String? get deliveryError => _deliveryError;

  /// Load recent deliveries for current user
  Future<void> loadRecentDeliveries() async {
    if (_isLoadingDeliveries) return; // Prevent multiple simultaneous calls

    _isLoadingDeliveries = true;
    _deliveryError = null;
    notifyListeners();

    try {
      // Get current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final deliveries = await DeliveryService.getUserDeliveries(currentUser.id, excludeCancelled: true);
        _recentDeliveries = deliveries.take(3).toList(); // Keep only latest 3
      }
    } catch (e) {
      _deliveryError = 'Failed to load deliveries: $e';
      debugPrint(_deliveryError);
    } finally {
      _isLoadingDeliveries = false;
      notifyListeners();
    }
  }

  /// Add new delivery to recent list
  void addDelivery(Delivery delivery) {
    _recentDeliveries.insert(0, delivery);
    // Keep only latest 3
    if (_recentDeliveries.length > 3) {
      _recentDeliveries = _recentDeliveries.take(3).toList();
    }
    notifyListeners();
  }

  /// Update delivery status
  void updateDelivery(Delivery updatedDelivery) {
    final index = _recentDeliveries.indexWhere((d) => d.id == updatedDelivery.id);
    if (index != -1) {
      _recentDeliveries[index] = updatedDelivery;
      notifyListeners();
    }
  }

  /// Clear deliveries
  void clearDeliveries() {
    _recentDeliveries.clear();
    notifyListeners();
  }
}