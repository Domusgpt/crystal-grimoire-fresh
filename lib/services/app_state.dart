import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/crystal.dart';
import '../models/crystal_collection.dart';
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
  final List<CollectionEntry> _collectionEntries = [];
  final List<CrystalIdentification> _recentIdentifications = [];
  
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
  List<CollectionEntry> get collectionEntries => List.unmodifiable(_collectionEntries);
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
  int get collectionCount => _collectionEntries.length;
  Crystal? get favoritesCrystal => _crystalCollection.isNotEmpty ? 
      _crystalCollection.first : null;
  
  // Missing properties for HomeScreen
  List<Crystal> get userCrystals => _crystalCollection;
  Map<String, int> get currentMonthUsage => {
    'identifications': _usageStats?.monthlyUsage ?? 0,
    'journal_entries': 0, // TODO: Implement journal tracking
  };
  int get monthlyLimit => _usageStats?.monthlyLimit ?? 10;
  
  /// Initialize app state on startup
  Future<void> initialize() async {
    setLoading(true, 'Initializing Crystal Grimoire...');
    
    try {
      // Load user subscription tier
      _subscriptionTier = await UsageTracker.getCurrentSubscriptionTier();
      
      // Load usage statistics
      _usageStats = await UsageTracker.getUsageStats();
      
      // Load crystal collection
      await _loadCrystalCollection();
      
      // Load recent identifications
      await _loadRecentIdentifications();
      
      // Check first launch
      await _checkFirstLaunch();
      
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
    // Save to preferences
    notifyListeners();
  }
  
  /// Updates notification settings
  Future<void> updateNotificationSettings(bool enabled) async {
    _notificationsEnabled = enabled;
    // Save to preferences
    notifyListeners();
  }
  
  /// Updates sound settings
  Future<void> updateSoundSettings(bool enabled) async {
    _soundEnabled = enabled;
    // Save to preferences
    notifyListeners();
  }
  
  /// Updates preferred language
  Future<void> updateLanguage(String languageCode) async {
    _preferredLanguage = languageCode;
    // Save to preferences
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
    _collectionEntries.clear();
    _crystalCollection.clear();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('collection')
          .orderBy('addedAt', descending: true)
          .get();

      final entries = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        final libraryRef = (data['libraryRef'] ?? '').toString();
        if (libraryRef.isEmpty) {
          debugPrint('Skipping collection entry ${doc.id} - missing libraryRef');
          return null;
        }

        final crystal = await _loadCrystalFromLibrary(firestore, libraryRef);
        final tags = _asStringList(data['tags']);
        final addedAt = _timestampToDate(data['addedAt']) ?? DateTime.now();
        final notesValue = data['notes'];
        final notes = notesValue is String ? notesValue : '';

        return CollectionEntry(
          id: doc.id,
          userId: user.uid,
          crystal: crystal,
          dateAdded: addedAt,
          source: 'Personal Collection',
          location: null,
          price: null,
          size: 'medium',
          quality: 'tumbled',
          primaryUses: tags,
          tags: tags,
          notes: notes.trim().isNotEmpty ? notes.trim() : null,
          images: <String>[],
          isActive: true,
          isFavorite: false,
          customProperties: {
            'documentPath': doc.reference.path,
            'addedAt': addedAt.toIso8601String(),
            'createdAt': _timestampToDate(data['createdAt'])?.toIso8601String(),
            'updatedAt': _timestampToDate(data['updatedAt'])?.toIso8601String(),
          }..removeWhere((key, value) => value == null),
          libraryRef: libraryRef,
        );
      }));

      final hydratedEntries = entries.whereType<CollectionEntry>().toList();

      _collectionEntries
        ..clear()
        ..addAll(hydratedEntries);

      _crystalCollection
        ..clear()
        ..addAll(hydratedEntries.map((entry) => entry.crystal));
    } catch (e) {
      debugPrint('Failed to load crystal collection: $e');
    }
  }

  Future<Crystal> _loadCrystalFromLibrary(
    FirebaseFirestore firestore,
    String libraryRef,
  ) async {
    try {
      final doc = await firestore.doc(libraryRef).get();
      final data = doc.data();
      if (doc.exists && data != null) {
        final map = Map<String, dynamic>.from(data);
        return _mapLibraryDocToCrystal(doc.id, map);
      }
    } catch (e) {
      debugPrint('Failed to load library document $libraryRef: $e');
    }

    return _fallbackCrystal(libraryRef);
  }

  Crystal _mapLibraryDocToCrystal(String docId, Map<String, dynamic> data) {
    final intents = _asStringList(data['intents']);
    final metaphysical = data['metaphysicalProperties'];
    final healingProps = <String>[];

    if (metaphysical is Map<String, dynamic>) {
      healingProps.addAll(_asStringList(metaphysical['healingProperties']));
      healingProps.addAll(_asStringList(metaphysical['emotionalSupport']));
      healingProps.addAll(_asStringList(metaphysical['spiritualUses']));
    } else {
      healingProps.addAll(_asStringList(data['healingProperties']));
    }

    final physicalProps = data['physicalProperties'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['physicalProperties'])
        : <String, dynamic>{};

    final description = data['description']?.toString() ??
        (intents.isNotEmpty
            ? 'Intents: ${intents.join(', ')}'
            : 'Crystal library entry');

    final imageUrls = _buildImageList(data['imageUrl'], data['imageUrls']);

    return Crystal(
      id: docId,
      name: data['name']?.toString() ?? _formatNameFromId(docId),
      scientificName: data['scientificName']?.toString() ?? '',
      description: description,
      metaphysicalProperties: intents,
      healingProperties: healingProps,
      chakras: _asStringList(data['chakras']),
      elements: _asStringList(data['elements']),
      properties: physicalProps,
      colorDescription: physicalProps['color']?.toString() ?? '',
      hardness: physicalProps['hardness']?.toString() ?? '',
      formation: physicalProps['formation']?.toString() ?? '',
      careInstructions: _stringifyCareInstructions(data['careInstructions']),
      imageUrls: imageUrls,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
      planetaryRulers: _asStringList(data['planetaryRulers']),
      zodiacSigns: _asStringList(data['zodiacSigns']),
      crystalSystem: data['crystalSystem']?.toString() ?? 'Unknown',
      formations: _asStringList(data['formations']),
      chargingMethods: _extractCareList(data['careInstructions'], 'charging'),
      cleansingMethods: _extractCareList(data['careInstructions'], 'cleansing'),
      bestCombinations: _asStringList(data['bestCombinations']),
      recommendedIntentions: intents,
      vibrationFrequency: data['vibrationFrequency']?.toString() ?? 'Medium',
      energyType: data['energyType']?.toString() ?? 'Balancing',
      bestTimeToUse: data['bestTimeToUse']?.toString() ?? 'Anytime',
      effectDuration: data['effectDuration']?.toString() ?? 'Hours',
      keywords: _asStringList(data['aliases']),
    );
  }

  Crystal _fallbackCrystal(String libraryRef) {
    final id = libraryRef.split('/').isNotEmpty
        ? libraryRef.split('/').last
        : libraryRef;

    return Crystal(
      id: id,
      name: _formatNameFromId(id),
      scientificName: '',
      description: 'Crystal reference $id',
      careInstructions: 'See library entry for care guidance.',
    );
  }

  List<String> _asStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.isNotEmpty) {
      return [value];
    }

    return <String>[];
  }

  List<String> _buildImageList(dynamic primaryImage, dynamic imageCollection) {
    final urls = <String>[];

    if (primaryImage is String && primaryImage.isNotEmpty) {
      urls.add(primaryImage);
    }

    if (imageCollection is Iterable) {
      urls.addAll(
        imageCollection
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty),
      );
    }

    return urls;
  }

  List<String> _extractCareList(dynamic careData, String key) {
    if (careData is Map<String, dynamic>) {
      return _asStringList(careData[key]);
    }
    return <String>[];
  }

  String _stringifyCareInstructions(dynamic value) {
    if (value is String) {
      return value;
    }

    if (value is Map) {
      final sections = <String>[];
      value.forEach((key, instructions) {
        final items = _asStringList(instructions);
        if (items.isNotEmpty) {
          sections.add('${_capitalize(key.toString())}: ${items.join(', ')}');
        }
      });

      if (sections.isNotEmpty) {
        return sections.join(' • ');
      }
    }

    return 'See library entry for care guidance.';
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _formatNameFromId(String id) {
    if (id.isEmpty) {
      return 'Unknown Crystal';
    }

    return id
        .split(RegExp('[-_ ]+'))
        .where((segment) => segment.isNotEmpty)
        .map(_capitalize)
        .join(' ');
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    if (value.length == 1) {
      return value.toUpperCase();
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  Future<void> _saveCrystalCollection() async {
    // TODO: Save to local database
  }
  
  Future<void> _loadRecentIdentifications() async {
    // TODO: Load from local storage
  }
  
  Future<void> _saveRecentIdentifications() async {
    // TODO: Save to local storage
  }
  
  Future<void> _checkFirstLaunch() async {
    // TODO: Check SharedPreferences for first launch
    _isFirstLaunch = false; // For now
    _hasSeenOnboarding = true; // For now
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