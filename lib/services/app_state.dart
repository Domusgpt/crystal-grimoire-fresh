import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crystal.dart';
import 'usage_tracker.dart';
import 'cache_service.dart';

/// Global app state management using Provider
class AppState extends ChangeNotifier {
  // User data
  String _subscriptionTier = 'free';
  bool _isFirstLaunch = true;
  bool _hasSeenOnboarding = false;
  
  // Crystal collection
  final List<Crystal> _crystalCollection = [];
  final List<CrystalIdentification> _recentIdentifications = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  SharedPreferences? _prefs;
  int _journalEntriesThisMonth = 0;
  static const String _crystalCacheKey = 'app_state_crystals';
  static const String _recentIdentificationsKey = 'app_state_recent_identifications';
  static const String _settingsCacheKey = 'app_state_settings';
  static const String _onboardingKey = 'app_state_has_seen_onboarding';
  static const String _installDateKey = 'app_state_install_date';

  // UI state
  bool _isLoading = false;
  String? _errorMessage;
  String _loadingMessage = 'Connecting to the crystal realm...';
  
  // Usage tracking
  UsageStats? _usageStats;
  
  // Settings
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  String _preferredLanguage = 'en';
  
  // Getters
  String get subscriptionTier => _subscriptionTier;
  bool get isFirstLaunch => _isFirstLaunch;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  List<Crystal> get crystalCollection => List.unmodifiable(_crystalCollection);
  List<CrystalIdentification> get recentIdentifications => 
      List.unmodifiable(_recentIdentifications);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get loadingMessage => _loadingMessage;
  UsageStats? get usageStats => _usageStats;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  String get preferredLanguage => _preferredLanguage;
  
  // Computed properties
  bool get isPremiumUser => _subscriptionTier != 'free';
  bool get canIdentify => _usageStats?.canIdentify ?? true;
  int get collectionCount => _crystalCollection.length;
  Crystal? get favoritesCrystal => _crystalCollection.isNotEmpty ? 
      _crystalCollection.first : null;
  
  // Missing properties for HomeScreen
  List<Crystal> get userCrystals => _crystalCollection;
  Map<String, int> get currentMonthUsage => {
    'identifications': _usageStats?.monthlyUsage ?? 0,
    'journal_entries': _journalEntriesThisMonth,
  };
  int get monthlyLimit => _usageStats?.monthlyLimit ?? 10;
  
  /// Initialize app state on startup
  Future<void> initialize() async {
    setLoading(true, 'Initializing Crystal Grimoire...');

    try {
      _prefs = await SharedPreferences.getInstance();

      // Load user subscription tier
      _subscriptionTier = await UsageTracker.getCurrentSubscriptionTier();

      // Load usage statistics
      _usageStats = await UsageTracker.getUsageStats();

      await _loadSettingsFromProfile();

      // Load crystal collection
      await _loadCrystalCollection();

      // Load recent identifications
      await _loadRecentIdentifications();

      // Check first launch
      await _checkFirstLaunch();

      await _loadUsageTracking();

      setLoading(false);

    } catch (e) {
      setError('Failed to initialize app: $e');
    }
  }
  
  /// Updates subscription tier
  Future<void> updateSubscriptionTier(String tier) async {
    _subscriptionTier = tier;
    await UsageTracker.updateSubscriptionTier(tier);
    _usageStats = await UsageTracker.getUsageStats();
    notifyListeners();
  }
  
  /// Adds a crystal to the collection
  Future<void> addCrystal(Crystal crystal) async {
    _crystalCollection.add(crystal);
    await _saveCrystalCollection();
    notifyListeners();
  }
  
  /// Removes a crystal from the collection
  Future<void> removeCrystal(String crystalId) async {
    _crystalCollection.removeWhere((crystal) => crystal.id == crystalId);
    await _saveCrystalCollection();
    notifyListeners();
  }
  
  /// Updates a crystal in the collection
  Future<void> updateCrystal(Crystal updatedCrystal) async {
    final index = _crystalCollection.indexWhere(
      (crystal) => crystal.id == updatedCrystal.id,
    );
    
    if (index != -1) {
      _crystalCollection[index] = updatedCrystal;
      await _saveCrystalCollection();
      notifyListeners();
    }
  }
  
  /// Adds a recent identification
  void addRecentIdentification(CrystalIdentification identification) {
    _recentIdentifications.insert(0, identification);
    
    // Keep only the most recent 20 identifications
    if (_recentIdentifications.length > 20) {
      _recentIdentifications.removeRange(20, _recentIdentifications.length);
    }
    
    _saveRecentIdentifications();
    notifyListeners();
  }
  
  /// Refreshes usage statistics
  Future<void> refreshUsageStats() async {
    _usageStats = await UsageTracker.getUsageStats();
    notifyListeners();
  }
  
  /// Increments usage for a specific feature
  Future<void> incrementUsage(String feature) async {
    try {
      await UsageTracker.incrementUsage(feature);
      _usageStats = await UsageTracker.getUsageStats();
      notifyListeners();
    } catch (e) {
      print('Failed to increment usage for $feature: $e');
    }
  }
  
