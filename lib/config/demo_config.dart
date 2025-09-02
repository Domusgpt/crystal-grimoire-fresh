/// Demo configuration to protect IP and limit usage
class DemoConfig {
  // Demo limitations
  static const bool isDemoMode = true;
  static const int maxDemoIdentifications = 3;
  static const int maxImagesPerIdentification = 1;
  
  // Demo messages
  static const String demoWatermark = 'DEMO VERSION';
  static const String demoLimitMessage = 
      'You\'ve reached the demo limit of 3 identifications.\n'
      'Contact phillips.paul.email@gmail.com for the full version!';
  
  // Features disabled in demo
  static const bool enableJournal = false;
  static const bool enableSettings = false;
  static const bool enableExport = false;
  static const bool enableSharing = false;
  
  // Demo backend (you can deploy a limited backend)
  static const String demoBackendUrl = 'https://crystal-grimoire-demo.onrender.com';
  
  // Add demo banner to results
  static String addDemoWatermark(String text) {
    return '$text\n\n--- $demoWatermark ---\n'
        'Full version available at phillips.paul.email@gmail.com';
  }
}