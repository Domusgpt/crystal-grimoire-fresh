import 'package:flutter/material.dart';

class CrystalTheme {
  // Mystical color palette
  static const Color deepPurple = Color(0xFF1E1B4B);
  static const Color royalPurple = Color(0xFF2D1B69);
  static const Color mysticPurple = Color(0xFF6B21A8);
  static const Color amethyst = Color(0xFF9333EA);
  static const Color crystalWhite = Color(0xFFF8FAFC);
  static const Color moonlightSilver = Color(0xFFE2E8F0);
  static const Color stardustGold = Color(0xFFFFD700);
  static const Color celestialBlue = Color(0xFF3B82F6);
  
  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepPurple, royalPurple, mysticPurple],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2D1B69),
      Color(0xFF1E1B4B),
    ],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0xFF2D1B69),
      Color(0xFF6B21A8),
      Color(0xFF2D1B69),
    ],
  );

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: mysticPurple,
        secondary: amethyst,
        surface: deepPurple,
        background: deepPurple,
        onPrimary: crystalWhite,
        onSecondary: crystalWhite,
        onSurface: crystalWhite,
        onBackground: crystalWhite,
      ),
      
      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: crystalWhite,
          fontFamily: 'Mystical',
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: crystalWhite,
          fontFamily: 'Mystical',
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: crystalWhite,
          fontFamily: 'Mystical',
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: crystalWhite,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: crystalWhite,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: moonlightSilver,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: moonlightSilver,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: Color(0xFFBBBBBB),
        ),
      ),
      
      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: crystalWhite,
          fontFamily: 'Mystical',
        ),
        iconTheme: IconThemeData(color: crystalWhite),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: royalPurple.withOpacity(0.3),
        elevation: 8,
        shadowColor: mysticPurple.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mysticPurple,
          foregroundColor: crystalWhite,
          elevation: 4,
          shadowColor: mysticPurple.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: crystalWhite,
        size: 24,
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: royalPurple.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mysticPurple.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mysticPurple.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: amethyst, width: 2),
        ),
        labelStyle: const TextStyle(color: moonlightSilver),
        hintStyle: TextStyle(color: moonlightSilver.withOpacity(0.7)),
      ),
    );
  }
}

// Custom decorations for mystical effects
class MysticalDecorations {
  static BoxDecoration get glowingCard => BoxDecoration(
    gradient: CrystalTheme.cardGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: CrystalTheme.mysticPurple.withOpacity(0.3),
        blurRadius: 20,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: CrystalTheme.amethyst.withOpacity(0.2),
        blurRadius: 40,
        spreadRadius: 4,
      ),
    ],
  );

  static BoxDecoration get crystalBorder => BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: CrystalTheme.amethyst.withOpacity(0.5),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: CrystalTheme.mysticPurple.withOpacity(0.2),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
  );

  static BoxDecoration get shimmerEffect => BoxDecoration(
    gradient: CrystalTheme.shimmerGradient,
    borderRadius: BorderRadius.circular(8),
  );
}