  /// Sets loading state
  void setLoading(bool loading, [String? message]) {
    _isLoading = loading;
    if (message != null) {
      _loadingMessage = message;
    }
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Sets error state
  void setError(String error) {
    _isLoading = false;
    _errorMessage = error;
    notifyListeners();
  }
  
  /// Clears error state
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Marks onboarding as completed
  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
    _isFirstLaunch = false;
    final prefs = await _ensurePrefs();
    await prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }

  /// Updates notification settings
  Future<void> updateNotificationSettings(bool enabled) async {
    _notificationsEnabled = enabled;
    await _saveSettingsToCache();
    await _persistSettingsToFirestore();
    notifyListeners();
  }

  /// Updates sound settings
  Future<void> updateSoundSettings(bool enabled) async {
    _soundEnabled = enabled;
    await _saveSettingsToCache();
    await _persistSettingsToFirestore();
    notifyListeners();
  }

  /// Updates preferred language
  Future<void> updateLanguage(String languageCode) async {
    _preferredLanguage = languageCode;
    await _saveSettingsToCache();
    await _persistSettingsToFirestore();
    notifyListeners();
  }
  
  /// Gets crystals by category/type
  List<Crystal> getCrystalsByType(String type) {
    return _crystalCollection
        .where((crystal) => crystal.name.toLowerCase().contains(type.toLowerCase()))
        .toList();
  }
  
  /// Gets crystals by chakra association
  List<Crystal> getCrystalsByChakra(ChakraAssociation chakra) {
    return _crystalCollection
        .where((crystal) => crystal.chakras.contains(chakra))
        .toList();
  }
  
  /// Searches crystals by name or properties
  List<Crystal> searchCrystals(String query) {
    final lowerQuery = query.toLowerCase();
    return _crystalCollection.where((crystal) {
      return crystal.name.toLowerCase().contains(lowerQuery) ||
             crystal.description.toLowerCase().contains(lowerQuery) ||
             crystal.metaphysicalProperties.any(
               (prop) => prop.toLowerCase().contains(lowerQuery),
             ) ||
             crystal.healingProperties.any(
               (prop) => prop.toLowerCase().contains(lowerQuery),
             );
    }).toList();
  }
  
  /// Gets cache statistics
  Future<CacheStats> getCacheStats() async {
    return await CacheService.getCacheStats();
  }
  
  /// Clears all cached data
  Future<void> clearCache() async {
    await CacheService.clearAllCache();
    notifyListeners();
  }
  
  // Private helper methods
  
  Future<void> _loadCrystalCollection() async {
    final user = _auth.currentUser;

    if (user == null) {
      await _loadCrystalCollectionFromCache();
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('collection')
          .orderBy('dateAdded', descending: true)
          .get();

      _crystalCollection
        ..clear()
        ..addAll(snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          final crystalData = data['crystal'];
          if (crystalData is Map<String, dynamic>) {
            crystalData['id'] = crystalData['id'] ?? doc.id;
            return Crystal.fromJson(crystalData);
          }
          return Crystal.fromJson({
            'id': data['id'] ?? doc.id,
            'name': data['name'] ?? 'Crystal',
            'scientificName': data['scientificName'] ?? '',
            'description': data['description'] ?? '',
            'careInstructions': data['careInstructions'] ?? '',
          });
        }));

