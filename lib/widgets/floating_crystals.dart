import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class FloatingCrystals extends StatefulWidget {
  final int crystalCount;
  final double maxSize;
  
  const FloatingCrystals({
    super.key,
    this.crystalCount = 5,    // Further reduced for performance
    this.maxSize = 30,        // Smaller size for less overdraw
  });

  @override
  State<FloatingCrystals> createState() => _FloatingCrystalsState();
}

class _FloatingCrystalsState extends State<FloatingCrystals> with TickerProviderStateMixin {
  final List<CrystalParticle> crystals = [];
  late AnimationController _animationController;
  double _lastUpdateTime = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 60), // Much slower for better performance
      vsync: this,
    )..repeat();
    
    _initializeCrystals();
  }

  void _initializeCrystals() {
    final random = math.Random();
    for (int i = 0; i < widget.crystalCount; i++) {
      crystals.add(CrystalParticle(
        initialX: random.nextDouble(),
        initialY: random.nextDouble(),
        size: random.nextDouble() * widget.maxSize + 15,
        speed: random.nextDouble() * 0.008 + 0.002, // Much slower
        opacity: random.nextDouble() * 0.2 + 0.05,  // More subtle
        color: [
          AppTheme.amethystPurple,
          AppTheme.cosmicPurple,
          AppTheme.mysticPink,
          AppTheme.holoBlue,
        ][random.nextInt(4)],
        rotationSpeed: random.nextDouble() * 0.5 - 0.25, // Much slower rotation
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
        // Throttle updates to ~20fps for better performance
        final currentTime = _animationController.value;
        if ((currentTime - _lastUpdateTime).abs() > 0.05) {
          _updateCrystalPositions();
          _lastUpdateTime = currentTime;
        }
        
        return CustomPaint(
          painter: CrystalPainter(
            crystals: crystals,
          ),
          size: Size.infinite,
        );
      },
    );
  }

  void _updateCrystalPositions() {
    final time = _animationController.value;
    for (var crystal in crystals) {
      // Pre-calculate positions to avoid expensive calculations in paint
      crystal.currentX = crystal.initialX;
      crystal.currentY = (crystal.initialY + crystal.speed * time) % 1.0;
      crystal.currentRotation = time * crystal.rotationSpeed * 2 * math.pi;
    }
  }
}

class CrystalParticle {
  final double initialX;
  final double initialY;
  final double size;
  final double speed;
  final double opacity;
  final Color color;
  final double rotationSpeed;
  
  // Pre-calculated values updated outside paint method
  late double currentX;
  late double currentY;
  late double currentRotation;

  CrystalParticle({
    required this.initialX,
    required this.initialY,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
    required this.rotationSpeed,
  }) {
    currentX = initialX;
    currentY = initialY;
    currentRotation = 0.0;
  }
}

class CrystalPainter extends CustomPainter {
  final List<CrystalParticle> crystals;
  
  // Cache paint objects and paths for maximum performance
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5; // Thinner stroke for better performance
    
  // Pre-built path for all crystals (static shape)
  static final Path _crystalPath = Path()
    ..moveTo(0, -1)
    ..lineTo(0.4, 0)
    ..lineTo(0, 1)
    ..lineTo(-0.4, 0)
    ..close();

  CrystalPainter({required this.crystals});

  @override
  void paint(Canvas canvas, Size size) {
    // Only paint visible crystals (simple bounds check)
    for (var crystal in crystals) {
      final x = crystal.currentX * size.width;
      final y = crystal.currentY * size.height;
      
      // Skip crystals outside visible area (with small buffer)
      if (x < -crystal.size || x > size.width + crystal.size ||
          y < -crystal.size || y > size.height + crystal.size) {
        continue;
      }
      
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(crystal.size / 2); // Scale the unit path
      canvas.rotate(crystal.currentRotation);
      
      // Set colors once per crystal
      _fillPaint.color = crystal.color.withOpacity(crystal.opacity);
      _strokePaint.color = Colors.white.withOpacity(crystal.opacity * 0.2);
      
      // Draw using pre-built path (much faster than creating new paths)
      canvas.drawPath(_crystalPath, _fillPaint);
      
      // Simple inner line (only if crystal is large enough to matter)
      if (crystal.size > 20) {
        canvas.drawLine(
          const Offset(0, -0.6), 
          const Offset(0, 0.6), 
          _strokePaint,
        );
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CrystalPainter oldDelegate) {
    // Always repaint since we're managing updates externally
    return true;
  }
}