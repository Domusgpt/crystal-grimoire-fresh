import 'package:flutter/material.dart';

/// Enhanced mystical theme for Crystal Grimoire with animations and polish
class CrystalGrimoireTheme {
  // Core mystical color palette
  static const Color deepSpace = Color(0xFF0F0F23);
  static const Color midnightPurple = Color(0xFF1E1B4B);
  static const Color royalPurple = Color(0xFF2D1B69);
  static const Color mysticPurple = Color(0xFF6B21A8);
  static const Color amethyst = Color(0xFF9333EA);
  static const Color cosmicViolet = Color(0xFFA855F7);
  static const Color stardustSilver = Color(0xFFE2E8F0);
  static const Color moonlightSilver = Color(0xFFE5E7EB);
  static const Color moonlightWhite = Color(0xFFF8FAFC);
  static const Color celestialGold = Color(0xFFFFD700);
  static const Color etherealBlue = Color(0xFF3B82F6);
  static const Color crystalRose = Color(0xFFFF4081);
  
  // Status colors
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  
  // Enhanced gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      deepSpace,
      midnightPurple,
      royalPurple,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2D1B69),
      Color(0xFF1E1B4B),
      Color(0xFF0F0F23),
    ],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      mysticPurple,
      amethyst,
      cosmicViolet,
    ],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      celestialGold,
      Color(0xFFFFE135),
      celestialGold,
    ],
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x00FFFFFF),
      Color(0x40FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Glassmorphism effects
  static BoxDecoration glassmorphismCard({
    bool isGlowing = false,
    Color? glowColor,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          royalPurple.withOpacity(0.4),
          midnightPurple.withOpacity(0.2),
          deepSpace.withOpacity(0.6),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: stardustSilver.withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        if (isGlowing) ...[
          BoxShadow(
            color: (glowColor ?? mysticPurple).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: (glowColor ?? amethyst).withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ] else ...[
          BoxShadow(
            color: deepSpace.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ],
    );
  }

  static BoxDecoration premiumCard() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          celestialGold.withOpacity(0.3),
          mysticPurple.withOpacity(0.2),
          royalPurple.withOpacity(0.4),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: celestialGold.withOpacity(0.5),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: celestialGold.withOpacity(0.2),
          blurRadius: 20,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: mysticPurple.withOpacity(0.1),
          blurRadius: 40,
          spreadRadius: 4,
        ),
      ],
    );
  }

  // Animation durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration breathingAnimation = Duration(milliseconds: 2000);

  // Curves
  static const Curve elasticCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
  static const Curve bounceCurve = Curves.bounceOut;

  // Create the main theme
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: mysticPurple,
        primaryContainer: royalPurple,
        secondary: amethyst,
        secondaryContainer: cosmicViolet,
        tertiary: crystalRose,
        surface: midnightPurple,
        surfaceVariant: royalPurple,
        background: deepSpace,
        onPrimary: moonlightWhite,
        onSecondary: moonlightWhite,
        onTertiary: moonlightWhite,
        onSurface: stardustSilver,
        onSurfaceVariant: stardustSilver.withOpacity(0.8),
        onBackground: moonlightWhite,
        outline: stardustSilver.withOpacity(0.3),
        error: errorRed,
        onError: moonlightWhite,
      ),
      
      // Typography with mystical fonts
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: moonlightWhite,
          letterSpacing: 1.2,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: moonlightWhite,
          letterSpacing: 1.1,
          height: 1.3,
        ),
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: moonlightWhite,
          letterSpacing: 1.0,
          height: 1.3,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: moonlightWhite,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: moonlightWhite,
          letterSpacing: 0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: stardustSilver,
          letterSpacing: 0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: moonlightWhite,
          letterSpacing: 0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: stardustSilver,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: stardustSilver,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: stardustSilver,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: Color(0xFFB8B8B8),
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: moonlightWhite,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: stardustSilver,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: stardustSilver,
        ),
      ),
      
      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: moonlightWhite,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(
          color: moonlightWhite,
          size: 24,
        ),
      ),
      
      // Card theme with glassmorphism
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Enhanced button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: moonlightWhite,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mysticPurple,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
      
      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: moonlightWhite,
          side: BorderSide(color: mysticPurple.withOpacity(0.5), width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
      
      // Icon theme
      iconTheme: const IconThemeData(
        color: stardustSilver,
        size: 24,
      ),
      
      // Enhanced input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: royalPurple.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: stardustSilver.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: stardustSilver.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: amethyst, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: TextStyle(
          color: stardustSilver.withOpacity(0.8),
          fontSize: 16,
        ),
        hintStyle: TextStyle(
          color: stardustSilver.withOpacity(0.6),
          fontSize: 16,
        ),
        errorStyle: const TextStyle(
          color: errorRed,
          fontSize: 12,
        ),
      ),
      
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: royalPurple.withOpacity(0.4),
        selectedColor: mysticPurple,
        disabledColor: stardustSilver.withOpacity(0.2),
        labelStyle: const TextStyle(
          color: moonlightWhite,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: stardustSilver.withOpacity(0.3)),
        ),
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: amethyst,
        linearTrackColor: Color(0xFF2A2A3A),
        circularTrackColor: Color(0xFF2A2A3A),
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: mysticPurple,
        foregroundColor: moonlightWhite,
        elevation: 8,
        highlightElevation: 12,
        shape: CircleBorder(),
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: midnightPurple,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          color: moonlightWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: stardustSilver,
          fontSize: 16,
        ),
      ),
      
      // Bottom sheet theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: midnightPurple,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
      ),
      
      // Drawer theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: deepSpace,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
      ),
    );
  }
}

/// Custom decorations and effects
class MysticalEffects {
  // Glow effect for premium elements
  static BoxDecoration get premiumGlow => BoxDecoration(
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: CrystalGrimoireTheme.celestialGold.withOpacity(0.3),
        blurRadius: 20,
        spreadRadius: 2,
      ),
      BoxShadow(
        color: CrystalGrimoireTheme.celestialGold.withOpacity(0.1),
        blurRadius: 40,
        spreadRadius: 4,
      ),
    ],
  );

  // Crystal shimmer effect
  static BoxDecoration get crystalShimmer => BoxDecoration(
    gradient: CrystalGrimoireTheme.shimmerGradient,
    borderRadius: BorderRadius.circular(8),
  );

  // Floating animation shadow
  static List<BoxShadow> get floatingShadow => [
    BoxShadow(
      color: CrystalGrimoireTheme.deepSpace.withOpacity(0.3),
      blurRadius: 15,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: CrystalGrimoireTheme.mysticPurple.withOpacity(0.1),
      blurRadius: 30,
      offset: const Offset(0, 4),
    ),
  ];

  // Pulsing glow animation keyframes
  static Animation<double> createPulseAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }

  // Breathing scale animation
  static Animation<double> createBreathingAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }
}