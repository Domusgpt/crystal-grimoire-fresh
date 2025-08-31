import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class FloatingCrystals extends StatefulWidget {
  final int crystalCount;
  final double maxSize;
  
  const FloatingCrystals({
    super.key,
    this.crystalCount = 15,
    this.maxSize = 60,
  });

  @override
  State<FloatingCrystals> createState() => _FloatingCrystalsState();
}

class _FloatingCrystalsState extends State<FloatingCrystals> with TickerProviderStateMixin {
  final List<CrystalParticle> crystals = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _initializeCrystals();
  }

  void _initializeCrystals() {
    final random = math.Random();
    for (int i = 0; i < widget.crystalCount; i++) {
      crystals.add(CrystalParticle(
        position: Offset(
          random.nextDouble() * 1.0,
          random.nextDouble() * 1.0,
        ),
        size: random.nextDouble() * widget.maxSize + 20,
        speed: random.nextDouble() * 0.02 + 0.005,
        opacity: random.nextDouble() * 0.3 + 0.1,
        color: [
          AppTheme.amethystPurple,
          AppTheme.cosmicPurple,
          AppTheme.mysticPink,
          AppTheme.holoBlue,
        ][random.nextInt(4)],
        rotationSpeed: random.nextDouble() * 2 - 1,
      ));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: CrystalPainter(
            crystals: crystals,
            animation: _animationController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class CrystalParticle {
  Offset position;
  final double size;
  final double speed;
  final double opacity;
  final Color color;
  final double rotationSpeed;

  CrystalParticle({
    required this.position,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
    required this.rotationSpeed,
  });
}

class CrystalPainter extends CustomPainter {
  final List<CrystalParticle> crystals;
  final double animation;

  CrystalPainter({
    required this.crystals,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var crystal in crystals) {
      // Update position
      crystal.position = Offset(
        crystal.position.dx,
        (crystal.position.dy + crystal.speed * animation) % 1.0,
      );
      
      final x = crystal.position.dx * size.width;
      final y = crystal.position.dy * size.height;
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(animation * crystal.rotationSpeed * 2 * math.pi);
      
      // Draw crystal shape
      final paint = Paint()
        ..color = crystal.color.withOpacity(crystal.opacity)
        ..style = PaintingStyle.fill;
      
      final glowPaint = Paint()
        ..color = crystal.color.withOpacity(crystal.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
      // Draw hexagon crystal
      final path = Path();
      final radius = crystal.size / 2;
      for (int i = 0; i < 6; i++) {
        final angle = (math.pi / 3) * i;
        final px = radius * math.cos(angle);
        final py = radius * math.sin(angle);
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
      
      // Draw glow
      canvas.drawPath(path, glowPaint);
      // Draw crystal
      canvas.drawPath(path, paint);
      
      // Draw inner facets
      final facetPaint = Paint()
        ..color = Colors.white.withOpacity(crystal.opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      
      for (int i = 0; i < 6; i++) {
        final angle = (math.pi / 3) * i;
        final px = radius * math.cos(angle);
        final py = radius * math.sin(angle);
        canvas.drawLine(Offset.zero, Offset(px, py), facetPaint);
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CrystalPainter oldDelegate) => true;
}