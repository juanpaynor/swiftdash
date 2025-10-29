import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Google Sign-In Service for SwiftDash
/// 
/// Handles native Google authentication for iOS and Android
/// Uses google_sign_in package to obtain ID token and access token
/// Then exchanges these with Supabase Auth for session creation
class GoogleAuthService {
  /// Web Client ID (OAuth 2.0 Web Application)
  /// Used for server-side token exchange with Supabase
  static const String _webClientId = '124714116903-5edl11iqfqf638eqd2f3kj4njk9vmp4b.apps.googleusercontent.com';
  
  /// iOS Client ID (OAuth 2.0 iOS Application)
  /// TODO: Create iOS OAuth client when building for iOS
  /// For now using web client ID as fallback
  static const String _iosClientId = '124714116903-5edl11iqfqf638eqd2f3kj4njk9vmp4b.apps.googleusercontent.com';
  
  /// Android uses the SHA-1 fingerprint, no client ID needed in code
  /// Just the web client ID is sufficient for Android
  
  /// Scopes required for Supabase authentication
  /// - email: Access to user's email address
  /// - profile: Access to user's basic profile info (name, picture)
  static const List<String> _scopes = ['email', 'profile'];
  
  /// GoogleSignIn instance
  late final GoogleSignIn _googleSignIn;
  
  /// Initialize the Google Sign-In service
  GoogleAuthService() {
    _googleSignIn = GoogleSignIn(
      // Server client ID is the Web Client ID from Google Cloud Console
      serverClientId: _webClientId,
      // Client ID for iOS (not used on Android)
      clientId: defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
      scopes: _scopes,
    );
  }
  
  /// Sign in with Google (native flow)
  /// 
  /// Steps:
  /// 1. Initialize GoogleSignIn with client IDs
  /// 2. Attempt lightweight authentication (or full auth if needed)
  /// 3. Request authorization with required scopes
  /// 4. Extract ID token and access token
  /// 5. Exchange tokens with Supabase Auth
  /// 
  /// Returns the Supabase AuthResponse on success
  /// Throws AuthException on failure
  Future<AuthResponse> signInWithGoogle() async {
    try {
      debugPrint('🔐 Starting Google Sign-In flow...');
      
      // Step 1: Attempt lightweight authentication
      // This uses cached credentials if available
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      
      // If silent sign-in fails, show the Google Sign-In UI
      if (googleUser == null) {
        debugPrint('📱 Showing Google Sign-In UI...');
        googleUser = await _googleSignIn.signIn();
      }
      
      if (googleUser == null) {
        debugPrint('❌ User cancelled Google Sign-In');
        throw const AuthException('User cancelled Google Sign-In');
      }
      
      debugPrint('✅ Google account selected: ${googleUser.email}');
      
      // Step 2: Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Step 3: Extract tokens
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      
      if (idToken == null) {
        debugPrint('❌ No ID Token found');
        throw const AuthException('No ID Token found from Google');
      }
      
      if (accessToken == null) {
        debugPrint('❌ No Access Token found');
        throw const AuthException('No Access Token found from Google');
      }
      
      debugPrint('🎫 ID Token obtained: ${idToken.substring(0, 20)}...');
      debugPrint('🔑 Access Token obtained: ${accessToken.substring(0, 20)}...');
      
      // Step 4: Sign in to Supabase with Google tokens
      debugPrint('🚀 Exchanging tokens with Supabase...');
      final AuthResponse response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      debugPrint('✅ Supabase authentication successful!');
      debugPrint('👤 User: ${response.user?.email}');
      debugPrint('🆔 User ID: ${response.user?.id}');
      
      return response;
      
    } on AuthException catch (e) {
      debugPrint('❌ Auth error: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error during Google Sign-In: $e');
      debugPrint('Stack trace: $stackTrace');
      throw AuthException('Failed to sign in with Google: $e');
    }
  }
  
  /// Sign out from Google
  Future<void> signOut() async {
    try {
      debugPrint('👋 Signing out from Google...');
      await _googleSignIn.signOut();
      debugPrint('✅ Google sign-out successful');
    } catch (e) {
      debugPrint('⚠️ Error signing out from Google: $e');
      // Don't throw, just log the error
    }
  }
  
  /// Check if user is currently signed in to Google
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }
  
  /// Get currently signed in Google account (if any)
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }
  
  /// Disconnect Google account (revokes access)
  /// This is different from sign out - it completely removes authorization
  Future<void> disconnect() async {
    try {
      debugPrint('🔌 Disconnecting Google account...');
      await _googleSignIn.disconnect();
      debugPrint('✅ Google disconnect successful');
    } catch (e) {
      debugPrint('⚠️ Error disconnecting Google: $e');
      // Don't throw, just log the error
    }
  }
}
