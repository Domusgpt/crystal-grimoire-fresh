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
  static const String _groqApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String _horoscopeApiKey = String.fromEnvironment('HOROSCOPE_API_KEY', defaultValue: '');
  static const String _revenueCatApiKey = String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: '');
  static const String _aiDefaultProvider =
      String.fromEnvironment('AI_DEFAULT_PROVIDER', defaultValue: 'gemini');
  static const String _openAIBaseUrl =
      String.fromEnvironment('OPENAI_BASE_URL', defaultValue: 'https://api.openai.com/v1');
  
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
  static const String _stripePremiumPriceId =
      String.fromEnvironment('STRIPE_PREMIUM_PRICE_ID', defaultValue: '');
  static const String _stripeProPriceId =
      String.fromEnvironment('STRIPE_PRO_PRICE_ID', defaultValue: '');
  static const String _stripeFoundersPriceId =
      String.fromEnvironment('STRIPE_FOUNDERS_PRICE_ID', defaultValue: '');

  // AdMob configuration
  static const String _admobAndroidBannerId = String.fromEnvironment('ADMOB_ANDROID_BANNER_ID', defaultValue: '');
  static const String _admobIosBannerId = String.fromEnvironment('ADMOB_IOS_BANNER_ID', defaultValue: '');
  static const String _admobAndroidInterstitialId =
      String.fromEnvironment('ADMOB_ANDROID_INTERSTITIAL_ID', defaultValue: '');
  static const String _admobIosInterstitialId =
      String.fromEnvironment('ADMOB_IOS_INTERSTITIAL_ID', defaultValue: '');
  static const String _admobAndroidRewardedId =
      String.fromEnvironment('ADMOB_ANDROID_REWARDED_ID', defaultValue: '');
  static const String _admobIosRewardedId =
      String.fromEnvironment('ADMOB_IOS_REWARDED_ID', defaultValue: '');
  static const String _admobTestDeviceIds =
      String.fromEnvironment('ADMOB_TEST_DEVICE_IDS', defaultValue: '');

  // Web + support configuration
  static const String _backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: '');
  static const bool _useLocalBackend =
      bool.fromEnvironment('USE_LOCAL_BACKEND', defaultValue: false);
  static const String _termsUrl = String.fromEnvironment('TERMS_URL', defaultValue: '');
  static const String _privacyUrl = String.fromEnvironment('PRIVACY_URL', defaultValue: '');
  static const String _supportUrl = String.fromEnvironment('SUPPORT_URL', defaultValue: '');
  static const String _supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@crystalgrimoire.com');
  
  // Getters for production configuration
  bool get isProduction => _isProduction;
  bool get isDevelopment => !_isProduction;
  
  // LLM API Keys
  String get openAIApiKey => _openAIApiKey;
  String get claudeApiKey => _claudeApiKey;
  String get geminiApiKey => _geminiApiKey;
  String get groqApiKey => _groqApiKey;
  String get horoscopeApiKey => _horoscopeApiKey;
  String get revenueCatApiKey => _revenueCatApiKey;
  String get aiDefaultProvider => _aiDefaultProvider;
  String get openAIBaseUrl => _openAIBaseUrl;
  
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
  String get stripeFoundersPriceId => _stripeFoundersPriceId;

  // AdMob configuration
  String get admobAndroidBannerId => _admobAndroidBannerId;
  String get admobIosBannerId => _admobIosBannerId;
  String get admobAndroidInterstitialId => _admobAndroidInterstitialId;
  String get admobIosInterstitialId => _admobIosInterstitialId;
  String get admobAndroidRewardedId => _admobAndroidRewardedId;
  String get admobIosRewardedId => _admobIosRewardedId;
  List<String> get adTestDeviceIds => _admobTestDeviceIds
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  // Backend + Support configuration
  String get backendUrl => _backendUrl;
  bool get useLocalBackend => _useLocalBackend;
  String get termsUrl =>
      _termsUrl.isNotEmpty ? _termsUrl : '${_trimTrailingSlash(websiteUrl)}/legal/terms';
  String get privacyUrl => _privacyUrl.isNotEmpty
      ? _privacyUrl
      : '${_trimTrailingSlash(websiteUrl)}/legal/privacy';
  String get supportUrl =>
      _supportUrl.isNotEmpty ? _supportUrl : '${_trimTrailingSlash(websiteUrl)}/support';
  String get supportEmail => _supportEmail;
  
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

    if (revenueCatApiKey.isEmpty) {
      issues.add('RevenueCat API key not configured - mobile subscription purchases will be disabled');
    }

    if (isProduction &&
        (admobAndroidBannerId.isEmpty ||
            admobIosBannerId.isEmpty ||
            admobAndroidInterstitialId.isEmpty ||
            admobIosInterstitialId.isEmpty)) {
      issues.add('AdMob ad unit IDs missing - ads will fall back to Google test units');
    }

    return issues;
  }

  String _trimTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
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
      'ads': {
        'android_banner': admobAndroidBannerId.isNotEmpty ? 'configured' : 'using_test_id',
        'ios_banner': admobIosBannerId.isNotEmpty ? 'configured' : 'using_test_id',
        'android_interstitial': admobAndroidInterstitialId.isNotEmpty ? 'configured' : 'using_test_id',
        'ios_interstitial': admobIosInterstitialId.isNotEmpty ? 'configured' : 'using_test_id',
        'android_rewarded': admobAndroidRewardedId.isNotEmpty ? 'configured' : 'using_test_id',
        'ios_rewarded': admobIosRewardedId.isNotEmpty ? 'configured' : 'using_test_id',
        'test_devices': adTestDeviceIds.isNotEmpty ? adTestDeviceIds : 'not_set',
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
        'revenuecat': revenueCatApiKey.isNotEmpty ? 'configured' : 'missing',
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