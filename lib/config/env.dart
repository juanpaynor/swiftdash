import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class Env {
  // Fallback values for web deployment (replace with your actual values)
  static const String _fallbackSupabaseUrl = 'https://lygzxmhskkqrntnmxtbb.supabase.co';
  static const String _fallbackSupabaseAnonKey = 'sb_publishable_AXpznyj7ra4eUoDiYQmqEQ_enUzT-Mc';
  static const String _fallbackGoogleMapsApiKey = 'AIzaSyANfwae0FJo4S8AG74T72n9XoB95y60mQ8';
  // Mapbox fallback (only used if .env not set). Consider moving to .env for production.
  static const String _fallbackMapboxAccessToken = '';
  static const String _fallbackMapboxStyleUrl = 'mapbox://styles/mapbox/streets-v12';

  static String get googleMapsApiKey {
    final envValue = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }
    return kIsWeb ? _fallbackGoogleMapsApiKey : '';
  }

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

  // Map provider flag: 'google' (default) or 'mapbox'
  static String get mapProvider {
    final v = dotenv.env['MAP_PROVIDER'];
    if (v != null && v.isNotEmpty) return v.toLowerCase();
    return 'google';
  }

  static String get mapboxAccessToken {
    final envValue = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (envValue != null && envValue.isNotEmpty) return envValue;
    // If you want to hardcode for quick testing, you can put your token here temporarily.
    return _fallbackMapboxAccessToken;
  }

  static String get mapboxStyleUrl {
    final envValue = dotenv.env['MAPBOX_STYLE_URL'];
    if (envValue != null && envValue.isNotEmpty) return envValue;
    return _fallbackMapboxStyleUrl;
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