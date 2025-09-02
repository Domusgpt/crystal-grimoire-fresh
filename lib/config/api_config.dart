class ApiConfig {
  // 🌟 AI PROVIDER CONFIGURATION - CHOOSE YOUR PROVIDER!
  
  // GOOGLE GEMINI (FREE TIER AVAILABLE!)
  // Get your FREE API key at: https://makersuite.google.com/app/apikey
  // ✨ RECOMMENDED FOR TESTING - Generous free tier with vision support!
  static const String geminiApiKey = 'AIzaSyB7ly1Cpev3g6aMivrGwYpxXqzE73KGxx4';
  
  // OpenAI Configuration
  // Get API key at: https://platform.openai.com/api-keys
  static const String openaiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String openaiBaseUrl = 'https://api.openai.com/v1';
  static const String gptModel = 'gpt-4o-mini'; // Cheaper than gpt-4o
  
  // GROQ (FAST & FREE TIER!)
  // Get your FREE API key at: https://console.groq.com/keys
  // Note: No vision support yet, but great for text-based spiritual guidance
  static const String groqApiKey = 'YOUR_GROQ_API_KEY_HERE';
  
  // Anthropic Claude Configuration
  // Get API key at: https://console.anthropic.com/
  static const String claudeApiKey = 'YOUR_CLAUDE_API_KEY_HERE';
  
  // Default AI Provider (change this to switch providers)
  static const String defaultProvider = 'gemini'; // Options: 'gemini', 'openai', 'groq', 'claude'
  
  // API limits
  static const int maxTokens = 2000;
  static const double temperature = 0.7;
  static const int maxImagesPerRequest = 5;
  static const int imageQuality = 85; // JPEG quality
  
  // Free tier limits (with ads)
  static const int freeIdentificationsPerMonth = 4;  // Reduced from 10
  static const int freeMaxImagesPerID = 2;           // Reduced from 3
  static const int freeJournalEntries = 0;           // Locked behind paywall
  
  // Premium tier limits
  static const int premiumMaxImagesPerID = 5;
  static const int proMaxImagesPerID = 10;
  
  // Cache settings
  static const int cacheExpirationDays = 30;
  
  // Rate limiting
  static const Duration rateLimitCooldown = Duration(seconds: 5);
  
  // Error messages
  static const String networkError = 'Unable to connect. Please check your internet connection.';
  static const String apiError = 'Our crystal advisor is currently meditating. Please try again.';
  static const String quotaExceeded = 'You\'ve reached your monthly identification limit. Upgrade for unlimited access!';
  static const String invalidApiKey = 'API configuration error. Please check your API key in settings.';
  
  // Mystical loading messages
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
  
  static String getRandomLoadingMessage() {
    return loadingMessages[(DateTime.now().millisecondsSinceEpoch ~/ 1000) % loadingMessages.length];
  }
}

class SubscriptionConfig {
  // Subscription tiers
  static const String freeTier = 'free';
  static const String premiumTier = 'premium';
  static const String proTier = 'pro';
  static const String foundersTier = 'founders';
  
  // Pricing
  static const Map<String, double> monthlyPrices = {
    premiumTier: 8.99,
    proTier: 19.99,
  };
  
  static const Map<String, double> annualPrices = {
    premiumTier: 95.99, // 20% off
    proTier: 191.99,    // 20% off
  };
  
  static const double foundersPrice = 499.0;
  static const int foundersLimit = 1000;
  
  // Feature flags - Updated tier structure
  static const Map<String, List<String>> tierFeatures = {
    freeTier: [
      'basic_identification',      // 4 per month with Gemini 2.0 Flash
      'crystal_database_access',   // Basic crystal information
      'community_support',        // Forum only
      'ad_supported',             // Ads shown
    ],
    premiumTier: [
      'unlimited_identification',  // No limits with enhanced models
      'crystal_journal',          // Personal crystal collection
      'crystal_grid_designer',    // Grid creation tools
      'upgraded_ai_model',        // Gemini-1.5-pro
      'spiritual_advisor_chat',   // AI guidance and chat
      'birth_chart_integration',  // Astrological features
      'meditation_patterns',      // Guided meditations
      'dream_journal_analyzer',   // Dream interpretation
      'ad_free_experience',       // No ads
    ],
    proTier: [
      'all_premium_features',
      'premium_ai_models',        // GPT-4o, Claude-3.5-sonnet
      'crystal_ai_oracle',        // Advanced AI divination
      'moon_ritual_planner',      // Lunar ceremony planning
      'energy_healing_sessions',  // Guided healing protocols
      'astro_crystal_matcher',    // Advanced astrological matching
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
      'developer_dashboard',      // Technical configuration access
    ],
  };
}

// Quick Start Guide for Developers:
// 
// 1. GOOGLE GEMINI (Recommended for testing - FREE!):
//    - Go to https://makersuite.google.com/app/apikey
//    - Click "Create API key"
//    - Copy the key and paste it above in geminiApiKey
//    - That's it! The app will use Gemini by default
//
// 2. GROQ (Alternative - Also FREE!):
//    - Go to https://console.groq.com/keys
//    - Sign up and create an API key
//    - Note: Groq doesn't support images yet, but it's super fast for text
//
// 3. OpenAI (Paid but reliable):
//    - Go to https://platform.openai.com/api-keys
//    - Create an API key (requires payment method)
//    - Use gpt-4o-mini for cheaper pricing
//
// To switch providers, change defaultProvider above!