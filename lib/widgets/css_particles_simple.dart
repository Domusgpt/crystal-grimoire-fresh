import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

class CSSParticlesSimple extends StatefulWidget {
  final int particleCount;
  final Color color;
  
  const CSSParticlesSimple({
    super.key,
    this.particleCount = 8,
    this.color = const Color(0xFF9333EA),
  });

  @override
  State<CSSParticlesSimple> createState() => _CSSParticlesSimpleState();
}

class _CSSParticlesSimpleState extends State<CSSParticlesSimple> {
  late String viewId;
  bool _viewRegistered = false;

  @override
  void initState() {
    super.initState();
    viewId = 'css-particles-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  void _registerView() {
    if (_viewRegistered) return;
    
    try {
      // Create the particle container
      final container = html.DivElement()
        ..id = viewId
        ..style.cssText = '''
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          pointer-events: none;
          overflow: hidden;
          z-index: 0;
        ''';

      // Add CSS for the particles
      _addParticleCSS();
      
      // Create particles
      _createParticles(container);

      // Register the view factory
      ui.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => container,
      );
      
      _viewRegistered = true;
    } catch (e) {
      print('Failed to register CSS particles view: $e');
      // Fallback will be handled in build method
    }
  }

  void _addParticleCSS() {
    final styleId = 'particle-style-$viewId';
    
    // Remove existing style if it exists
    html.document.getElementById(styleId)?.remove();
    
    final style = html.StyleElement()
      ..id = styleId
      ..text = '''
        .particle-$viewId {
          position: absolute;
          width: 3px;
          height: 3px;
          background: ${_colorToCSS(widget.color)};
          border-radius: 50%;
          opacity: 0.7;
          animation: particle-float-$viewId 20s infinite linear;
          box-shadow: 0 0 4px ${_colorToCSS(widget.color)}40;
        }
        
        @keyframes particle-float-$viewId {
          0% {
            transform: translateY(100vh) translateX(0px) scale(0.5);
            opacity: 0;
          }
          10% {
            opacity: 0.7;
            transform: translateY(90vh) translateX(5px) scale(1);
          }
          90% {
            opacity: 0.7;
            transform: translateY(10vh) translateX(-5px) scale(1);
          }
          100% {
            transform: translateY(-10vh) translateX(10px) scale(0.5);
            opacity: 0;
          }
        }
        
        .particle-$viewId:nth-child(odd) {
          animation-duration: 25s;
          width: 2px;
          height: 2px;
        }
        
        .particle-$viewId:nth-child(even) {
          animation-duration: 18s;
          width: 4px;
          height: 4px;
        }
        
        .particle-$viewId:nth-child(3n) {
          animation-duration: 22s;
          animation-delay: -5s;
        }
      ''';

    html.document.head!.append(style);
  }

  void _createParticles(html.DivElement container) {
    for (int i = 0; i < widget.particleCount; i++) {
      final particle = html.DivElement()
        ..className = 'particle-$viewId'
        ..style.left = '${(i * (100 / widget.particleCount)) + (i % 5) * 2}%'
        ..style.animationDelay = '${i * 1.5}s';
      
      container.append(particle);
    }
  }

  String _colorToCSS(Color color) {
    return 'rgba(${color.red}, ${color.green}, ${color.blue}, ${color.opacity})';
  }

  @override
  void dispose() {
    // Clean up
    final styleId = 'particle-style-$viewId';
    html.document.getElementById(styleId)?.remove();
    html.document.getElementById(viewId)?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_viewRegistered) {
      // Fallback gradient background
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              widget.color.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
        ),
      );
    }
    
    return HtmlElementView(viewType: viewId);
  }
}

/// Ultra-simple fallback for maximum compatibility
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
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 2.0,
          colors: [
            color.withOpacity(0.05),
            color.withOpacity(0.02),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}