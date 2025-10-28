import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Service for creating driver profile picture markers for map display
/// Handles downloading, processing, and caching driver photos
class DriverMarkerService {
  // Cache processed marker images to avoid re-processing
  static final Map<String, Uint8List> _markerCache = {};

  /// Creates a circular marker image from driver's profile picture URL
  /// Returns processed image bytes ready for Mapbox PointAnnotation
  /// 
  /// Process:
  /// 1. Download image from URL
  /// 2. Resize to 120x120px
  /// 3. Crop to circular shape
  /// 4. Add white border
  /// 5. Cache result
  static Future<Uint8List?> createDriverMarker({
    required String profilePictureUrl,
    required String driverId,
    int size = 120,
    int borderWidth = 5,
    Color borderColor = Colors.white,
  }) async {
    try {
      // Check cache first
      final cacheKey = '${driverId}_${size}_${borderWidth}';
      if (_markerCache.containsKey(cacheKey)) {
        debugPrint('✅ Using cached marker for driver: $driverId');
        return _markerCache[cacheKey];
      }

      debugPrint('🔽 Downloading driver profile picture: $profilePictureUrl');
      debugPrint('🔽 URL parsed: ${Uri.parse(profilePictureUrl)}');

      // Download image
      final response = await http.get(
        Uri.parse(profilePictureUrl),
        headers: {
          'User-Agent': 'SwiftDash-Customer-App/1.0',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('❌ Download timeout after 10 seconds');
          throw Exception('Profile picture download timeout');
        },
      );

      debugPrint('📥 HTTP Response Status: ${response.statusCode}');
      debugPrint('📥 Content-Type: ${response.headers['content-type']}');
      debugPrint('📥 Content-Length: ${response.headers['content-length']}');

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to download profile picture: HTTP ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        return null;
      }

      debugPrint('✅ Profile picture downloaded (${response.bodyBytes.length} bytes)');

      // Decode image
      debugPrint('🔄 Attempting to decode image...');
      img.Image? image = img.decodeImage(response.bodyBytes);
      if (image == null) {
        debugPrint('❌ Failed to decode profile picture');
        debugPrint('❌ First 100 bytes: ${response.bodyBytes.take(100).toList()}');
        return null;
      }

      debugPrint('✅ Image decoded successfully!');
      debugPrint('🎨 Processing image: ${image.width}x${image.height}');

      // Process image
      debugPrint('🔄 Starting image processing (resize + crop + border)...');
      final processedImage = _processImage(
        image,
        size: size,
        borderWidth: borderWidth,
        borderColor: borderColor,
      );
      debugPrint('✅ Image processed: ${processedImage.width}x${processedImage.height}');

      // Encode to PNG
      debugPrint('🔄 Encoding image to PNG...');
      final pngBytes = Uint8List.fromList(img.encodePng(processedImage));
      debugPrint('✅ Image encoded: ${pngBytes.length} bytes');
      
      // Cache it
      _markerCache[cacheKey] = pngBytes;
      
      debugPrint('✅ Driver marker created and cached: ${pngBytes.length} bytes');

      return pngBytes;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating driver marker: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Process image: Resize → Circular crop → Add border
  static img.Image _processImage(
    img.Image image, {
    required int size,
    required int borderWidth,
    required Color borderColor,
  }) {
    // Step 1: Resize to target size
    final resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic, // High quality
    );

    // Step 2: Create circular mask
    final circular = _cropToCircle(resized, size);

    // Step 3: Add white border
    final withBorder = _addBorder(
      circular,
      borderWidth: borderWidth,
      borderColor: borderColor,
    );

    return withBorder;
  }

  /// Crop image to perfect circle
  static img.Image _cropToCircle(img.Image image, int size) {
    final center = size / 2;
    final radius = size / 2;

    // Create new image with transparent background (RGBA format)
    final circularImage = img.Image(
      width: size, 
      height: size,
      numChannels: 4, // RGBA - ensures proper alpha channel
    );
    
    // Fill with fully transparent background
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        circularImage.setPixelRgba(x, y, 0, 0, 0, 0); // Transparent
      }
    }

    // Draw circular mask
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final dx = x - center;
        final dy = y - center;
        final distance = (dx * dx + dy * dy).abs();

        // If pixel is within circle radius
        if (distance <= radius * radius) {
          final pixel = image.getPixel(x, y);
          circularImage.setPixel(x, y, pixel);
        }
      }
    }

    return circularImage;
  }

  /// Add white border around circular image
  static img.Image _addBorder(
    img.Image image, {
    required int borderWidth,
    required Color borderColor,
  }) {
    final size = image.width;
    final center = size / 2;
    final outerRadius = size / 2;
    final innerRadius = outerRadius - borderWidth;

    // Create new image with RGBA format for proper transparency
    final borderedImage = img.Image(
      width: size, 
      height: size,
      numChannels: 4, // RGBA - ensures proper alpha channel
    );
    
    // Fill with fully transparent background
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        borderedImage.setPixelRgba(x, y, 0, 0, 0, 0); // Transparent
      }
    }

    // Draw border and image
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final dx = x - center;
        final dy = y - center;
        final distance = (dx * dx + dy * dy).abs();

        // Border ring
        if (distance <= outerRadius * outerRadius && 
            distance > innerRadius * innerRadius) {
          borderedImage.setPixelRgba(
            x, y,
            borderColor.red,
            borderColor.green,
            borderColor.blue,
            borderColor.alpha,
          );
        }
        // Inner image
        else if (distance <= innerRadius * innerRadius) {
          final pixel = image.getPixel(x, y);
          borderedImage.setPixel(x, y, pixel);
        }
      }
    }

    return borderedImage;
  }

  /// Clear cached markers (call when memory is needed)
  static void clearCache() {
    _markerCache.clear();
    debugPrint('🧹 Driver marker cache cleared');
  }

  /// Get cache size in bytes
  static int getCacheSize() {
    int totalBytes = 0;
    for (final bytes in _markerCache.values) {
      totalBytes += bytes.length;
    }
    return totalBytes;
  }

  /// Check if marker is cached
  static bool isCached(String driverId, {int size = 120, int borderWidth = 5}) {
    final cacheKey = '${driverId}_${size}_${borderWidth}';
    return _markerCache.containsKey(cacheKey);
  }
}
