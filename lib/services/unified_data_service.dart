import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/user_profile.dart';
import '../models/crystal_collection.dart';
import '../models/journal_entry.dart';
import '../models/birth_chart.dart';
import 'firebase_service.dart';
import 'storage_service.dart';

/// Unified Data Service - Single source of truth for all user data
/// Uses Firebase Blaze for real-time sync and premium features
class UnifiedDataService extends ChangeNotifier {
  final FirebaseService _firebaseService;
  final StorageService _storageService;
  
  UserProfile? _userProfile;
  List<CollectionEntry> _crystalCollection = [];
  List<JournalEntry> _journalEntries = [];
  Map<String, dynamic> _spiritualContext = {};
  
  // Real-time streams
  StreamSubscription? _profileStream;
  StreamSubscription? _collectionStream;
  
  UnifiedDataService({
    required FirebaseService firebaseService,
    required StorageService storageService,
  }) : _firebaseService = firebaseService,
       _storageService = storageService;
  
  // Getters
  UserProfile? get userProfile => _userProfile;
  List<CollectionEntry> get crystalCollection => _crystalCollection;
  List<JournalEntry> get journalEntries => _journalEntries;
  bool get isAuthenticated => _firebaseService.isAuthenticated;
  bool get isPremiumUser => _userProfile?.subscriptionTier != SubscriptionTier.free;
  
  /// Initialize data service and start real-time sync
  Future<void> initialize() async {
    if (_firebaseService.isAuthenticated) {
      await _loadUserData();
      await _startRealTimeSync();
    }
  }
  
  /// Load all user data from Firebase/local storage
  Future<void> _loadUserData() async {
    try {
      // Load user profile
      _userProfile = _firebaseService.currentUserProfile;
      
      // Load crystal collection
      _crystalCollection = await _firebaseService.loadCrystalCollection();
      
      // Load journal entries
      _journalEntries = await _firebaseService.loadJournalEntries();
      
      // Update spiritual context
      _updateSpiritualContext();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load user data: $e');
      // Fallback to local storage
      await _loadFromLocalStorage();
    }
  }
  
  /// Start real-time synchronization (Blaze feature)
  Future<void> _startRealTimeSync() async {
    if (!isPremiumUser) return; // Real-time sync only for premium users
    
    try {
      // Listen to profile changes
      _profileStream = _firebaseService.getUserProfileStream().listen((profile) {
        _userProfile = profile;
        _updateSpiritualContext();
        notifyListeners();
      });
      
      // Listen to collection changes
      _collectionStream = _firebaseService.getCrystalCollectionStream().listen((collection) {
        _crystalCollection = collection;
        _updateSpiritualContext();
        notifyListeners();
      });
      
      debugPrint('🔥 Firebase Blaze real-time sync started for premium user');
    } catch (e) {
      debugPrint('Real-time sync failed: $e');
    }
  }
  
  /// Update spiritual context for AI personalization
  void _updateSpiritualContext() {
    if (_userProfile == null) return;
    
    _spiritualContext = {
      'user_name': _userProfile!.name,
      'birth_chart': _userProfile!.birthChart?.toJson() ?? {},
      'owned_crystals': _crystalCollection.map((c) => {
        'name': c.crystal.name,
        'type': c.quality,
        'acquisition_date': c.dateAdded.toIso8601String(),
        'usage_count': c.usageCount,
        'intentions': c.primaryUses.join(', '),
      }).toList(),
      'crystal_count': _crystalCollection.length,
      'recent_mood': _getRecentMood(),
      'subscription_tier': _userProfile!.subscriptionTier.name,
      'recent_activity': _getRecentActivity(),
      'spiritual_preferences': _userProfile!.spiritualPreferences ?? {},
    };
  }
  
  /// Get personalized spiritual context for AI prompts
  Map<String, dynamic> getSpiritualContext() {
    return Map<String, dynamic>.from(_spiritualContext);
  }
  
  /// Add crystal to collection with real-time sync
  Future<void> addCrystal(CollectionEntry crystal) async {
    _crystalCollection.add(crystal);
    
    // Track activity with Firebase Blaze
    await _firebaseService.trackUserActivity('crystal_added', {
      'crystal_name': crystal.crystal.name,
      'crystal_type': crystal.quality,
    });
    
    // Sync to Firebase
    await _firebaseService.saveCrystalCollection(_crystalCollection);
    
    // Trigger cross-feature updates
    await _triggerCrossFeatureUpdates('crystal_added', crystal.toJson());
    
    _updateSpiritualContext();
    notifyListeners();
  }
  
  /// Update crystal usage
  Future<void> updateCrystalUsage(String crystalId) async {
    final crystalIndex = _crystalCollection.indexWhere((c) => c.id == crystalId);
    if (crystalIndex != -1) {
      // Update usage count (simplified for now)
      // In a full implementation, would update the usage count properly
      
      await _firebaseService.saveCrystalCollection(_crystalCollection);
      _updateSpiritualContext();
      notifyListeners();
    }
  }
  
  /// Add journal entry with crystal associations
  Future<void> addJournalEntry(JournalEntry entry) async {
    _journalEntries.insert(0, entry); // Latest first
    
    // Track activity with Firebase Blaze
    await _firebaseService.trackUserActivity('journal_entry', {
      'emotional_state': entry.moodAfter.name,
      'energy_change': entry.energyAfter.level - entry.energyBefore.level,
    });
    
    // Save to Firebase
    await _firebaseService.saveJournalEntry(entry);
    
    // Trigger cross-feature updates based on mood
    await _triggerCrossFeatureUpdates('journal_entry', entry.toJson());
    
    _updateSpiritualContext();
    notifyListeners();
  }
  
