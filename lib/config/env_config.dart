import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration service for managing API keys and sensitive data
class EnvConfig {
  /// Load environment variables from .env file
  static Future<void> load() async {
    await dotenv.load(fileName: ".env");
  }

  /// Google Places API Key for search functionality
  static String get googlePlacesApiKey {
    final key = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_PLACES_API_KEY not found in .env file');
    }
    return key;
  }

  /// Google Maps API Key for maps functionality  
  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY not found in .env file');
    }
    return key;
  }

  /// Mapbox Access Token for map display
  static String get mapboxAccessToken {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (token == null || token.isEmpty) {
      throw Exception('MAPBOX_ACCESS_TOKEN not found in .env file');
    }
    return token;
  }

  /// Mapbox Secret Token for server-side APIs (Optimization, Directions, etc.)
  static String get mapboxSecretToken {
    final token = dotenv.env['MAPBOX_SECRET_TOKEN'];
    if (token == null || token.isEmpty) {
      throw Exception('MAPBOX_SECRET_TOKEN not found in .env file');
    }
    return token;
  }

  /// Supabase URL
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('SUPABASE_URL not found in .env file');
    }
    return url;
  }

  /// Supabase Anonymous Key
  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY not found in .env file');
    }
    return key;
  }

  /// Map provider configuration
  static String get mapProvider {
    return dotenv.env['MAP_PROVIDER'] ?? 'mapbox';
  }

  /// Mapbox style URL
  static String get mapboxStyleUrl {
    return dotenv.env['MAPBOX_STYLE_URL'] ?? 'mapbox://styles/mapbox/streets-v12';
  }

  /// Check if we're in development mode
  static bool get isDevelopment {
    return dotenv.env['ENVIRONMENT'] != 'production';
  }

  /// Get all environment variables (for debugging - remove in production)
  static Map<String, String> getAllEnvVars() {
    if (!isDevelopment) {
      throw Exception('Environment variables can only be accessed in development mode');
    }
    return Map<String, String>.from(dotenv.env);
  }
}