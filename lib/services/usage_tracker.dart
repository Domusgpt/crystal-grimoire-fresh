import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Service for tracking API usage and enforcing subscription limits
class UsageTracker {
  static const String _monthlyCountKey = 'monthly_identifications';
  static const String _lastResetKey = 'last_reset_month';
  static const String _subscriptionTierKey = 'subscription_tier';
  static const String _lastUsageKey = 'last_usage_timestamp';
  static const String _totalUsageKey = 'total_identifications';
  static const String _previewUsedKey = 'preview_features_used';
  static const String _premiumIDsUsedKey = 'premium_ids_used';
  static const String _firstInstallKey = 'first_install_date';
  static const String _newUserBonusUsedKey = 'new_user_bonus_used';
  
  /// Checks if user can perform an identification
  static Future<bool> canIdentify() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current subscription tier
      final tier = await getCurrentSubscriptionTier();
      
      // Premium and Pro users have unlimited access
      if (tier != SubscriptionConfig.freeTier) {
        return true;
      }
      
      // Check if new user still has bonus premium IDs
      final bonusRemaining = await getNewUserBonusRemaining();
      if (bonusRemaining > 0) {
        return true;
      }
      
      // Check monthly reset
      await _checkAndResetMonthlyCounter();
      
      // Get current month's usage
      final currentCount = prefs.getInt(_monthlyCountKey) ?? 0;
      
