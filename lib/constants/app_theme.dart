import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ✨ ANGKAS-INSPIRED BLUE GRADIENT COLOR SYSTEM ✨
  
  // Primary Blue Gradient (Headers, Primary Actions)
  static const Color primaryBlue = Color(0xFF00B4DB); // Cyan Blue (gradient start)
  static const Color primaryBlueDark = Color(0xFF0083B0); // Deep Ocean Blue (gradient end)
  static const Color primaryBlueLight = Color(0xFF56CCF2); // Light Cyan (hover states)
  
  // Accent Cyan Gradient (Highlights, Secondary Actions)
  static const Color accentCyan = Color(0xFF56CCF2); // Light Cyan (accent start)
  static const Color accentBlue = Color(0xFF2F80ED); // Bright Blue (accent end)
  static const Color accentTeal = Color(0xFF06B6D4); // Teal (tertiary)
  
  // Legacy colors (kept for backward compatibility)
  static const Color secondaryBlue = primaryBlue; // Alias
  
  // Gradient Colors - Angkas Blue Style
  static const Color gradientStart = primaryBlue; // #00B4DB
  static const Color gradientEnd = primaryBlueDark; // #0083B0
  static const Color gradientAccent = accentCyan; // #56CCF2
  
  // Success & Status Colors (Angkas Style)
  static const Color successColor = Color(0xFF10B981); // Green
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warningColor = Color(0xFFF59E0B); // Orange
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color infoColor = Color(0xFF3B82F6); // Info blue
  static const Color infoLight = Color(0xFFEFF6FF);
  
  // Neutral Colors (Clean & Modern)
  static const Color backgroundColor = Color(0xFFF8FAFB); // Off-white with blue tint
  static const Color surfaceColor = Color(0xFFFFFFFF); // Pure white
  static const Color cardColor = Color(0xFFFFFFFF); // Pure white for cards
  static const Color sheetColor = Color(0xFFF8FAFB); // Light background for sheets
  static const Color dividerColor = Color(0xFFE5E7EB); // Light gray divider
  static const Color borderColor = Color(0xFFE5E7EB); // Light gray border
  
  // Text Colors (Neutral & High Contrast)
  static const Color textPrimary = Color(0xFF1A1F36); // Almost black
  static const Color textSecondary = Color(0xFF6B7280); // Medium gray
  static const Color textTertiary = Color(0xFF9CA3AF); // Light gray
  static const Color textHint = Color(0xFFD1D5DB); // Very light gray
  static const Color textInverse = Color(0xFFFFFFFF); // White (for blue backgrounds)
  
  // Shadow Colors
  static const Color shadowLight = Color(0x0D000000);
  static const Color shadowMedium = Color(0x1A000000);
  static const Color shadowDark = Color(0x26000000);
  
  // Premium Gradients
  // Primary Blue Gradient (Headers, Primary Actions, Backgrounds)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryBlueDark], // #00B4DB → #0083B0 (Cyan to Deep Ocean)
    stops: [0.0, 1.0],
  );
  
  // Accent Cyan Gradient (Highlights, Secondary Actions, Active States)
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [accentCyan, accentBlue], // #56CCF2 → #2F80ED (Light Cyan to Bright Blue)
    stops: [0.0, 1.0],
  );
  
  // Background Gradient (Page backgrounds)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFB), Color(0xFFFFFFFF)], // Off-white to pure white
  );
  
  // Shimmer Gradient (Loading states)
  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0xFFE0F2FE), 
      Color(0xFFF0F9FF), 
      Color(0xFFE0F2FE)
    ], // Soft blue shimmer
    stops: [0.1, 0.3, 0.4],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  // Shadow Definitions (Angkas Style - Soft & Subtle)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: shadowLight,
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: shadowMedium,
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: shadowMedium,
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: shadowLight,
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  
  // Button Shadow (Blue glow for primary buttons)
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryBlue.withOpacity(0.25), // Updated to use new primaryBlue (#00B4DB)
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: GoogleFonts.inter().fontFamily,
      
      // Advanced Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        secondary: accentCyan,
        tertiary: accentTeal,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: textInverse,
        onSecondary: textInverse,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textInverse,
        outline: borderColor,
        surfaceVariant: sheetColor,
      ),
      
      // Enhanced App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: textSecondary,
          size: 24,
        ),
      ),
      
      // Premium Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) {
              return primaryBlueDark;
            }
            if (states.contains(MaterialState.disabled)) {
              return textHint;
            }
            return null;
          }),
          foregroundColor: MaterialStateProperty.all(textInverse),
          shadowColor: MaterialStateProperty.all(Colors.transparent),
        ),
      ),
      
      // Modern Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: borderColor, width: 1.5),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      
      // Enhanced Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        
        // Border Styles
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        
        // Text Styles
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: primaryBlue,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.inter(
          color: textHint,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: GoogleFonts.inter(
          color: errorColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // Premium Card Theme
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dividerColor.withOpacity(0.5)),
        ),
        color: cardColor,
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      
      // Modern Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        modalBackgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: dividerColor,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      
      // List Tile Theme
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      
      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      
      // Advanced Text Theme
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          color: textPrimary,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.8,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.6,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.1,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.05,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textTertiary,
          letterSpacing: 0.05,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.15,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textTertiary,
          letterSpacing: 0.15,
        ),
      ),
      
      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: sheetColor,
        selectedColor: primaryBlue.withOpacity(0.1),
        secondarySelectedColor: accentCyan.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: primaryBlue,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: const BorderSide(color: borderColor),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    );
  }

  // Spacing Constants
  static const double spacing2 = 2.0;
  static const double spacing4 = 4.0;
  static const double spacing6 = 6.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing28 = 28.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing56 = 56.0;
  static const double spacing64 = 64.0;

  // Border Radius Constants
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius28 = 28.0;
  static const double radius32 = 32.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration animationSlower = Duration(milliseconds: 800);
}