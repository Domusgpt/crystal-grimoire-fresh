// Conditional export based on platform
// This file provides a unified interface for WebGL particles across platforms

export 'webgl_renderer_stub.dart' // Stub implementation for non-web platforms
  if (dart.library.html) 'webgl_renderer_web.dart'; // Web implementation