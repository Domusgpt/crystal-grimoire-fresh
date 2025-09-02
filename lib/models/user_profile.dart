import 'package:flutter/material.dart';
import 'birth_chart.dart';
import 'crystal_collection.dart';
import 'journal_entry.dart';

/// Subscription tiers for the application
enum SubscriptionTier {
  free('Free', 5, 5, 'Basic features only'),
  premium('Premium', 30, -1, 'Unlimited crystals, marketplace access'),
  pro('Pro', -1, -1, 'All features including AI guidance and healing'),
  founders('Founders', -1, -1, 'Lifetime access with exclusive features');

  const SubscriptionTier(this.displayName, this.dailyIdentifications, this.maxCrystals, this.description);
  
  final String displayName;
  final int dailyIdentifications; // -1 = unlimited
  final int maxCrystals; // -1 = unlimited
  final String description;
  
  double get monthlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return 0.0;
      case SubscriptionTier.premium:
        return 9.99;
      case SubscriptionTier.pro:
        return 19.99;
      case SubscriptionTier.founders:
        return 199.0; // One-time payment
    }
  }
}

/// Central user profile containing all personal and spiritual data
class UserProfile {
  final String id;
  final String name;
  final String email;
  final DateTime? birthDate;
  final String? birthTime; // HH:MM format
  final String? birthLocation;
  final double? latitude;
  final double? longitude;
  final BirthChart? birthChart;
  final SubscriptionTier subscriptionTier;
  final Map<String, dynamic> spiritualPreferences;
  final Map<String, int> monthlyUsage;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool isEmailVerified;
  final String? profileImageUrl;
  final Map<String, dynamic> settings;
  final List<String> favoriteFeatures;
  final Map<String, dynamic> customProperties;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.birthDate,
    this.birthTime,
    this.birthLocation,
    this.latitude,
    this.longitude,
    this.birthChart,
    this.subscriptionTier = SubscriptionTier.free,
    Map<String, dynamic>? spiritualPreferences,
    Map<String, int>? monthlyUsage,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    this.isEmailVerified = false,
    this.profileImageUrl,
    Map<String, dynamic>? settings,
    List<String>? favoriteFeatures,
    Map<String, dynamic>? customProperties,
  }) : spiritualPreferences = spiritualPreferences ?? {},
       monthlyUsage = monthlyUsage ?? {},
       createdAt = createdAt ?? DateTime.now(),
       lastActiveAt = lastActiveAt ?? DateTime.now(),
       settings = settings ?? {},
       favoriteFeatures = favoriteFeatures ?? [],
       customProperties = customProperties ?? {};

  /// Create new user profile
  factory UserProfile.create({
    required String name,
    required String email,
    SubscriptionTier tier = SubscriptionTier.free,
  }) {
    return UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      subscriptionTier: tier,
    );
  }

  /// Create default user profile for anonymous users
  factory UserProfile.createDefault() {
    return UserProfile(
      id: 'default_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Crystal Explorer',
      email: 'guest@crystalgrimoire.com',
      subscriptionTier: SubscriptionTier.free,
      spiritualPreferences: {
        'preferredCrystals': [],
        'interests': ['healing', 'meditation', 'chakras'],
        'experienceLevel': 'beginner',
      },
      settings: {
        'notifications': true,
        'theme': 'mystical',
        'language': 'en',
      },
    );
  }

  /// Get spiritual context for LLM prompts
  Map<String, dynamic> getSpiritualContext() {
    final context = <String, dynamic>{
      'name': name,
      'subscriptionTier': subscriptionTier.displayName,
      'spiritualPreferences': spiritualPreferences,
      'hasAstrologyData': birthChart != null,
    };

    // Add astrological data if available
    if (birthChart != null) {
      context['astrology'] = {
        'sunSign': birthChart!.sunSign.name,
        'moonSign': birthChart!.moonSign.name,
        'ascendant': birthChart!.ascendant.name,
        'dominantElements': birthChart!.getSpiritualContext()['dominantElements'],
        'currentTransits': birthChart!.getSpiritualContext()['currentTransits'],
      };
    }

    // Add usage patterns
    context['usagePatterns'] = {
      'thisMonthIdentifications': monthlyUsage['identifications'] ?? 0,
      'thisMonthJournalEntries': monthlyUsage['journalEntries'] ?? 0,
      'thisMonthRituals': monthlyUsage['rituals'] ?? 0,
      'thisMonthHealingSessions': monthlyUsage['healingSessions'] ?? 0,
    };

    return context;
  }

  /// Get personalized recommendations based on profile
  List<String> getPersonalizedRecommendations() {
    final recommendations = <String>[];
    
    // Based on subscription tier
    switch (subscriptionTier) {
      case SubscriptionTier.free:
        recommendations.add('Consider upgrading to Premium for unlimited crystal identifications');
        break;
      case SubscriptionTier.premium:
        recommendations.add('Explore Pro features like Moon Rituals and Crystal Healing');
        break;
      case SubscriptionTier.pro:
        recommendations.add('You have access to all features! Try the Sound Bath meditation');
        break;
      case SubscriptionTier.founders:
        recommendations.add('Thank you for being a Founder! You have lifetime access to all features');
        break;
    }

    // Based on astrological data
    if (birthChart != null) {
      final crystalRecs = birthChart!.getCrystalRecommendations();
      if (crystalRecs.isNotEmpty) {
        recommendations.add('Based on your ${birthChart!.sunSign.name} sun sign, consider adding ${crystalRecs.first}');
      }
    } else {
      recommendations.add('Add your birth information for personalized astrological crystal recommendations');
    }

    // Based on usage patterns
    final identifications = monthlyUsage['identifications'] ?? 0;
    if (identifications == 0) {
      recommendations.add('Try identifying your first crystal using the camera feature');
    }

    return recommendations;
  }

  /// Check if user has access to a feature
  bool hasAccessTo(String feature) {
    switch (feature) {
      case 'crystal_identification':
        return true; // Basic feature for all
      case 'collection_management':
        return true; // Basic feature for all
      case 'unlimited_identifications':
        return subscriptionTier != SubscriptionTier.free;
      case 'marketplace':
        return subscriptionTier != SubscriptionTier.free;
      case 'journal':
        return subscriptionTier == SubscriptionTier.pro || subscriptionTier == SubscriptionTier.founders;
      case 'moon_rituals':
        return subscriptionTier == SubscriptionTier.pro || subscriptionTier == SubscriptionTier.founders;
      case 'crystal_healing':
        return subscriptionTier == SubscriptionTier.pro || subscriptionTier == SubscriptionTier.founders;
      case 'sound_bath':
        return subscriptionTier == SubscriptionTier.pro || subscriptionTier == SubscriptionTier.founders;
      case 'ai_guidance':
        return subscriptionTier == SubscriptionTier.pro || subscriptionTier == SubscriptionTier.founders;
      case 'advanced_astrology':
        return subscriptionTier == SubscriptionTier.pro || subscriptionTier == SubscriptionTier.founders;
      default:
        return false;
    }
  }

  /// Get remaining daily identifications
  int getRemainingIdentifications() {
    if (subscriptionTier.dailyIdentifications == -1) {
      return -1; // Unlimited
    }
    
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    final todayUsage = monthlyUsage[todayKey] ?? 0;
    
    return (subscriptionTier.dailyIdentifications - todayUsage).clamp(0, subscriptionTier.dailyIdentifications);
  }

  /// Record usage for a feature
  UserProfile recordUsage(String feature, {int count = 1}) {
    final newUsage = Map<String, int>.from(monthlyUsage);
    newUsage[feature] = (newUsage[feature] ?? 0) + count;
    
    // Also record daily usage for identifications
    if (feature == 'identifications') {
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month}-${today.day}';
      newUsage[todayKey] = (newUsage[todayKey] ?? 0) + count;
    }
    
    return copyWith(
      monthlyUsage: newUsage,
      lastActiveAt: DateTime.now(),
    );
  }

  /// Update spiritual preferences
  UserProfile updateSpiritualPreferences(Map<String, dynamic> preferences) {
    final newPreferences = Map<String, dynamic>.from(spiritualPreferences);
    newPreferences.addAll(preferences);
    return copyWith(spiritualPreferences: newPreferences);
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'birthDate': birthDate?.toIso8601String(),
      'birthTime': birthTime,
      'birthLocation': birthLocation,
      'latitude': latitude,
      'longitude': longitude,
      'birthChart': birthChart?.toJson(),
      'subscriptionTier': subscriptionTier.name,
      'spiritualPreferences': spiritualPreferences,
      'monthlyUsage': monthlyUsage,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'profileImageUrl': profileImageUrl,
      'settings': settings,
      'favoriteFeatures': favoriteFeatures,
      'customProperties': customProperties,
    };
  }

  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      birthTime: json['birthTime'],
      birthLocation: json['birthLocation'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      birthChart: json['birthChart'] != null ? BirthChart.fromJson(json['birthChart']) : null,
      subscriptionTier: SubscriptionTier.values.firstWhere(
        (tier) => tier.name == json['subscriptionTier'],
        orElse: () => SubscriptionTier.free,
      ),
      spiritualPreferences: Map<String, dynamic>.from(json['spiritualPreferences'] ?? {}),
      monthlyUsage: Map<String, int>.from(json['monthlyUsage'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      lastActiveAt: DateTime.parse(json['lastActiveAt']),
      isEmailVerified: json['isEmailVerified'] ?? false,
      profileImageUrl: json['profileImageUrl'],
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
      favoriteFeatures: List<String>.from(json['favoriteFeatures'] ?? []),
      customProperties: Map<String, dynamic>.from(json['customProperties'] ?? {}),
    );
  }

  /// Create copy with updated fields
  UserProfile copyWith({
    String? name,
    String? email,
    DateTime? birthDate,
    String? birthTime,
    String? birthLocation,
    double? latitude,
    double? longitude,
    BirthChart? birthChart,
    SubscriptionTier? subscriptionTier,
    Map<String, dynamic>? spiritualPreferences,
    Map<String, int>? monthlyUsage,
    DateTime? lastActiveAt,
    bool? isEmailVerified,
    String? profileImageUrl,
    Map<String, dynamic>? settings,
    List<String>? favoriteFeatures,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      birthTime: birthTime ?? this.birthTime,
      birthLocation: birthLocation ?? this.birthLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      birthChart: birthChart ?? this.birthChart,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      spiritualPreferences: spiritualPreferences ?? this.spiritualPreferences,
      monthlyUsage: monthlyUsage ?? this.monthlyUsage,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      settings: settings ?? this.settings,
      favoriteFeatures: favoriteFeatures ?? this.favoriteFeatures,
      customProperties: customProperties,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, tier: ${subscriptionTier.displayName})';
  }
}
