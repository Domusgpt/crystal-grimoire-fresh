import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'dart:js' as js;

class WebGLParticles extends StatefulWidget {
  final int particleCount;
  final double particleSize;
  final Color color;
  final double speed;
  
  const WebGLParticles({
    super.key,
    this.particleCount = 15,
    this.particleSize = 6.0,
    this.color = const Color(0xFF9333EA),
    this.speed = 0.5,
  });

  @override
  State<WebGLParticles> createState() => _WebGLParticlesState();
}

class _WebGLParticlesState extends State<WebGLParticles> {
  late String canvasId;
  html.CanvasElement? canvas;
  js.JsObject? particleSystem;
  
  @override
  void initState() {
    super.initState();
    canvasId = 'webgl-particles-${DateTime.now().millisecondsSinceEpoch}';
    _createWebGLCanvas();
  }

  void _createWebGLCanvas() {
    // Create HTML5 Canvas element
    canvas = html.CanvasElement()
      ..id = canvasId
      ..style.cssText = '''
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        pointer-events: none;
        z-index: 0;
      ''';
    
    // Register the canvas as a platform view
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      canvasId,
      (int viewId) {
        // Load WebGL particle system script if not already loaded
        if (!_isWebGLScriptLoaded()) {
          _loadWebGLScript();
        }
        
        return canvas!;
      },
    );
  }

  bool _isWebGLScriptLoaded() {
    return js.context.hasProperty('createWebGLParticles');
  }

  void _loadWebGLScript() {
    final script = html.ScriptElement()
      ..src = 'webgl_particles.js'
      ..type = 'text/javascript';
    
    script.onLoad.listen((_) {
      _initializeParticleSystem();
    });
    
    script.onError.listen((_) {
      print('Failed to load WebGL particles script');
    });
    
    html.document.head!.append(script);
  }

  void _initializeParticleSystem() {
    if (!mounted) return;
    
    try {
      // Convert Flutter Color to WebGL RGBA array
      final colorArray = [
        widget.color.red / 255.0,
        widget.color.green / 255.0, 
        widget.color.blue / 255.0,
        widget.color.opacity,
      ];

      // Configure particle system
      final options = js.JsObject.jsify({
        'particleCount': widget.particleCount,
        'particleSize': widget.particleSize,
        'color': colorArray,
        'speed': widget.speed,
      });

      // Create WebGL particle system
      particleSystem = js.context.callMethod('createWebGLParticles', [canvasId, options]);
      
      if (particleSystem == null) {
        print('Failed to create WebGL particle system');
      }
    } catch (e) {
      print('Error initializing WebGL particles: $e');
    }
  }

  @override
  void didUpdateWidget(WebGLParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update particle system configuration if properties changed
    if (particleSystem != null && (
        oldWidget.particleCount != widget.particleCount ||
        oldWidget.particleSize != widget.particleSize ||
        oldWidget.color != widget.color ||
        oldWidget.speed != widget.speed)) {
      
      final colorArray = [
        widget.color.red / 255.0,
        widget.color.green / 255.0,
        widget.color.blue / 255.0,
        widget.color.opacity,
      ];
      
      final newConfig = js.JsObject.jsify({
        'particleCount': widget.particleCount,
        'particleSize': widget.particleSize,
        'color': colorArray,
        'speed': widget.speed,
      });
      
      particleSystem!.callMethod('updateConfig', [newConfig]);
    }
  }

  @override
  void dispose() {
    // Clean up WebGL resources
    particleSystem?.callMethod('destroy');
    canvas?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // WebGL Canvas
        SizedBox.expand(
          child: HtmlElementView(
            viewType: canvasId,
          ),
        ),
        
        // Fallback for when WebGL is loading
        if (particleSystem == null)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  widget.color.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Simplified WebGL particles for better performance
class WebGLSimpleParticles extends StatefulWidget {
  final int particleCount;
  final Color color;
  
  const WebGLSimpleParticles({
    super.key,
    this.particleCount = 8,
    this.color = const Color(0xFF9333EA),
  });

  @override
  State<WebGLSimpleParticles> createState() => _WebGLSimpleParticlesState();
}

class _WebGLSimpleParticlesState extends State<WebGLSimpleParticles> {
  late String canvasId;
  
  @override
  void initState() {
    super.initState();
    canvasId = 'webgl-simple-${DateTime.now().millisecondsSinceEpoch}';
    _createSimpleCanvas();
  }

  void _createSimpleCanvas() {
    final canvas = html.CanvasElement()
      ..id = canvasId
      ..style.cssText = '''
        position: absolute;
        top: 0;
        left: 0; 
        width: 100%;
        height: 100%;
        pointer-events: none;
        z-index: 0;
      ''';
    
    // Register with a simple CSS animation fallback
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      canvasId,
      (int viewId) {
        _addCSSParticles(canvas);
        return canvas;
      },
    );
  }

  void _addCSSParticles(html.CanvasElement canvas) {
    // Create CSS-based particles for maximum compatibility
    final style = html.StyleElement()
      ..text = '''
        @keyframes float-up {
          0% {
            transform: translateY(100vh) translateX(0px);
            opacity: 0;
          }
          10% {
            opacity: 0.8;
          }
          90% {
            opacity: 0.8;
          }
          100% {
            transform: translateY(-20vh) translateX(20px);
            opacity: 0;
          }
        }
        
        .css-particle {
          position: absolute;
          width: 3px;
          height: 3px;
          background: ${_colorToCss(widget.color)};
          border-radius: 50%;
          animation: float-up 25s infinite linear;
          box-shadow: 0 0 6px ${_colorToCss(widget.color)}80;
        }
      ''';
    
    html.document.head!.append(style);
    
    // Create particle elements
    for (int i = 0; i < widget.particleCount; i++) {
      final particle = html.DivElement()
        ..className = 'css-particle'
        ..style.left = '${(i * (100 / widget.particleCount)) % 100}%'
        ..style.animationDelay = '${i * 2}s';
      
      canvas.parent!.append(particle);
    }
  }

  String _colorToCss(Color color) {
    return 'rgba(${color.red}, ${color.green}, ${color.blue}, ${color.opacity})';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: canvasId);
  }
}