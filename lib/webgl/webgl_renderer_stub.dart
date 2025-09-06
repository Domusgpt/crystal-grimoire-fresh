// Stub implementation for non-web platforms

class WebGLParticleRenderer {
  void initialize() {
    throw UnsupportedError('WebGL particles are only supported on web platforms');
  }
  
  void destroy() {}
  
  void updateConfig(Map<String, dynamic> config) {}
}

void registerWebGLFactory() {
  throw UnsupportedError('WebGL is only supported on web platforms');
}