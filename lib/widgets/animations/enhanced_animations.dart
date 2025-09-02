import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'mystical_animations.dart';

class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double maxGlowRadius;
  final Duration duration;

  const PulsingGlow({
    Key? key,
    required this.child,
    required this.glowColor,
    this.maxGlowRadius = 20.0,
    this.duration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.3 + _animation.value * 0.4),
                blurRadius: widget.maxGlowRadius * _animation.value,
                spreadRadius: widget.maxGlowRadius * 0.3 * _animation.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

class RotatingCrystal extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;
  final bool reverse;

  const RotatingCrystal({
    Key? key,
    this.size = 60.0,
    this.color = Colors.purple,
    this.duration = const Duration(seconds: 4),
    this.reverse = false,
  }) : super(key: key);

  @override
  State<RotatingCrystal> createState() => _RotatingCrystalState();
}

class _RotatingCrystalState extends State<RotatingCrystal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    
    _rotation = Tween<double>(
      begin: 0.0,
      end: widget.reverse ? -2 * math.pi : 2 * math.pi,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotation.value,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: CrystalPainter(color: widget.color),
          ),
        );
      },
    );
  }
}

class CrystalPainter extends CustomPainter {
  final Color color;

  CrystalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw crystal shape (hexagon)
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi * 2) / 6;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Add gradient effect
    paint.shader = RadialGradient(
      colors: [
        color,
        color.withOpacity(0.7),
        color.withOpacity(0.3),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawPath(path, paint);

    // Add inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final innerRadius = radius * 0.3;
    canvas.drawCircle(center, innerRadius, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WaveAnimation extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration duration;
  final Axis direction;

  const WaveAnimation({
    Key? key,
    required this.child,
    this.amplitude = 10.0,
    this.duration = const Duration(seconds: 3),
    this.direction = Axis.horizontal,
  }) : super(key: key);

  @override
  State<WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<WaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final offset = widget.amplitude * math.sin(_animation.value);
        return Transform.translate(
          offset: widget.direction == Axis.horizontal
              ? Offset(offset, 0)
              : Offset(0, offset),
          child: widget.child,
        );
      },
    );
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Duration delay;
  final VoidCallback? onComplete;

  const TypewriterText({
    Key? key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 50),
    this.delay = Duration.zero,
    this.onComplete,
  }) : super(key: key);

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(
        milliseconds: widget.text.length * widget.duration.inMilliseconds,
      ),
      vsync: this,
    );
    
    _characterCount = StepTween(
      begin: 0,
      end: widget.text.length,
    ).animate(_controller);
    
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward().then((_) {
          if (widget.onComplete != null) {
            widget.onComplete!();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _characterCount,
      builder: (context, child) {
        final visibleText = widget.text.substring(0, _characterCount.value);
        return Text(
          visibleText,
          style: widget.style,
        );
      },
    );
  }
}

class ParallaxBackground extends StatefulWidget {
  final Widget child;
  final List<ParallaxLayer> layers;

  const ParallaxBackground({
    Key? key,
    required this.child,
    required this.layers,
  }) : super(key: key);

  @override
  State<ParallaxBackground> createState() => _ParallaxBackgroundState();
}

class _ParallaxBackgroundState extends State<ParallaxBackground>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = widget.layers.map((layer) {
      return AnimationController(
        duration: layer.duration,
        vsync: this,
      )..repeat();
    }).toList();
    
    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(controller);
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Parallax layers
        ...widget.layers.asMap().entries.map((entry) {
          final index = entry.key;
          final layer = entry.value;
          final animation = _animations[index];
          
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Positioned.fill(
                child: Transform.translate(
                  offset: Offset(
                    animation.value * layer.speed.dx,
                    animation.value * layer.speed.dy,
                  ),
                  child: Opacity(
                    opacity: layer.opacity,
                    child: layer.widget,
                  ),
                ),
              );
            },
          );
        }).toList(),
        
        // Main content
        widget.child,
      ],
    );
  }
}

class ParallaxLayer {
  final Widget widget;
  final Offset speed;
  final double opacity;
  final Duration duration;

  const ParallaxLayer({
    required this.widget,
    required this.speed,
    this.opacity = 1.0,
    this.duration = const Duration(seconds: 10),
  });
}

class MorphingShape extends StatefulWidget {
  final List<ShapeData> shapes;
  final Duration duration;
  final Color color;
  final double size;

  const MorphingShape({
    Key? key,
    required this.shapes,
    this.duration = const Duration(seconds: 3),
    this.color = Colors.purple,
    this.size = 100.0,
  }) : super(key: key);

  @override
  State<MorphingShape> createState() => _MorphingShapeState();
}

class _MorphingShapeState extends State<MorphingShape>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _currentShapeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentShapeIndex = (_currentShapeIndex + 1) % widget.shapes.length;
        });
        _controller.reset();
        _controller.forward();
      }
    });
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: MorphingShapePainter(
            currentShape: widget.shapes[_currentShapeIndex],
            nextShape: widget.shapes[(_currentShapeIndex + 1) % widget.shapes.length],
            progress: _animation.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class ShapeData {
  final List<Offset> points;
  final String name;

  const ShapeData({
    required this.points,
    required this.name,
  });
}

class MorphingShapePainter extends CustomPainter {
  final ShapeData currentShape;
  final ShapeData nextShape;
  final double progress;
  final Color color;

  MorphingShapePainter({
    required this.currentShape,
    required this.nextShape,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Interpolate between current and next shape points
    for (int i = 0; i < currentShape.points.length; i++) {
      final currentPoint = currentShape.points[i];
      final nextPoint = nextShape.points[i % nextShape.points.length];
      
      final interpolatedPoint = Offset.lerp(currentPoint, nextPoint, progress)!;
      final scaledPoint = Offset(
        interpolatedPoint.dx * size.width,
        interpolatedPoint.dy * size.height,
      );
      
      if (i == 0) {
        path.moveTo(scaledPoint.dx, scaledPoint.dy);
      } else {
        path.lineTo(scaledPoint.dx, scaledPoint.dy);
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Predefined shape data for common shapes
class CommonShapes {
  static const circle = ShapeData(
    name: 'circle',
    points: [
      Offset(0.5, 0.0),
      Offset(0.933, 0.25),
      Offset(0.933, 0.75),
      Offset(0.5, 1.0),
      Offset(0.067, 0.75),
      Offset(0.067, 0.25),
    ],
  );
  
  static const hexagon = ShapeData(
    name: 'hexagon',
    points: [
      Offset(0.5, 0.0),
      Offset(0.866, 0.25),
      Offset(0.866, 0.75),
      Offset(0.5, 1.0),
      Offset(0.134, 0.75),
      Offset(0.134, 0.25),
    ],
  );
  
  static const diamond = ShapeData(
    name: 'diamond',
    points: [
      Offset(0.5, 0.0),
      Offset(1.0, 0.5),
      Offset(0.5, 1.0),
      Offset(0.0, 0.5),
      Offset(0.5, 0.0),
      Offset(0.5, 0.0),
    ],
  );
  
  static const star = ShapeData(
    name: 'star',
    points: [
      Offset(0.5, 0.0),
      Offset(0.618, 0.345),
      Offset(0.975, 0.345),
      Offset(0.694, 0.559),
      Offset(0.794, 0.905),
      Offset(0.5, 0.691),
    ],
  );
}