import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import 'glassmorphic_container.dart';

class HolographicButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final IconData? icon;
  
  const HolographicButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width = double.infinity,
    this.height = 60,
    this.icon,
  });

  @override
  State<HolographicButton> createState() => _HolographicButtonState();
}

class _HolographicButtonState extends State<HolographicButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width,
        height: widget.height,
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.95 : 1.0),
        child: Stack(
          children: [
            // Glassmorphic background
            GlassmorphicContainer(
              borderRadius: 30,
              blur: 20,
              opacity: 0.2,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.amethystPurple.withOpacity(0.3),
                  AppTheme.cosmicPurple.withOpacity(0.2),
                ],
              ),
              border: Border.all(
                color: AppTheme.crystalGlow.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.amethystPurple.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
              child: Container(),
            ),
            
            // Holographic shimmer effect
            AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: CustomPaint(
                    painter: HolographicPainter(
                      shimmerPosition: _shimmerAnimation.value,
                    ),
                    size: Size(widget.width, widget.height),
                  ),
                );
              },
            ),
            
            // Button content
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: AppTheme.crystalGlow,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                  ],
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: _isPressed
                            ? [AppTheme.holoPink, AppTheme.holoBlue]
                            : [AppTheme.crystalGlow, AppTheme.mysticPink],
                      ).createShader(bounds);
                    },
                    child: Text(
                      widget.text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HolographicPainter extends CustomPainter {
  final double shimmerPosition;
  
  HolographicPainter({required this.shimmerPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + shimmerPosition, 0),
        end: Alignment(-1 + shimmerPosition + 0.3, 0),
        colors: [
          Colors.transparent,
          AppTheme.holoBlue.withOpacity(0.3),
          AppTheme.holoPink.withOpacity(0.3),
          AppTheme.holoYellow.withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(HolographicPainter oldDelegate) {
    return oldDelegate.shimmerPosition != shimmerPosition;
  }
}