import 'package:flutter/material.dart';
import 'dart:math' as math;

class TealRedGemLogo extends StatefulWidget {
  final double size;
  final bool animate;
  
  const TealRedGemLogo({
    Key? key,
    this.size = 100,
    this.animate = true,
  }) : super(key: key);

  @override
  State<TealRedGemLogo> createState() => _TealRedGemLogoState();
}

class _TealRedGemLogoState extends State<TealRedGemLogo>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    if (widget.animate) {
      // Rotation animation - slow, continuous
      _rotationController = AnimationController(
        duration: const Duration(seconds: 4),
        vsync: this,
      )..repeat();
      
      // Pulse animation - subtle breathing effect
      _pulseController = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      )..repeat(reverse: true);
      
      // Shimmer animation - sparkling effect
      _shimmerController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat();
      
      _rotationAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _rotationController,
        curve: Curves.linear,
      ));
      
      _pulseAnimation = Tween<double>(
        begin: 0.95,
        end: 1.05,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));
      
      _shimmerAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ));
    }
  }

  @override
  void dispose() {
    if (widget.animate) {
      _rotationController.dispose();
      _pulseController.dispose();
      _shimmerController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: GemLogoPainter(
          rotationValue: 0.0,
          pulseValue: 1.0,
          shimmerValue: 0.0,
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotationAnimation,
        _pulseAnimation,
        _shimmerAnimation,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF20B2AA).withOpacity(0.3), // Teal glow
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: const Color(0xFFFF4500).withOpacity(0.3), // Red glow
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: GemLogoPainter(
                rotationValue: _rotationAnimation.value,
                pulseValue: _pulseAnimation.value,
                shimmerValue: _shimmerAnimation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class GemLogoPainter extends CustomPainter {
  final double rotationValue;
  final double pulseValue;
  final double shimmerValue;

  GemLogoPainter({
    required this.rotationValue,
    required this.pulseValue,
    required this.shimmerValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;
    
    // Save canvas state for rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationValue * 2 * math.pi);
    canvas.translate(-center.dx, -center.dy);

    // Draw main gem shape (hexagonal)
    _drawMainGem(canvas, center, radius);
    
    // Draw facets for 3D effect
    _drawFacets(canvas, center, radius);
    
    // Draw shimmer/sparkle effects
    _drawShimmerEffect(canvas, center, radius);
    
    // Restore canvas state
    canvas.restore();
  }

  void _drawMainGem(Canvas canvas, Offset center, double radius) {
    // Draw the exact hexagonal gem from the image
    final gemPath = Path();
    
    // Create the main hexagon shape
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180; // Start from top
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        gemPath.moveTo(x, y);
      } else {
        gemPath.lineTo(x, y);
      }
    }
    gemPath.close();

    // Left half - Teal
    final leftHalfPaint = Paint()
      ..color = const Color(0xFF20B2AA)
      ..style = PaintingStyle.fill;
    
    final leftPath = Path();
    leftPath.moveTo(center.dx, center.dy - radius); // Top
    leftPath.lineTo(center.dx - radius * 0.866, center.dy - radius * 0.5); // Top left
    leftPath.lineTo(center.dx - radius * 0.866, center.dy + radius * 0.5); // Bottom left
    leftPath.lineTo(center.dx, center.dy + radius); // Bottom
    leftPath.lineTo(center.dx, center.dy); // Center
    leftPath.close();
    
    canvas.drawPath(leftPath, leftHalfPaint);

    // Right half - Red
    final rightHalfPaint = Paint()
      ..color = const Color(0xFFFF4500)
      ..style = PaintingStyle.fill;
    
    final rightPath = Path();
    rightPath.moveTo(center.dx, center.dy - radius); // Top
    rightPath.lineTo(center.dx + radius * 0.866, center.dy - radius * 0.5); // Top right
    rightPath.lineTo(center.dx + radius * 0.866, center.dy + radius * 0.5); // Bottom right
    rightPath.lineTo(center.dx, center.dy + radius); // Bottom
    rightPath.lineTo(center.dx, center.dy); // Center
    rightPath.close();
    
    canvas.drawPath(rightPath, rightHalfPaint);
    
    // Add the main outline
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawPath(gemPath, outlinePaint);
    
    // Add the center dividing line
    final centerLinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      centerLinePaint,
    );
  }

  void _drawFacets(Canvas canvas, Offset center, double radius) {
    // Draw the inner facet lines to match the image
    final facetPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Top facet lines
    canvas.drawLine(
      Offset(center.dx - radius * 0.866, center.dy - radius * 0.5), // Top left
      Offset(center.dx, center.dy), // Center
      facetPaint,
    );
    
    canvas.drawLine(
      Offset(center.dx + radius * 0.866, center.dy - radius * 0.5), // Top right
      Offset(center.dx, center.dy), // Center
      facetPaint,
    );

    // Bottom facet lines
    canvas.drawLine(
      Offset(center.dx - radius * 0.866, center.dy + radius * 0.5), // Bottom left
      Offset(center.dx, center.dy), // Center
      facetPaint,
    );
    
    canvas.drawLine(
      Offset(center.dx + radius * 0.866, center.dy + radius * 0.5), // Bottom right
      Offset(center.dx, center.dy), // Center
      facetPaint,
    );

    // Add subtle highlight on the left teal side
    final leftHighlight = Paint()
      ..color = Colors.white.withOpacity(0.3 + shimmerValue * 0.2)
      ..style = PaintingStyle.fill;
    
    final leftHighlightPath = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx - radius * 0.4, center.dy - radius * 0.5)
      ..lineTo(center.dx - radius * 0.2, center.dy)
      ..lineTo(center.dx, center.dy)
      ..close();
    
    canvas.drawPath(leftHighlightPath, leftHighlight);

    // Add subtle highlight on the right red side
    final rightHighlight = Paint()
      ..color = Colors.white.withOpacity(0.2 + shimmerValue * 0.3)
      ..style = PaintingStyle.fill;
    
    final rightHighlightPath = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.4, center.dy - radius * 0.5)
      ..lineTo(center.dx + radius * 0.2, center.dy)
      ..lineTo(center.dx, center.dy)
      ..close();
    
    canvas.drawPath(rightHighlightPath, rightHighlight);
  }

  void _drawShimmerEffect(Canvas canvas, Offset center, double radius) {
    // Create sparkle points around the gem
    final sparkleCount = 8;
    final sparklePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i * 45) * math.pi / 180;
      final distance = radius * (1.2 + 0.3 * math.sin(shimmerValue * 2 * math.pi + i));
      final sparkleSize = 2 + math.sin(shimmerValue * 2 * math.pi + i * 0.5) * 2;
      
      final sparkleX = center.dx + distance * math.cos(angle);
      final sparkleY = center.dy + distance * math.sin(angle);
      
      // Draw sparkle as a small diamond
      final sparklePath = Path()
        ..moveTo(sparkleX, sparkleY - sparkleSize)
        ..lineTo(sparkleX + sparkleSize * 0.5, sparkleY)
        ..lineTo(sparkleX, sparkleY + sparkleSize)
        ..lineTo(sparkleX - sparkleSize * 0.5, sparkleY)
        ..close();
      
      final sparkleOpacity = math.max(0.0, math.sin(shimmerValue * 2 * math.pi + i * 0.7));
      sparklePaint.color = Colors.white.withOpacity(sparkleOpacity);
      
      canvas.drawPath(sparklePath, sparklePaint);
    }

    // Add central highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.6 + shimmerValue * 0.4)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(center.dx + radius * 0.2, center.dy - radius * 0.2), 
      radius * 0.15, 
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}