  /// Get crystals filtered by purpose/properties
  List<CollectionEntry> getCrystalsByPurpose(String purpose) {
    return _crystalCollection.where((crystal) {
      final properties = crystal.crystal.metaphysicalProperties.join(' ').toLowerCase();
      final intentions = crystal.primaryUses.join(' ').toLowerCase();
      return properties.contains(purpose.toLowerCase()) || 
             intentions.contains(purpose.toLowerCase());
    }).toList();
  }
  
  /// Get crystals for specific chakra
  List<CollectionEntry> getCrystalsByChakra(String chakra) {
    return _crystalCollection.where((crystal) {
      final properties = crystal.crystal.metaphysicalProperties.join(' ').toLowerCase();
      return properties.contains(chakra.toLowerCase());
    }).toList();
  }
  
  /// Get recommended crystals for current mood
  List<CollectionEntry> getRecommendedCrystals() {
    final recentMood = _getRecentMood();
    
    switch (recentMood.toLowerCase()) {
      case 'anxious':
      case 'stressed':
        return getCrystalsByPurpose('calming');
      case 'sad':
      case 'depressed':
        return getCrystalsByPurpose('uplifting');
      case 'energetic':
      case 'excited':
        return getCrystalsByPurpose('grounding');
      default:
        return _crystalCollection.take(3).toList();
    }
  }
  
  /// Enhanced AI query with full context
  Future<String> getPersonalizedGuidance(String query, String type) async {
    if (!isPremiumUser) {
      throw Exception('Personalized guidance requires premium subscription');
    }
    
    final context = getSpiritualContext();
    return await _firebaseService.enhancedAIQuery(query, type, context);
  }
  
  /// Get enhanced birth chart for premium users
  Future<BirthChart?> getEnhancedBirthChart() async {
    if (_userProfile?.birthDate == null || !isPremiumUser) return null;
    
    try {
      final result = await _firebaseService.getEnhancedBirthChart(
        _userProfile!.birthDate!,
        _userProfile!.birthTime ?? '12:00',
        _userProfile!.birthLocation ?? 'Unknown',
      );
      
      final birthChart = BirthChart.fromJson(result);
      
      // Update user profile with new chart
      _userProfile = _userProfile!.copyWith(birthChart: birthChart);
      await _firebaseService.updateUserProfile(_userProfile!);
      
      _updateSpiritualContext();
      notifyListeners();
      
      return birthChart;
    } catch (e) {
      debugPrint('Enhanced birth chart failed: $e');
      return null;
    }
  }
  
  /// Trigger cross-feature updates based on user activity
  Future<void> _triggerCrossFeatureUpdates(String activity, Map<String, dynamic> data) async {
    switch (activity) {
      case 'journal_entry':
        await _handleJournalCrossUpdates(data);
        break;
      case 'crystal_added':
        await _handleCrystalCrossUpdates(data);
        break;
    }
  }
  
  /// Handle journal entry cross-feature updates
  Future<void> _handleJournalCrossUpdates(Map<String, dynamic> entryData) async {
    final emotionalState = entryData['emotional_state']?.toString().toLowerCase();
    
    if (emotionalState == 'anxious' || emotionalState == 'stressed') {
      // Schedule healing suggestion
      await _firebaseService.trackUserActivity('healing_suggested', {
        'trigger': 'anxious_journal_entry',
        'recommended_crystals': getCrystalsByPurpose('calming').map((c) => c.crystal.name).toList(),
      });
    }
    
    if (emotionalState == 'energetic' || emotionalState == 'excited') {
      // Suggest moon ritual
      await _firebaseService.trackUserActivity('ritual_suggested', {
        'trigger': 'energetic_journal_entry',
        'type': 'grounding_ritual',
      });
    }
  }
  
  /// Handle crystal addition cross-feature updates
  Future<void> _handleCrystalCrossUpdates(Map<String, dynamic> crystalData) async {
    final crystalName = crystalData['crystal_name'];
    
    await _firebaseService.trackUserActivity('collection_updated', {
      'new_crystal': crystalName,
      'total_crystals': _crystalCollection.length,
      'suggestions_updated': true,
    });
  }
  
  /// Get recent mood from journal entries
  String _getRecentMood() {
    if (_journalEntries.isEmpty) return 'neutral';
    // Would need to implement emotionalState in JournalEntry model
    return 'neutral'; // Placeholder
  }
  
  /// Get recent activity summary
  Map<String, dynamic> _getRecentActivity() {
    return {
      'last_journal_date': _journalEntries.isNotEmpty 
        ? _journalEntries.first.dateTime.toIso8601String() 
        : null,
      'last_crystal_added': _crystalCollection.isNotEmpty
        ? _crystalCollection.last.dateAdded.toIso8601String()
        : null,
      'total_crystal_uses': _crystalCollection.fold(0, (sum, crystal) => sum + crystal.usageCount),
    };
  }
  
  /// Fallback to local storage
  Future<void> _loadFromLocalStorage() async {
    try {
      final profile = await _storageService.loadUserProfile();
      if (profile != null) {
        _userProfile = profile;
        _updateSpiritualContext();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Local storage fallback failed: $e');
    }
  }
  
  /// Save data locally as backup
  Future<void> _saveToLocalStorage() async {
    if (_userProfile != null) {
      await _storageService.saveUserProfile(_userProfile!);
    }
  }
  
  /// Clean up streams
  @override
  void dispose() {
    _profileStream?.cancel();
    _collectionStream?.cancel();
    super.dispose();
  }
}