      // Check against free tier limit
      return currentCount < ApiConfig.freeIdentificationsPerMonth;
      
    } catch (e) {
      // Fail open - allow usage if we can't check
      print('Usage check failed: $e');
      return true;
    }
  }
  
  /// Records a successful identification
  static Future<void> recordUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Increment monthly counter
      final currentCount = prefs.getInt(_monthlyCountKey) ?? 0;
      await prefs.setInt(_monthlyCountKey, currentCount + 1);
      
      // Update total usage
      final totalCount = prefs.getInt(_totalUsageKey) ?? 0;
      await prefs.setInt(_totalUsageKey, totalCount + 1);
      
      // Record timestamp
      await prefs.setString(
        _lastUsageKey, 
        DateTime.now().toIso8601String(),
      );
      
    } catch (e) {
      print('Usage recording failed: $e');
    }
  }
  
  /// Increments usage for a specific feature
  static Future<void> incrementUsage(String feature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final featureKey = '${feature}_usage';
      final currentCount = prefs.getInt(featureKey) ?? 0;
      await prefs.setInt(featureKey, currentCount + 1);
      
      // Record timestamp for this feature
      await prefs.setString(
        '${feature}_last_used', 
        DateTime.now().toIso8601String(),
      );
      
    } catch (e) {
      print('Feature usage recording failed for $feature: $e');
    }
  }
  
  /// Gets current usage statistics
  static Future<UsageStats> getUsageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _checkAndResetMonthlyCounter();
      
      final tier = await getCurrentSubscriptionTier();
      final monthlyCount = prefs.getInt(_monthlyCountKey) ?? 0;
      final totalCount = prefs.getInt(_totalUsageKey) ?? 0;
      final previewsUsed = prefs.getInt(_previewUsedKey) ?? 0;
      
      final lastUsageString = prefs.getString(_lastUsageKey);
      DateTime? lastUsage;
      if (lastUsageString != null) {
        lastUsage = DateTime.tryParse(lastUsageString);
      }
      
      int monthlyLimit;
      switch (tier) {
        case SubscriptionConfig.freeTier:
          monthlyLimit = ApiConfig.freeIdentificationsPerMonth;
          break;
        default:
          monthlyLimit = -1; // Unlimited
      }
      
      return UsageStats(
        subscriptionTier: tier,
        monthlyUsage: monthlyCount,
        monthlyLimit: monthlyLimit,
        totalUsage: totalCount,
        previewFeaturesUsed: previewsUsed,
        lastUsage: lastUsage,
        canIdentify: monthlyLimit == -1 || monthlyCount < monthlyLimit,
      );
      
    } catch (e) {
      print('Usage stats retrieval failed: $e');
      return UsageStats(
        subscriptionTier: SubscriptionConfig.freeTier,
        monthlyUsage: 0,
        monthlyLimit: ApiConfig.freeIdentificationsPerMonth,
        totalUsage: 0,
        previewFeaturesUsed: 0,
        lastUsage: null,
        canIdentify: true,
      );
    }
  }
  
  /// Checks if user can access a premium feature
  static Future<bool> canAccessFeature(String featureName) async {
    try {
      final tier = await getCurrentSubscriptionTier();
      final features = SubscriptionConfig.tierFeatures[tier] ?? [];
      
      // Check if feature is included in current tier
      if (features.contains(featureName)) {
        return true;
      }
      
      // Free tier users get one preview of premium features
      if (tier == SubscriptionConfig.freeTier) {
        final prefs = await SharedPreferences.getInstance();
        final previewsUsed = prefs.getInt(_previewUsedKey) ?? 0;
        return previewsUsed < 1;
      }
      
      return false;
      
    } catch (e) {
      print('Feature access check failed: $e');
      return false;
    }
  }
  
  /// Records usage of a premium feature preview
  static Future<void> recordPreviewUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previewsUsed = prefs.getInt(_previewUsedKey) ?? 0;
      await prefs.setInt(_previewUsedKey, previewsUsed + 1);
    } catch (e) {
      print('Preview usage recording failed: $e');
    }
  }
  
  /// Gets current subscription tier
  static Future<String> getCurrentSubscriptionTier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_subscriptionTierKey) ?? SubscriptionConfig.freeTier;
    } catch (e) {
      return SubscriptionConfig.freeTier;
    }
  }
  
  /// Updates subscription tier (called when subscription changes)
  static Future<void> updateSubscriptionTier(String tier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_subscriptionTierKey, tier);
      
      // Reset usage counters for new subscribers
      if (tier != SubscriptionConfig.freeTier) {
        await prefs.remove(_monthlyCountKey);
        await prefs.remove(_lastResetKey);
      }
      
    } catch (e) {
      print('Subscription tier update failed: $e');
    }
  }
  
  /// Resets usage data (for testing or account reset)
  static Future<void> resetUsageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_monthlyCountKey);
      await prefs.remove(_lastResetKey);
      await prefs.remove(_lastUsageKey);
      await prefs.remove(_totalUsageKey);
      await prefs.remove(_previewUsedKey);
    } catch (e) {
      print('Usage data reset failed: $e');
    }
  }
  
  /// Checks and resets monthly counter if needed
  static Future<void> _checkAndResetMonthlyCounter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month}';
      final lastReset = prefs.getString(_lastResetKey);
      
      if (lastReset != currentMonth) {
        // New month - reset counter
        await prefs.setInt(_monthlyCountKey, 0);
        await prefs.setString(_lastResetKey, currentMonth);
      }
    } catch (e) {
      print('Monthly counter reset failed: $e');
    }
  }
  
  /// Gets days until next monthly reset
  static int getDaysUntilReset() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return nextMonth.difference(now).inDays;
  }
  
  /// Checks if user is approaching their monthly limit
  static Future<bool> isApproachingLimit() async {
    final stats = await getUsageStats();
    if (stats.monthlyLimit == -1) return false; // Unlimited
    
    final usageRatio = stats.monthlyUsage / stats.monthlyLimit;
    return usageRatio >= 0.8; // 80% of limit used
  }
  
  /// Gets upgrade recommendation message
  static Future<String?> getUpgradeRecommendation() async {
    final stats = await getUsageStats();
    
    if (stats.subscriptionTier != SubscriptionConfig.freeTier) {
      return null; // Already subscribed
    }
    
    if (stats.monthlyUsage >= stats.monthlyLimit) {
      return 'You\'ve reached your monthly limit! Upgrade for unlimited identifications.';
    }
    
    if (await isApproachingLimit()) {
      final remaining = stats.monthlyLimit - stats.monthlyUsage;
      return 'Only $remaining identifications left this month. Consider upgrading!';
    }
    
    if (stats.totalUsage >= 20) {
      return 'You\'re a crystal enthusiast! Unlock unlimited identifications with Premium.';
    }
    
    return null;
  }

  /// Gets remaining new user bonus premium identifications
  static Future<int> getNewUserBonusRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Initialize first install date if not set
      if (!prefs.containsKey(_firstInstallKey)) {
        await prefs.setString(_firstInstallKey, DateTime.now().toIso8601String());
      }
      
      final bonusUsed = prefs.getInt(_newUserBonusUsedKey) ?? 0;
      const bonusLimit = 5; // 5 free premium IDs for new users
      
      return (bonusLimit - bonusUsed).clamp(0, bonusLimit);
    } catch (e) {
      print('New user bonus check failed: $e');
      return 0;
    }
  }

  /// Records usage of a new user bonus premium identification
  static Future<void> recordNewUserBonusUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bonusUsed = prefs.getInt(_newUserBonusUsedKey) ?? 0;
      await prefs.setInt(_newUserBonusUsedKey, bonusUsed + 1);
    } catch (e) {
      print('New user bonus recording failed: $e');
    }
  }

  /// Determines which AI model tier to use for current user
  static Future<IdentificationTier> getIdentificationTier() async {
    try {
      final tier = await getCurrentSubscriptionTier();
      
      // Pro users get the best models
      if (tier == SubscriptionConfig.proTier || tier == SubscriptionConfig.foundersTier) {
        return IdentificationTier.premium;
      }
      
      // Premium users get mid-tier models
      if (tier == SubscriptionConfig.premiumTier) {
        return IdentificationTier.enhanced;
      }
      
      // Free users - check if they have bonus premium IDs left
      final bonusRemaining = await getNewUserBonusRemaining();
      if (bonusRemaining > 0) {
        return IdentificationTier.premium; // Give new users premium experience
      }
      
      // Regular free tier users get basic models
      return IdentificationTier.basic;
      
    } catch (e) {
      print('Identification tier check failed: $e');
      return IdentificationTier.basic;
    }
  }

  /// Checks if user should get high-accuracy identification
  static Future<bool> shouldUseHighAccuracyModel() async {
    final identificationTier = await getIdentificationTier();
    return identificationTier != IdentificationTier.basic;
  }

  /// Records successful premium identification and manages bonus usage
  static Future<void> recordPremiumUsage() async {
    try {
      // First check if this was a bonus premium ID
      final bonusRemaining = await getNewUserBonusRemaining();
      if (bonusRemaining > 0) {
        await recordNewUserBonusUsage();
      }
      
      // Record standard usage
      await recordUsage();
      
      // Track premium ID usage for analytics
      final prefs = await SharedPreferences.getInstance();
      final premiumUsed = prefs.getInt(_premiumIDsUsedKey) ?? 0;
      await prefs.setInt(_premiumIDsUsedKey, premiumUsed + 1);
      
    } catch (e) {
      print('Premium usage recording failed: $e');
    }
  }

  /// Gets days since first install (for new user determination)
  static Future<int> getDaysSinceInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstInstallString = prefs.getString(_firstInstallKey);
      
      if (firstInstallString == null) {
        // First time - set install date
        await prefs.setString(_firstInstallKey, DateTime.now().toIso8601String());
        return 0;
      }
      
      final firstInstall = DateTime.parse(firstInstallString);
      return DateTime.now().difference(firstInstall).inDays;
    } catch (e) {
      print('Install date check failed: $e');
      return 999; // Assume old user if check fails
    }
  }

  /// Checks if user is still considered "new" (first 7 days)
  static Future<bool> isNewUser() async {
    final daysSinceInstall = await getDaysSinceInstall();
    return daysSinceInstall <= 7;
  }
}

