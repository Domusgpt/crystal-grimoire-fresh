import 'package:flutter/material.dart';
import 'dart:math' as math;

class LightweightParticles extends StatefulWidget {
  final int particleCount;
  final Color color;
  final double maxSize;
  
  const LightweightParticles({
    super.key,
    this.particleCount = 8,
    this.color = const Color(0xFF9333EA),
    this.maxSize = 6.0,
  });

  @override
  State<LightweightParticles> createState() => _LightweightParticlesState();
}

class _LightweightParticlesState extends State<LightweightParticles> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  final List<Particle> _particles = [];
  
  @override
  void initState() {
    super.initState();
    
    // Much slower animation for better performance
    _controller = AnimationController(
      duration: const Duration(seconds: 120), // Very slow
      vsync: this,
    );
    
    _initializeParticles();
    _controller.repeat();
  }
  
  void _initializeParticles() {
    final random = math.Random();
    _particles.clear();
    
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * widget.maxSize + 2,
        speed: random.nextDouble() * 0.001 + 0.0001, // Much slower
        opacity: random.nextDouble() * 0.3 + 0.1,
        phase: random.nextDouble() * 2 * math.pi,
      ));
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: LightweightParticlePainter(
            particles: _particles,
            animationValue: _controller.value,
            color: widget.color,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final double phase;
  
  const Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class LightweightParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final Color color;
  
  // Static paint object for performance
  static final Paint _paint = Paint()
    ..style = PaintingStyle.fill;
  
  LightweightParticlePainter({
    required this.particles,
    required this.animationValue,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      // Calculate position (much simpler math)
      final currentY = (particle.y + particle.speed * animationValue) % 1.0;
      final x = particle.x * size.width;
      final y = currentY * size.height;
      
      // Skip particles outside viewport (performance optimization)
      if (y < -particle.size || y > size.height + particle.size) {
        continue;
      }
      
      // Subtle floating motion using phase
      final floatOffset = math.sin(animationValue * 2 * math.pi + particle.phase) * 10;
      
      _paint.color = color.withOpacity(particle.opacity);
      
      // Draw simple circle (most efficient shape)
      canvas.drawCircle(
        Offset(x + floatOffset, y),
        particle.size / 2,
        _paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(LightweightParticlePainter oldDelegate) {
    // Only repaint if animation progressed significantly
    return (animationValue - oldDelegate.animationValue).abs() > 0.01;
  }
}