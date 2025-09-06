import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../webgl/webgl_renderer.dart';

class WebGLParticleWidget extends StatefulWidget {
  final int particleCount;
  final double speed;
  final double size;
  final double opacity;
  
  const WebGLParticleWidget({
    Key? key,
    this.particleCount = 50,
    this.speed = 1.0,
    this.size = 15.0,
    this.opacity = 0.8,
  }) : super(key: key);

  @override
  State<WebGLParticleWidget> createState() => _WebGLParticleWidgetState();
}

class _WebGLParticleWidgetState extends State<WebGLParticleWidget> {
  WebGLParticleRenderer? _renderer;
  bool _isWebSupported = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeWebGL();
  }
  
  Future<void> _initializeWebGL() async {
    try {
      // Check if we're running on web platform
      if (kIsWeb) {
        // Register the WebGL factory
        registerWebGLFactory();
        
        setState(() {
          _isWebSupported = true;
        });
      } else {
        setState(() {
          _isWebSupported = false;
          _errorMessage = 'WebGL particles only supported on web platform';
        });
      }
    } catch (e) {
      setState(() {
        _isWebSupported = false;
        _errorMessage = 'Failed to initialize WebGL: $e';
      });
    }
  }
  
  @override
  void didUpdateWidget(WebGLParticleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update WebGL renderer configuration when widget properties change
    if (_renderer != null && _isWebSupported) {
      _renderer!.updateConfig({
        'particleCount': widget.particleCount,
        'speed': widget.speed,
        'size': widget.size,
        'opacity': widget.opacity,
      });
    }
  }
  
  @override
  void dispose() {
    _renderer?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWebSupported) {
      return _buildFallback();
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: kIsWeb 
        ? const HtmlElementView(viewType: 'webgl-particles')
        : _buildFallback(),
    );
  }
  
  Widget _buildFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _FallbackParticlePainter(
          particleCount: widget.particleCount,
          time: DateTime.now().millisecondsSinceEpoch / 1000.0,
        ),
      ),
    );
  }
}

// Lightweight fallback painter for non-web platforms
class _FallbackParticlePainter extends CustomPainter {
  final int particleCount;
  final double time;
  
  const _FallbackParticlePainter({
    required this.particleCount,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    final paint = Paint()
      ..color = Colors.purple.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    
    // Draw simple animated particles as fallback
    for (int i = 0; i < (particleCount / 5).round(); i++) {
      final double phase = (i / particleCount) * 6.28;
      final double x = size.width * 0.5 + 
          (size.width * 0.3) * (0.5 + 0.5 * math.sin(phase + time * 0.5));
      final double y = size.height * 0.5 + 
          (size.height * 0.3) * (0.5 + 0.5 * math.cos(phase * 1.3 + time * 0.3));
      
      final double radius = 3 + 2 * math.sin(time + phase).abs();
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = Color.lerp(
          Colors.purple.withOpacity(0.4),
          Colors.blue.withOpacity(0.6),
          math.sin(time + phase) * 0.5 + 0.5,
        )!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}