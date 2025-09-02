import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Mystical color palette
  static const Color deepMystical = Color(0xFF0D0221);
  static const Color darkViolet = Color(0xFF1A0B2E);
  static const Color midnightBlue = Color(0xFF16213E);
  static const Color amethystPurple = Color(0xFF9966CC);
  static const Color blueViolet = Color(0xFF8A2BE2);
  static const Color plum = Color(0xFFDDA0DD);
  static const Color crystalGlow = Color(0xFFE0AAFF);
  static const Color mysticPink = Color(0xFFC77DFF);
  static const Color cosmicPurple = Color(0xFF9D4EDD);
  static const Color mysticalPurple = Color(0xFF6D28D9);
  
  // Holographic colors from visual_codex
  static const Color holoBlue = Color(0xFF00FFFF);
  static const Color holoPink = Color(0xFFFF00FF);
  static const Color holoYellow = Color(0xFFFFFF00);
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: amethystPurple,
        secondary: cosmicPurple,
        tertiary: mysticPink,
        surface: darkViolet,
        background: deepMystical,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: crystalGlow,
        onBackground: crystalGlow,
      ),
      
      // Background
      scaffoldBackgroundColor: deepMystical,
      
      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: crystalGlow,
          letterSpacing: 2,
        ),
      ),
      
      // Text theme
      textTheme: TextTheme(
        // Display styles
        displayLarge: GoogleFonts.cinzelDecorative(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: crystalGlow,
          letterSpacing: 3,
        ),
        displayMedium: GoogleFonts.cinzelDecorative(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: crystalGlow,
          letterSpacing: 2,
        ),
        displaySmall: GoogleFonts.cinzelDecorative(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: crystalGlow,
        ),
        
        // Headlines
        headlineLarge: GoogleFonts.orbitron(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: crystalGlow,
        ),
        headlineMedium: GoogleFonts.orbitron(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: crystalGlow,
        ),
        headlineSmall: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: crystalGlow,
        ),
        
        // Body text
        bodyLarge: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          color: Colors.white70,
        ),
        bodyMedium: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          color: Colors.white70,
        ),
        bodySmall: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          color: Colors.white60,
        ),
        
        // Labels
        labelLarge: GoogleFonts.orbitron(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: crystalGlow,
          letterSpacing: 1.2,
        ),
      ),
      
      // Card theme with glassmorphism
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amethystPurple.withOpacity(0.3),
          foregroundColor: crystalGlow,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: amethystPurple.withOpacity(0.5),
              width: 1,
            ),
          ),
          textStyle: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: crystalGlow,
        size: 24,
      ),
      
      // Divider theme
      dividerTheme: DividerThemeData(
        color: crystalGlow.withOpacity(0.2),
        thickness: 1,
      ),
    );
  }
  
  // Glassmorphic container decoration
  static BoxDecoration glassmorphicDecoration({
    List<Color>? gradientColors,
    double borderRadius = 20,
    double opacity = 0.1,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors ?? [
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(opacity * 0.5),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: amethystPurple.withOpacity(0.1),
          blurRadius: 20,
          spreadRadius: -5,
        ),
      ],
    );
  }
  
  // Holographic gradient shader
  static Shader holographicShader(Rect bounds) {
    return const LinearGradient(
      colors: [holoBlue, holoPink, holoYellow, holoBlue],
      stops: [0.0, 0.33, 0.67, 1.0],
    ).createShader(bounds);
  }
  
  // Mystical gradient shader
  static Shader mysticalShader(Rect bounds) {
    return const LinearGradient(
      colors: [crystalGlow, mysticPink, cosmicPurple],
      stops: [0.0, 0.5, 1.0],
    ).createShader(bounds);
  }
}