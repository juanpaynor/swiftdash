import 'package:flutter/material.dart';

/// Modern color system for clean tracking screen design
/// Features sleek blue accents (#3B82F6) with neutral greys
class ModernColors {
  // Primary blue accent system
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color darkBlue = Color(0xFF2563EB);
  
  // Blue variants for different states
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color blueLight = Color(0xFFDbeafe);
  static const Color blueVeryLight = Color(0xFFF0F9FF);
  
  // Neutral grey system
  static const Color darkGrey = Color(0xFF1F2937);
  static const Color mediumGrey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFF9CA3AF);
  static const Color veryLightGrey = Color(0xFFF3F4F6);
  static const Color borderGrey = Color(0xFFE5E7EB);
  
  // Background colors
  static const Color cardBackground = Colors.white;
  static const Color screenBackground = Color(0xFFFAFAFA);
  static const Color accentBackground = Color(0xFFF8FAFC);
  
  // Status colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  
  // Shadow colors
  static Color shadowLight = Colors.black.withOpacity(0.08);
  static Color shadowMedium = Colors.black.withOpacity(0.12);
  static Color shadowDark = Colors.black.withOpacity(0.16);
  
  // Blue accent with opacity variations
  static Color blueAccentLight = primaryBlue.withOpacity(0.1);
  static Color blueAccentMedium = primaryBlue.withOpacity(0.2);
  static Color blueAccentStrong = primaryBlue.withOpacity(0.3);
}

/// Modern shadow presets for consistent elevation
class ModernShadows {
  static List<BoxShadow> get small => [
    BoxShadow(
      color: ModernColors.shadowLight,
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: ModernColors.shadowMedium,
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get large => [
    BoxShadow(
      color: ModernColors.shadowMedium,
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: ModernColors.shadowLight,
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get blueGlow => [
    BoxShadow(
      color: ModernColors.blueAccentStrong,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}