/// Identification quality tiers
enum IdentificationTier {
  basic,    // Gemini Flash - free users after bonus used
  enhanced, // Gemini Pro or GPT-4o-mini - premium users
  premium,  // GPT-4o or Claude 3.5 - pro users and new user bonus
}

/// Usage statistics for display and analytics
class UsageStats {
  final String subscriptionTier;
  final int monthlyUsage;
  final int monthlyLimit; // -1 for unlimited
  final int totalUsage;
  final int previewFeaturesUsed;
  final DateTime? lastUsage;
  final bool canIdentify;
  
  UsageStats({
    required this.subscriptionTier,
    required this.monthlyUsage,
    required this.monthlyLimit,
    required this.totalUsage,
    required this.previewFeaturesUsed,
    this.lastUsage,
    required this.canIdentify,
  });
  
  /// Gets remaining identifications this month
  int get remainingThisMonth {
    if (monthlyLimit == -1) return -1; // Unlimited
    return (monthlyLimit - monthlyUsage).clamp(0, monthlyLimit);
  }
  
  /// Gets usage percentage (0.0 to 1.0)
  double get usagePercentage {
    if (monthlyLimit == -1) return 0.0; // Unlimited
    return (monthlyUsage / monthlyLimit).clamp(0.0, 1.0);
  }
  
  /// Checks if user has premium features
  bool get hasPremiumFeatures {
    return subscriptionTier != SubscriptionConfig.freeTier;
  }
  
  /// Gets tier display name
  String get tierDisplayName {
    switch (subscriptionTier) {
      case SubscriptionConfig.freeTier:
        return 'Free';
      case SubscriptionConfig.premiumTier:
        return 'Premium';
      case SubscriptionConfig.proTier:
        return 'Pro';
      case SubscriptionConfig.foundersTier:
        return 'Founders Edition';
      default:
        return 'Unknown';
    }
  }
  
  /// Gets time since last usage
  String? get timeSinceLastUsage {
    if (lastUsage == null) return null;
    
    final difference = DateTime.now().difference(lastUsage!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
  
  @override
  String toString() {
    return 'UsageStats(tier: $tierDisplayName, '
           'monthly: $monthlyUsage/$monthlyLimit, '
           'total: $totalUsage, canIdentify: $canIdentify)';
  }
}