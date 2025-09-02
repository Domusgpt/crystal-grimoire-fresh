import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  String displayName;
  String? photoUrl;
  final DateTime createdAt;
  DateTime lastActive;
  String subscriptionTier; // free, premium, pro, founders
  int dailyCredits;
  int totalCredits;
  Map<String, dynamic> birthChart;
  Map<String, dynamic> preferences;
  List<String> favoriteCategories;
  List<String> ownedCrystalIds;
  Map<String, dynamic> stats;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    DateTime? lastActive,
    this.subscriptionTier = 'free',
    this.dailyCredits = 3,
    this.totalCredits = 0,
    Map<String, dynamic>? birthChart,
    Map<String, dynamic>? preferences,
    List<String>? favoriteCategories,
    List<String>? ownedCrystalIds,
    Map<String, dynamic>? stats,
  })  : lastActive = lastActive ?? DateTime.now(),
        birthChart = birthChart ?? {},
        preferences = preferences ?? _defaultPreferences(),
        favoriteCategories = favoriteCategories ?? [],
        ownedCrystalIds = ownedCrystalIds ?? [],
        stats = stats ?? _defaultStats();

  static Map<String, dynamic> _defaultPreferences() {
    return {
      'theme': 'dark',
      'notifications': true,
      'dailyCrystal': true,
      'moonPhaseAlerts': true,
      'healingReminders': false,
      'meditationMusic': true,
      'autoSaveJournal': true,
    };
  }

  static Map<String, dynamic> _defaultStats() {
    return {
      'crystalsIdentified': 0,
      'collectionSize': 0,
      'healingSessions': 0,
      'meditationMinutes': 0,
      'journalEntries': 0,
      'ritualsCompleted': 0,
      'daysActive': 0,
      'achievementsUnlocked': [],
    };
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'Crystal Seeker',
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActive: (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
      subscriptionTier: data['subscriptionTier'] ?? 'free',
      dailyCredits: data['dailyCredits'] ?? 3,
      totalCredits: data['totalCredits'] ?? 0,
      birthChart: data['birthChart'] ?? {},
      preferences: data['preferences'] ?? _defaultPreferences(),
      favoriteCategories: List<String>.from(data['favoriteCategories'] ?? []),
      ownedCrystalIds: List<String>.from(data['ownedCrystalIds'] ?? []),
      stats: data['stats'] ?? _defaultStats(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'subscriptionTier': subscriptionTier,
      'dailyCredits': dailyCredits,
      'totalCredits': totalCredits,
      'birthChart': birthChart,
      'preferences': preferences,
      'favoriteCategories': favoriteCategories,
      'ownedCrystalIds': ownedCrystalIds,
      'stats': stats,
    };
  }

  // Helper methods
  bool get isPremium => subscriptionTier != 'free';
  bool get isPro => subscriptionTier == 'pro' || subscriptionTier == 'founders';
  bool get isFounder => subscriptionTier == 'founders';

  bool hasCredits() => dailyCredits > 0 || totalCredits > 0;

  void useCredit() {
    if (dailyCredits > 0) {
      dailyCredits--;
    } else if (totalCredits > 0) {
      totalCredits--;
    }
  }

  String get sunSign => birthChart['sunSign'] ?? 'Unknown';
  String get moonSign => birthChart['moonSign'] ?? 'Unknown';
  String get risingSign => birthChart['risingSign'] ?? 'Unknown';
  
  DateTime? get birthDate {
    if (birthChart['birthDate'] != null) {
      return (birthChart['birthDate'] as Timestamp).toDate();
    }
    return null;
  }

  // Feature access based on subscription
  bool canAccessFeature(String feature) {
    switch (feature) {
      case 'crystalId':
        return hasCredits() || isPremium;
      case 'unlimitedId':
        return isPremium;
      case 'advancedHealing':
        return isPremium;
      case 'personalizedRituals':
        return isPremium;
      case 'downloadContent':
        return isPro;
      case 'marketplace':
        return true; // Available to all
      case 'dreamAnalysis':
        return isPremium;
      case 'soundBathPremium':
        return isPremium;
      default:
        return false;
    }
  }

  // Update stats
  void incrementStat(String statKey, [int amount = 1]) {
    if (stats[statKey] is int) {
      stats[statKey] = (stats[statKey] as int) + amount;
    } else if (stats[statKey] is List) {
      // For achievements or similar list-based stats
      // Handle accordingly
    }
  }
}