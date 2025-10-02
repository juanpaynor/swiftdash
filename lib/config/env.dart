import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Env {
  // Fallback values for web deployment (replace with your actual values)
  static const String _fallbackSupabaseUrl = 'https://lygzxmhskkqrntnmxtbb.supabase.co';
  static const String _fallbackSupabaseAnonKey = 'sb_publishable_AXpznyj7ra4eUoDiYQmqEQ_enUzT-Mc';
  static const String _fallbackMapProvider = 'mapbox'; // Default to Mapbox

  // SECURE: API keys removed from code - using environment variables only

  static String get supabaseUrl {
    final envValue = dotenv.env['SUPABASE_URL'];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }
    return kIsWeb ? _fallbackSupabaseUrl : '';
  }

  static String get supabaseAnonKey {
    final envValue = dotenv.env['SUPABASE_ANON_KEY'];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }
    return kIsWeb ? _fallbackSupabaseAnonKey : '';
  }

  // SECURE: Google Places API Key from environment
  static String get googlePlacesApiKey {
    final envValue = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (envValue == null || envValue.isEmpty) {
      throw Exception('GOOGLE_PLACES_API_KEY not found in .env file');
    }
    return envValue;
  }

  // SECURE: Google Maps API Key from environment  
  static String get googleMapsApiKey {
    final envValue = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (envValue == null || envValue.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY not found in .env file');
    }
    return envValue;
  }

  // SECURE: Mapbox Access Token from environment
  static String get mapboxAccessToken {
    final envValue = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (envValue == null || envValue.isEmpty) {
      throw Exception('MAPBOX_ACCESS_TOKEN not found in .env file');
    }
    return envValue;
  }

  static String get mapProvider {
    final envValue = dotenv.env['MAP_PROVIDER'];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }
    // Using Mapbox for all platforms
    return _fallbackMapProvider;
  }

  /// Loads environment variables from the .env file if present.
  ///
  /// If the file is missing, we log a debug message and continue so the
  /// app can start (useful for local development where a .env may be
  /// intentionally excluded). Callers should still validate required
  /// variables (for example, Supabase keys) before using them.
  static Future<void> load() async {
    try {
      // For web, we can't check file existence, so we just try to load
      if (kIsWeb) {
        await dotenv.load(fileName: '.env');
        return;
      }
      
      // For mobile/desktop platforms, check if file exists first
      const String envFile = '.env';
      await dotenv.load(fileName: envFile);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Could not load .env file: $e');
        debugPrint('Using fallback environment values for ${kIsWeb ? 'web' : 'mobile'}');
      }
    }
  }
}