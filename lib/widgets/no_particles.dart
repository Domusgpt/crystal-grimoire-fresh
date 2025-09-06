import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'webgl_particle_widget.dart';

/// GPU-accelerated particle system for web, fallback gradient for other platforms
class SimpleGradientParticles extends StatelessWidget {
  final int particleCount;
  final Color color;
  
  const SimpleGradientParticles({
    super.key,
    this.particleCount = 8,
    this.color = const Color(0xFF9333EA),
  });

  @override
  Widget build(BuildContext context) {
    // Use WebGL on web platform for GPU acceleration
    if (kIsWeb) {
      return Positioned.fill(
        child: WebGLParticleWidget(
          particleCount: particleCount * 6, // Scale up particles with GPU power
          speed: 1.0,
          size: 12.0,
          opacity: 0.7,
        ),
      );
    }
    
    // Fallback to simple gradient for other platforms
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 2.0,
          colors: [
            color.withOpacity(0.03),
            color.withOpacity(0.01),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Even simpler - just a transparent container
class NoParticles extends StatelessWidget {
  final int particleCount;
  final Color color;
  
  const NoParticles({
    super.key,
    this.particleCount = 8,
    this.color = const Color(0xFF9333EA),
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Invisible widget
  }
}