import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/birth_chart.dart';

class StorageService {
  static const String _birthChartKey = 'birth_chart';
  static const String _subscriptionKey = 'subscription_tier';
  static const String _aiProviderKey = 'ai_provider';
  static const String _usageKey = 'usage_stats';
  static const String _foundersAccountKey = 'founders_account_enabled';
  static const String _metaphysicalQueriesKey = 'metaphysical_queries';
  static const String _queryDateKey = 'query_date';
  static const String _userProfileKey = 'user_profile';
  static const String _adMetricsKey = 'ad_metrics';
  static const String _settingsSnapshotKey = 'user_settings_snapshot';
  static const String _planSnapshotKey = 'user_plan_snapshot';
  
  bool _isInitialized = false;
  
  // Birth Chart
  static Future<void> saveBirthChart(Map<String, dynamic> chartData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_birthChartKey, json.encode(chartData));
  }
  
  static Future<Map<String, dynamic>?> getBirthChart() async {
    final prefs = await SharedPreferences.getInstance();
    final chartString = prefs.getString(_birthChartKey);
    if (chartString != null) {
      return json.decode(chartString) as Map<String, dynamic>;
    }
    return null;
  }
  
  static Future<void> deleteBirthChart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_birthChartKey);
  }
  
  // Subscription
  static Future<void> saveSubscriptionTier(String tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subscriptionKey, tier);
  }
  
  static Future<String> getSubscriptionTier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_subscriptionKey) ?? 'free';
  }
  
  // AI Provider
  static Future<void> saveAIProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiProviderKey, provider);
  }
  
  static Future<String> getAIProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_aiProviderKey) ?? 'gemini';
  }
  
  // Usage Statistics
  static Future<void> saveUsageStats(Map<String, dynamic> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usageKey, json.encode(stats));
  }
  
  static Future<Map<String, dynamic>> getUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsString = prefs.getString(_usageKey);
    if (statsString != null) {
      return json.decode(statsString) as Map<String, dynamic>;
    }
    return {
      'identifications': 0,
      'lastReset': DateTime.now().toIso8601String(),
    };
  }
  
  static Future<void> incrementIdentifications() async {
    final stats = await getUsageStats();
    stats['identifications'] = (stats['identifications'] as int) + 1;
    await saveUsageStats(stats);
  }

  static Future<int> getDailyIdentifications() async {
    final stats = await getUsageStats();
    return stats['identifications'] as int? ?? 0;
  }
  
  static Future<void> resetMonthlyUsage() async {
    await saveUsageStats({
      'identifications': 0,
      'lastReset': DateTime.now().toIso8601String(),
    });
  }

  // Settings snapshot helpers
  static Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsSnapshotKey, json.encode(settings));
  }

  static Future<Map<String, dynamic>?> getUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_settingsSnapshotKey);
    if (jsonStr == null) {
      return null;
    }

    try {
      final decoded = json.decode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      print('Failed to decode cached settings: $e');
      return null;
    }
  }

  static Future<void> clearUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsSnapshotKey);
  }

  // Plan snapshot helpers
  static Future<void> savePlanSnapshot(Map<String, dynamic> plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planSnapshotKey, json.encode(plan));
  }

  static Future<Map<String, dynamic>?> getPlanSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_planSnapshotKey);
    if (jsonStr == null) {
      return null;
    }

    try {
      final decoded = json.decode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      print('Failed to decode cached plan snapshot: $e');
      return null;
    }
  }

  static Future<void> clearPlanSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_planSnapshotKey);
  }
  
  // Founders Account Management
  static Future<void> enableFoundersAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_foundersAccountKey, true);
    // Automatically upgrade to founders tier
    await saveSubscriptionTier('founders');
  }
  
  static Future<bool> isFoundersAccountEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_foundersAccountKey) ?? false;
  }
  
  static Future<void> disableFoundersAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_foundersAccountKey, false);
    // Revert to free tier
    await saveSubscriptionTier('free');
  }
  
  // Metaphysical Query Tracking
  static Future<int> getDailyMetaphysicalQueries() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final lastQueryDate = prefs.getString(_queryDateKey) ?? '';
    
    if (lastQueryDate != today) {
      // Reset counter for new day
      await prefs.setInt(_metaphysicalQueriesKey, 0);
      await prefs.setString(_queryDateKey, today);
      return 0;
    }
    
    return prefs.getInt(_metaphysicalQueriesKey) ?? 0;
  }
  
  static Future<void> incrementMetaphysicalQueries() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = await getDailyMetaphysicalQueries();
    await prefs.setInt(_metaphysicalQueriesKey, currentCount + 1);
  }
  
  static Future<bool> canMakeMetaphysicalQuery() async {
    final subscriptionTier = await getSubscriptionTier();
    final currentQueries = await getDailyMetaphysicalQueries();
    
    switch (subscriptionTier) {
      case 'free':
        return false; // No metaphysical queries for free tier
      case 'premium':
        return false; // Premium doesn't have metaphysical queries
      case 'pro':
        return currentQueries < 5; // 5 queries per day for pro
      case 'founders':
        return true; // Unlimited for founders
      default:
        return false;
    }
  }
  
  static Future<int> getMetaphysicalQueryLimit() async {
    final subscriptionTier = await getSubscriptionTier();
    
    switch (subscriptionTier) {
      case 'pro':
        return 5;
      case 'founders':
        return -1; // Unlimited
      default:
        return 0; // No access
    }
  }
  
  // Clear all user data (for logout)
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  // Check if user has seen onboarding
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }
  
  // Mark onboarding as seen
  static Future<void> setOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }
  
  // Initialize service (for non-static usage)
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }
  
  // User Profile Management
  UserProfile? _cachedProfile;
  
  UserProfile? getUserProfile() {
    return _cachedProfile;
  }
  
  Future<UserProfile> getOrCreateUserProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;
    
    // Try to load from storage
    _cachedProfile = await loadUserProfile();
    
    // If no profile exists, create a default one
    if (_cachedProfile == null) {
      _cachedProfile = UserProfile.createDefault();
      await saveUserProfile(_cachedProfile!);
    }
    
    return _cachedProfile!;
  }
  
  Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userProfileKey, json.encode(profile.toJson()));
  }
  
  Future<UserProfile?> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileString = prefs.getString(_userProfileKey);
    if (profileString != null) {
      try {
        return UserProfile.fromJson(json.decode(profileString));
      } catch (e) {
        print('Error loading user profile: $e');
        return null;
      }
    }
    return null;
  }
  
  // Birth Chart Management (non-static)
  BirthChart? getBirthChartInstance() {
    // For now, return null - could load from shared preferences
    return null;
  }
  
  Future<void> saveBirthChartInstance(BirthChart chart) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_birthChartKey, json.encode(chart.toJson()));
  }
  
  Future<BirthChart?> loadBirthChart() async {
    final prefs = await SharedPreferences.getInstance();
    final chartString = prefs.getString(_birthChartKey);
    if (chartString != null) {
      try {
        return BirthChart.fromJson(json.decode(chartString));
      } catch (e) {
        print('Error loading birth chart: $e');
        return null;
      }
    }
    return null;
  }
  
  // Ad metrics storage
  static Future<void> saveAdMetrics(Map<String, dynamic> metrics) async {
    final prefs = await SharedPreferences.getInstance();
    final metricsJson = json.encode(metrics);
    await prefs.setString('${_adMetricsKey}_${metrics['date']}', metricsJson);
  }
  
  static Future<List<Map<String, dynamic>>> getAdMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_adMetricsKey));
    
    final metrics = <Map<String, dynamic>>[];
    for (final key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        metrics.add(json.decode(jsonStr));
      }
    }
    
    return metrics;
  }
}