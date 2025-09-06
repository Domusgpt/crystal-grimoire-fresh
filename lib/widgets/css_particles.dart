import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

class CSSParticles extends StatefulWidget {
  final int particleCount;
  final String particleColor;
  
  const CSSParticles({
    super.key,
    this.particleCount = 20,
    this.particleColor = '#9333ea',
  });

  @override
  State<CSSParticles> createState() => _CSSParticlesState();
}

class _CSSParticlesState extends State<CSSParticles> {
  late String viewId;

  @override
  void initState() {
    super.initState();
    viewId = 'css-particles-${DateTime.now().millisecondsSinceEpoch}';
    _createCSSParticleSystem();
  }

  void _createCSSParticleSystem() {
    // Create HTML element with CSS particle system
    html.DivElement particleContainer = html.DivElement()
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

    // Add CSS for particles
    html.StyleElement style = html.StyleElement()
      ..text = '''
        .particle {
          position: absolute;
          width: 4px;
          height: 4px;
          background: ${widget.particleColor};
          border-radius: 50%;
          opacity: 0.6;
          animation: float 20s infinite linear;
          box-shadow: 0 0 6px ${widget.particleColor}40;
        }
        
        @keyframes float {
          0% {
            transform: translateY(100vh) rotate(0deg);
            opacity: 0;
          }
          10% {
            opacity: 0.6;
          }
          90% {
            opacity: 0.6;
          }
          100% {
            transform: translateY(-10vh) rotate(360deg);
            opacity: 0;
          }
        }
        
        .particle:nth-child(odd) {
          animation-duration: 25s;
          width: 3px;
          height: 3px;
        }
        
        .particle:nth-child(even) {
          animation-duration: 18s;
          width: 5px;
          height: 5px;
        }
      ''';

    html.document.head!.append(style);

    // Create particles
    for (int i = 0; i < widget.particleCount; i++) {
      html.DivElement particle = html.DivElement()
        ..className = 'particle'
        ..style.left = '${(i * (100 / widget.particleCount)) + (i % 3) * 10}%'
        ..style.animationDelay = '${i * 0.5}s';
      
      particleContainer.append(particle);
    }

    // Register the view
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => particleContainer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: viewId);
  }

  @override
  void dispose() {
    // Clean up CSS particles
    html.document.getElementById(viewId)?.remove();
    super.dispose();
  }
}