      await _saveCrystalCollection();
    } catch (e) {
      print('Failed to load crystal collection from Firestore: $e');
      await _loadCrystalCollectionFromCache();
    }
  }

  Future<void> _saveCrystalCollection() async {
    final prefs = await _ensurePrefs();
    final payload = jsonEncode(
      _crystalCollection.map((crystal) => crystal.toJson()).toList(),
    );
    await prefs.setString(_crystalCacheKey, payload);
  }

  Future<void> _loadCrystalCollectionFromCache() async {
    final prefs = await _ensurePrefs();
    final cached = prefs.getString(_crystalCacheKey);
    if (cached == null) return;

    try {
      final decoded = jsonDecode(cached) as List<dynamic>;
      _crystalCollection
        ..clear()
        ..addAll(decoded.map((e) => Crystal.fromJson(Map<String, dynamic>.from(e))));
    } catch (e) {
      print('Failed to parse cached crystal collection: $e');
    }
  }

  Future<void> _loadRecentIdentifications() async {
    final user = _auth.currentUser;

    if (user == null) {
      await _loadRecentIdentificationsFromCache();
      return;
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('identifications')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition' ||
            (e.message?.toLowerCase().contains('createdat') ?? false)) {
          snapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('identifications')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .get();
        } else {
          rethrow;
        }
      }

      _recentIdentifications
        ..clear()
        ..addAll(snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['sessionId'] = data['sessionId'] ?? doc.id;
          if (!data.containsKey('timestamp') && data['createdAt'] != null) {
            data['timestamp'] = data['createdAt'];
          }
          return CrystalIdentification.fromJson(data);
        }));

      await _saveRecentIdentifications();
    } catch (e) {
      print('Failed to load recent identifications: $e');
      await _loadRecentIdentificationsFromCache();
    }
  }

  Future<void> _saveRecentIdentifications() async {
    final prefs = await _ensurePrefs();
    final payload = jsonEncode(
      _recentIdentifications.map((identification) => identification.toJson()).toList(),
    );
    await prefs.setString(_recentIdentificationsKey, payload);
  }

  Future<void> _loadRecentIdentificationsFromCache() async {
    final prefs = await _ensurePrefs();
    final cached = prefs.getString(_recentIdentificationsKey);
    if (cached == null) return;

    try {
      final decoded = jsonDecode(cached) as List<dynamic>;
      _recentIdentifications
        ..clear()
        ..addAll(decoded.map((e) =>
            CrystalIdentification.fromJson(Map<String, dynamic>.from(e))));
    } catch (e) {
      print('Failed to parse cached identifications: $e');
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await _ensurePrefs();
    final installDate = prefs.getString(_installDateKey);

    if (installDate == null) {
      _isFirstLaunch = true;
      _hasSeenOnboarding = false;
      await prefs.setString(_installDateKey, DateTime.now().toIso8601String());
    } else {
      _isFirstLaunch = false;
      _hasSeenOnboarding = prefs.getBool(_onboardingKey) ?? false;
    }
  }

  Future<void> _loadSettingsFromProfile() async {
    await _loadSettingsFromCache();

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final settings = Map<String, dynamic>.from(doc.data()?['settings'] ?? {});
      _notificationsEnabled = settings['notifications'] ?? _notificationsEnabled;
      _soundEnabled = settings['sound'] ?? settings['soundEnabled'] ?? _soundEnabled;
      _preferredLanguage = settings['language'] ?? _preferredLanguage;
      await _saveSettingsToCache();
    } catch (e) {
      print('Failed to load settings from Firestore: $e');
    }
  }

  Future<void> _loadSettingsFromCache() async {
    final prefs = await _ensurePrefs();
    final cached = prefs.getString(_settingsCacheKey);
    if (cached == null) return;

    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      _notificationsEnabled = data['notifications'] ?? _notificationsEnabled;
      _soundEnabled = data['sound'] ?? _soundEnabled;
      _preferredLanguage = data['language'] ?? _preferredLanguage;
    } catch (e) {
      print('Failed to parse cached settings: $e');
    }
  }

  Future<void> _saveSettingsToCache() async {
    final prefs = await _ensurePrefs();
    final data = jsonEncode({
      'notifications': _notificationsEnabled,
      'sound': _soundEnabled,
      'language': _preferredLanguage,
    });
    await prefs.setString(_settingsCacheKey, data);
  }

  Future<void> _persistSettingsToFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'settings': {
          'notifications': _notificationsEnabled,
          'sound': _soundEnabled,
          'language': _preferredLanguage,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print('Failed to persist settings to Firestore: $e');
    }
  }

  Future<void> _loadUsageTracking() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month);
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('journal')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      _journalEntriesThisMonth = snapshot.size;
    } catch (e) {
      print('Failed to load journal usage: $e');
      _journalEntriesThisMonth = 0;
    }
  }

  Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
}

/// Extension methods for convenient access
extension AppStateExtensions on AppState {
  /// Checks if user can access premium features
  bool canAccessPremiumFeature(String featureName) {
    if (isPremiumUser) return true;
    
    // Free users might have preview access
    // This would be checked against UsageTracker
    return false;
  }
  
  /// Gets upgrade prompt message
  String? getUpgradePrompt() {
    if (isPremiumUser) return null;
    
    if (_usageStats != null && !_usageStats!.canIdentify) {
      return 'Unlock unlimited crystal identifications with Premium!';
    }
    
    if (collectionCount >= 5) {
      return 'Growing collection! Upgrade to Premium for unlimited storage and spiritual guidance.';
    }
    
    return null;
  }
  
  /// Formats usage stats for display
  String getUsageDescription() {
    if (_usageStats == null) return 'Loading...';
    
    if (isPremiumUser) {
      return 'Unlimited identifications • ${_usageStats!.tierDisplayName}';
    }
    
    final remaining = _usageStats!.remainingThisMonth;
    final total = _usageStats!.monthlyLimit;
    
    return '$remaining of $total identifications remaining this month';
  }
  
  /// Gets personalized greeting
  String getPersonalizedGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting;
    
    if (hour < 6) {
      timeGreeting = 'Good night';
    } else if (hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon';
    } else if (hour < 21) {
      timeGreeting = 'Good evening';
    } else {
      timeGreeting = 'Good night';
    }
    
    if (collectionCount == 0) {
      return '$timeGreeting, beloved seeker! Ready to discover your first crystal?';
    } else if (collectionCount == 1) {
      return '$timeGreeting! Your crystal journey has begun beautifully.';
    } else {
      return '$timeGreeting, crystal keeper! Your collection of $collectionCount crystals awaits.';
    }
  }
}