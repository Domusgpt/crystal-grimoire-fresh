// Web-specific implementation for WebGL particles
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class WebGLParticleRenderer {
  html.CanvasElement? _canvas;
  bool _isInitialized = false;
  
  void initialize() {
    if (_isInitialized) return;
    
    try {
      // Create canvas element with modern approach
      _canvas = html.CanvasElement(width: 800, height: 600);
      _canvas!.style.width = '100%';
      _canvas!.style.height = '100%';
      _canvas!.style.display = 'block';
      _canvas!.style.position = 'absolute';
      _canvas!.style.top = '0';
      _canvas!.style.left = '0';
      _canvas!.style.zIndex = '1';
      
      // Use the existing WebGL JavaScript system via interop
      js.context.callMethod('eval', ['''
        if (typeof WebGLParticleSystem !== 'undefined') {
          window.crystalParticles = new WebGLParticleSystem(document.querySelector('canvas'), {
            particleCount: 50,
            particleSize: 15.0,
            speed: 1.0,
            color: [0.6, 0.3, 0.9, 0.8]
          });
        }
      ''']);
      
      _isInitialized = true;
      
    } catch (e) {
      print('WebGL initialization error: $e');
      throw UnsupportedError('Failed to initialize WebGL: $e');
    }
  }
  
  void updateConfig(Map<String, dynamic> config) {
    if (!_isInitialized) return;
    
    try {
      // Update particle system configuration via JavaScript
      final particleCount = config['particleCount'] as int? ?? 50;
      final speed = config['speed'] as double? ?? 1.0;
      final size = config['size'] as double? ?? 15.0;
      
      js.context.callMethod('eval', ['''
        if (window.crystalParticles && window.crystalParticles.updateConfig) {
          window.crystalParticles.updateConfig({
            particleCount: $particleCount,
            speed: $speed,
            size: $size
          });
        }
      ''']);
    } catch (e) {
      print('Error updating WebGL config: $e');
    }
  }
  
  void destroy() {
    try {
      js.context.callMethod('eval', ['''
        if (window.crystalParticles && window.crystalParticles.destroy) {
          window.crystalParticles.destroy();
          window.crystalParticles = null;
        }
      ''']);
    } catch (e) {
      print('Error destroying WebGL particles: $e');
    }
    
    _canvas = null;
    _isInitialized = false;
  }
  
  html.CanvasElement? get canvas => _canvas;
}

void registerWebGLFactory() {
  // Register the HTML element view factory for Flutter Web
  try {
    ui_web.platformViewRegistry.registerViewFactory('webgl-particles', (int viewId) {
      final renderer = WebGLParticleRenderer();
      try {
        renderer.initialize();
        return renderer.canvas!;
      } catch (e) {
        print('Error initializing WebGL renderer: $e');
        // Fallback to a simple div with gradient background
        final div = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.background = '''
            radial-gradient(circle at center, 
              rgba(153, 51, 234, 0.3) 0%, 
              rgba(99, 102, 241, 0.2) 50%, 
              rgba(168, 85, 247, 0.1) 100%)
          '''
          ..style.position = 'relative'
          ..style.overflow = 'hidden';
        
        // Add some CSS animation for the fallback
        final style = html.StyleElement()
          ..text = '''
            @keyframes crystalFloat {
              0%, 100% { transform: translateY(0px) rotate(0deg); }
              33% { transform: translateY(-20px) rotate(120deg); }
              66% { transform: translateY(10px) rotate(240deg); }
            }
            .crystal-particle {
              position: absolute;
              width: 8px;
              height: 8px;
              background: radial-gradient(circle, rgba(255,255,255,0.8) 0%, rgba(153,51,234,0.6) 100%);
              border-radius: 50%;
              animation: crystalFloat 8s ease-in-out infinite;
            }
          ''';
        html.document.head!.append(style);
        
        // Add some animated particles as fallback
        for (int i = 0; i < 5; i++) {
          final particle = html.DivElement()
            ..className = 'crystal-particle'
            ..style.left = '${20 + i * 15}%'
            ..style.top = '${30 + (i % 2) * 40}%'
            ..style.animationDelay = '${i * 1.6}s';
          div.append(particle);
        }
        
        return div;
      }
    });
  } catch (e) {
    print('Error registering WebGL factory: $e');
  }
}