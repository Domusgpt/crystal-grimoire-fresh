import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/enhanced_theme.dart';
import 'gem_symbol_logo.dart';
import 'teal_red_gem_logo.dart';

class EnhancedAppTitle extends StatefulWidget {
  final double fontSize;
  final bool showLogo;
  
  const EnhancedAppTitle({
    Key? key,
    this.fontSize = 48,
    this.showLogo = true,
  }) : super(key: key);

  @override
  State<EnhancedAppTitle> createState() => _EnhancedAppTitleState();
}

class _EnhancedAppTitleState extends State<EnhancedAppTitle>
    with TickerProviderStateMixin {
  late AnimationController _sparkleController;
  late AnimationController _colorController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    // Sparkle animation - optimized for performance
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 6), // Longer duration for better performance
      vsync: this,
    )..repeat();
    
    // Color shift animation - smoother curves
    _colorController = AnimationController(
      duration: const Duration(seconds: 8), // Longer duration for smoother animation
      vsync: this,
    )..repeat(reverse: true);
    
    _colorAnimation = ColorTween(
      begin: CrystalGrimoireTheme.amethyst,
      end: CrystalGrimoireTheme.celestialGold,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOut,
    ));
    
    // Pulse animation - very subtle
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 6000), // Slower pulse for better performance
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    _colorController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main content - NEW GEM LOGO
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NEW: Teal/Red Gem Logo (replaces text)
            TealRedGemLogo(
              size: widget.fontSize * 1.5, // Make it prominent
              animate: true,
            ),
            
            const SizedBox(height: 8),
            
            // Subtle app name below logo
            AnimatedBuilder(
              animation: _colorAnimation,
              builder: (context, child) {
                return Text(
                  'Crystal Grimoire',
                  style: TextStyle(
                    fontSize: widget.fontSize * 0.4, // Much smaller than before
                    fontWeight: FontWeight.w600,
                    fontFamily: 'serif',
                    letterSpacing: 2.0,
                    color: Colors.white.withOpacity(0.9),
                    shadows: [
                      Shadow(
                        color: _colorAnimation.value!.withOpacity(0.6),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            if (widget.showLogo) ...[
              const SizedBox(height: 16),
              // Classic diamond emoji with dramatic effects
              _buildClassicDiamondLogo(),
            ],
          ],
        ),
        
        // Sparkle overlay - now properly positioned in Stack
        if (widget.showLogo)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _sparkleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SparklePainter(
                      progress: _sparkleController.value,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildClassicDiamondLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_sparkleController, _colorAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _colorAnimation.value!.withOpacity(0.1),
                  _colorAnimation.value!.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _colorAnimation.value!.withOpacity(0.6),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const GemSymbolLogo(
              size: 100,
              animate: true,
              colors: [
                Color(0xFF20B2AA), // Teal
                Color(0xFFFF4500), // Red
                Color(0xFFFF8C00), // Orange
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOldAnimatedGemstone() {
    return AnimatedBuilder(
      animation: _sparkleController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _sparkleController.value * 2 * math.pi * 0.1,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  CrystalGrimoireTheme.etherealBlue.withOpacity(0.3),
                  CrystalGrimoireTheme.amethyst.withOpacity(0.5),
                  CrystalGrimoireTheme.cosmicViolet.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: CrystalGrimoireTheme.etherealBlue.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gemstone shape
                CustomPaint(
                  size: const Size(50, 50),
                  painter: GemStonePainter(
                    color: CrystalGrimoireTheme.amethyst,
                    shimmerProgress: _sparkleController.value,
                  ),
                ),
                // Inner glow
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.8),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GemStonePainter extends CustomPainter {
  final Color color;
  final double shimmerProgress;

  GemStonePainter({
    required this.color,
    required this.shimmerProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shimmerPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Create hexagonal gemstone shape
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Draw base gemstone
    canvas.drawPath(path, paint);

    // Draw facets
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      final facetPath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(x, y);
      
      final nextAngle = ((i + 1) * 60) * math.pi / 180;
      final nextX = center.dx + radius * math.cos(nextAngle);
      final nextY = center.dy + radius * math.sin(nextAngle);
      facetPath.lineTo(nextX, nextY);
      facetPath.close();
      
      // Shimmer effect on facets
      if (i == (shimmerProgress * 6).floor()) {
        canvas.drawPath(facetPath, shimmerPaint);
      }
      
      // Facet borders
      final borderPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      
      canvas.drawPath(facetPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SparklePainter extends CustomPainter {
  final double progress;
  final Color color;

  SparklePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Create random sparkles
    final random = math.Random(42);
    for (int i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkleProgress = (progress + i * 0.1) % 1.0;
      final opacity = math.sin(sparkleProgress * math.pi);
      
      paint.color = color.withOpacity(opacity * 0.8);
      
      // Draw sparkle
      canvas.drawCircle(
        Offset(x, y),
        2 + random.nextDouble() * 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}