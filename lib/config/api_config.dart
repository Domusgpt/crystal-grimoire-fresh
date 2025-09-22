import '../services/environment_config.dart';

class ApiConfig {
  static EnvironmentConfig get _env => EnvironmentConfig.instance;

  // Provider credentials are resolved from the runtime environment.
  static String get geminiApiKey => _env.geminiApiKey;
  static String get openaiApiKey => _env.openAIApiKey;
  static String get claudeApiKey => _env.claudeApiKey;
  static String get groqApiKey => _env.groqApiKey;

  static String get defaultProvider => _env.aiDefaultProvider;

  static String get openaiBaseUrl => _env.openAIBaseUrl;
  static const String claudeBaseUrl = 'https://api.anthropic.com/v1/messages';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String replicateBaseUrl = 'https://api.replicate.com/v1/predictions';
  static const String gptModel = 'gpt-4o-mini';

  static const int maxTokens = 2000;
  static const double temperature = 0.7;
  static const int maxImagesPerRequest = 5;
  static const int imageQuality = 85;

  static const int freeIdentificationsPerMonth = 4;
  static const int freeMaxImagesPerID = 2;
  static const int freeJournalEntries = 0;

  static const int premiumMaxImagesPerID = 5;
  static const int proMaxImagesPerID = 10;

  static const int cacheExpirationDays = 30;
  static const Duration rateLimitCooldown = Duration(seconds: 5);

  static const String networkError =
      'Unable to connect. Please check your internet connection.';
  static const String apiError =
      'Our crystal advisor is currently meditating. Please try again.';
  static const String quotaExceeded =
      'You\'ve reached your monthly identification limit. Upgrade for unlimited access!';
  static const String invalidApiKey =
      'API configuration error. Please check your API key in settings.';

  static const List<String> loadingMessages = [
    'Consulting the crystal matrix...',
    'Attuning to mystical frequencies...',
    'Channeling ancient wisdom...',
    'Reading the crystal\'s energy signature...',
    'Connecting with spiritual guides...',
    'Unlocking crystalline secrets...',
    'Harmonizing with cosmic vibrations...',
    'Accessing the Akashic records...',
  ];

  static bool get hasConfiguredProvider =>
      geminiApiKey.isNotEmpty ||
      openaiApiKey.isNotEmpty ||
      claudeApiKey.isNotEmpty ||
      groqApiKey.isNotEmpty;

  static String getRandomLoadingMessage() {
    return loadingMessages[
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) % loadingMessages.length];
  }
}

class SubscriptionConfig {
  static const String freeTier = 'free';
  static const String premiumTier = 'premium';
  static const String proTier = 'pro';
  static const String foundersTier = 'founders';

  static const Map<String, double> monthlyPrices = {
    premiumTier: 8.99,
    proTier: 19.99,
  };

  static const Map<String, double> annualPrices = {
    premiumTier: 95.99,
    proTier: 191.99,
  };

  static const double foundersPrice = 499.0;
  static const int foundersLimit = 1000;

  static const Map<String, List<String>> tierFeatures = {
    freeTier: [
      'basic_identification',
      'crystal_database_access',
      'community_support',
      'ad_supported',
    ],
    premiumTier: [
      'unlimited_identification',
      'crystal_journal',
      'crystal_grid_designer',
      'upgraded_ai_model',
      'spiritual_advisor_chat',
      'birth_chart_integration',
      'meditation_patterns',
      'dream_journal_analyzer',
      'ad_free_experience',
    ],
    proTier: [
      'all_premium_features',
      'premium_ai_models',
      'crystal_ai_oracle',
      'moon_ritual_planner',
      'energy_healing_sessions',
      'astro_crystal_matcher',
      'priority_support',
      'api_access',
      'beta_features',
      'advanced_analytics',
    ],
    foundersTier: [
      'all_pro_features',
      'lifetime_access',
      'early_access',
      'founders_badge',
      'dev_channel',
      'custom_training',
      'developer_dashboard',
    ],
  };
}
