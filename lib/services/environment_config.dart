/// Environment Configuration for Crystal Grimoire Beta0.2
/// Manages API keys, endpoints, and environment settings
/// SECURITY: All API keys are loaded from environment variables only
class EnvironmentConfig {
  static const bool _isProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  
  // API Keys - NEVER hardcode keys in source code
  // Use environment variables or GitHub Secrets for production
  static const String _openAIApiKey = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const String _claudeApiKey = String.fromEnvironment('CLAUDE_API_KEY', defaultValue: '');
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _horoscopeApiKey = String.fromEnvironment('HOROSCOPE_API_KEY', defaultValue: '');
  
  // Firebase Configuration - Production values
  static const String _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const String _firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'crystalgrimoire-production');
  static const String _firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: 'crystalgrimoire-production.firebaseapp.com');
  static const String _firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: 'crystalgrimoire-production.firebasestorage.app');
  static const String _firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '937741022651');
  static const String _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '1:937741022651:web:cf181d053f178c9298c09e');
  
  // Stripe Configuration - Production Live Keys
  static const String _stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');
  static const String _stripeSecretKey = String.fromEnvironment('STRIPE_SECRET_KEY', defaultValue: '');
  static const String _stripePremiumPriceId = String.fromEnvironment('STRIPE_PREMIUM_PRICE_ID', defaultValue: '');
  static const String _stripeProPriceId = String.fromEnvironment('STRIPE_PRO_PRICE_ID', defaultValue: '');
  
  // Getters for production configuration
  bool get isProduction => _isProduction;
  bool get isDevelopment => !_isProduction;
  
  // LLM API Keys
  String get openAIApiKey => _openAIApiKey;
  String get claudeApiKey => _claudeApiKey;
  String get geminiApiKey => _geminiApiKey;
  String get horoscopeApiKey => _horoscopeApiKey;
  
  // Firebase Configuration
  String get firebaseApiKey => _firebaseApiKey;
  String get firebaseProjectId => _firebaseProjectId;
  String get firebaseAuthDomain => _firebaseAuthDomain;
  String get firebaseStorageBucket => _firebaseStorageBucket;
  String get firebaseMessagingSenderId => _firebaseMessagingSenderId;
  String get firebaseAppId => _firebaseAppId;
  
  // Stripe Configuration
  String get stripePublishableKey => _stripePublishableKey;
  String get stripeSecretKey => _stripeSecretKey;
  String get stripePremiumPriceId => _stripePremiumPriceId;
  String get stripeProPriceId => _stripeProPriceId;
  
  // API Endpoints
  String get baseApiUrl => isProduction 
    ? 'https://api.crystalgrimoire.com'
    : 'http://localhost:8080';
    
  String get websiteUrl => isProduction
    ? 'https://crystalgrimoire.com'
    : 'http://localhost:3000';
  
  // Feature Flags
  bool get enableCrystalIdentification => geminiApiKey.isNotEmpty || openAIApiKey.isNotEmpty;
  bool get enableAdvancedGuidance => geminiApiKey.isNotEmpty || claudeApiKey.isNotEmpty || openAIApiKey.isNotEmpty;
  bool get enableMarketplace => stripePublishableKey.isNotEmpty;
  bool get enableDailyHoroscope => horoscopeApiKey.isNotEmpty;
  bool get enableFirebaseAuth => firebaseApiKey.isNotEmpty;
  
  // Configuration validation
  List<String> validateConfiguration() {
    final issues = <String>[];
    
    // Check essential services
    if (openAIApiKey.isEmpty && claudeApiKey.isEmpty && geminiApiKey.isEmpty) {
      issues.add('No LLM API keys configured - AI features will be unavailable');
    }
    
    if (firebaseApiKey.isEmpty) {
      issues.add('Firebase not configured - user data will not persist');
    }
    
    if (stripePublishableKey.isEmpty && isProduction) {
      issues.add('Stripe not configured - premium features will be unavailable');
    }
    
    if (horoscopeApiKey.isEmpty) {
      issues.add('Horoscope API not configured - daily astrology will be unavailable');
    }
    
    return issues;
  }
  
  // Get configuration summary for debugging
  Map<String, dynamic> getConfigSummary() {
    return {
      'environment': isProduction ? 'production' : 'development',
      'base_api_url': baseApiUrl,
      'website_url': websiteUrl,
      'features': {
        'crystal_identification': enableCrystalIdentification,
        'advanced_guidance': enableAdvancedGuidance,
        'marketplace': enableMarketplace,
        'daily_horoscope': enableDailyHoroscope,
        'firebase_auth': enableFirebaseAuth,
      },
      'llm_providers': {
        'openai': openAIApiKey.isNotEmpty ? 'configured' : 'missing',
        'claude': claudeApiKey.isNotEmpty ? 'configured' : 'missing',
        'gemini': geminiApiKey.isNotEmpty ? 'configured' : 'missing',
      },
      'services': {
        'firebase': firebaseApiKey.isNotEmpty ? 'configured' : 'missing',
        'stripe': stripePublishableKey.isNotEmpty ? 'configured' : 'missing',
        'horoscope': horoscopeApiKey.isNotEmpty ? 'configured' : 'missing',
      },
    };
  }
  
  // Singleton pattern for global access
  static EnvironmentConfig? _instance;
  
  EnvironmentConfig._internal();
  
  factory EnvironmentConfig() {
    _instance ??= EnvironmentConfig._internal();
    return _instance!;
  }
  
  // Static helper methods
  static EnvironmentConfig get instance => EnvironmentConfig();
  
  static bool get hasValidConfiguration {
    final config = EnvironmentConfig();
    final issues = config.validateConfiguration();
    return issues.isEmpty || (issues.length == 1 && issues.first.contains('Horoscope'));
  }
  
  static void printConfigurationStatus() {
    final config = EnvironmentConfig();
    final summary = config.getConfigSummary();
    final issues = config.validateConfiguration();
    
    print('\n🔮 Crystal Grimoire Configuration Status');
    print('Environment: ${summary['environment']}');
    print('Base API URL: ${summary['base_api_url']}');
    print('\n🛠 Feature Status:');
    
    final features = summary['features'] as Map<String, dynamic>;
    features.forEach((feature, enabled) {
      final status = enabled ? '✅' : '❌';
      print('  $status ${feature.replaceAll('_', ' ').toUpperCase()}');
    });
    
    print('\n🤖 LLM Providers:');
    final providers = summary['llm_providers'] as Map<String, dynamic>;
    providers.forEach((provider, status) {
      final icon = status == 'configured' ? '✅' : '❌';
      print('  $icon ${provider.toUpperCase()}: $status');
    });
    
    print('\n🔧 Services:');
    final services = summary['services'] as Map<String, dynamic>;
    services.forEach((service, status) {
      final icon = status == 'configured' ? '✅' : '❌';
      print('  $icon ${service.toUpperCase()}: $status');
    });
    
    if (issues.isNotEmpty) {
      print('\n⚠️  Configuration Issues:');
      for (var issue in issues) {
        print('  • $issue');
      }
    } else {
      print('\n✨ All services configured successfully!');
    }
    print('');
  }
}