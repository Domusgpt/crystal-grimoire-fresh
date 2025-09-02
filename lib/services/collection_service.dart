import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crystal_collection.dart';
import '../models/crystal.dart';
import 'firebase_service.dart';
import 'backend_service.dart';

/// Service for managing the user's crystal collection with real-time Firebase sync
class CollectionService {
  static const String _collectionKey = 'crystal_collection';
  static const String _usageLogsKey = 'crystal_usage_logs';
  
  static List<CollectionEntry> _collection = [];
  static List<UsageLog> _usageLogs = [];
  static bool _isLoaded = false;
  static FirebaseService? _firebaseService;

  /// Get the current collection
  static List<CollectionEntry> get collection => List.unmodifiable(_collection);
  
  /// Get usage logs
  static List<UsageLog> get usageLogs => List.unmodifiable(_usageLogs);

  /// Initialize the collection service with Firebase integration
  static Future<void> initialize({FirebaseService? firebaseService}) async {
    if (_isLoaded) return;
    
    _firebaseService = firebaseService;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load collection from local storage first
    final collectionJson = prefs.getString(_collectionKey);
    if (collectionJson != null) {
      final List<dynamic> decoded = json.decode(collectionJson);
      _collection = decoded.map((e) => CollectionEntry.fromJson(e)).toList();
    }
    
    // Load usage logs
    final logsJson = prefs.getString(_usageLogsKey);
    if (logsJson != null) {
      final List<dynamic> decoded = json.decode(logsJson);
      _usageLogs = decoded.map((e) => UsageLog.fromJson(e)).toList();
    }
    
    _isLoaded = true;
    
    // Real-time sync with Firebase if authenticated
    if (_firebaseService?.isAuthenticated == true) {
      await _syncWithFirebase();
      _startRealtimeSync();
    }
    // Fallback to backend sync
    else if (BackendService.isAuthenticated) {
      await _syncWithBackend();
    }
  }

  /// Add a crystal to the collection
  static Future<CollectionEntry> addCrystal({
    required Crystal crystal,
    required String source,
    String? location,
    double? price,
    required String size,
    required String quality,
    List<String>? primaryUses,
    String? notes,
    List<String>? images,
  }) async {
    await initialize();
    
    final entry = CollectionEntry.create(
      userId: BackendService.currentUserId ?? 'local',
      crystal: crystal,
      source: source,
      location: location,
      price: price,
      size: size,
      quality: quality,
      primaryUses: primaryUses,
      notes: notes,
      images: images,
    );
    
    _collection.add(entry);
    await _saveCollection();
    
    // Real-time sync with Firebase
    if (_firebaseService?.isAuthenticated == true) {
      await _firebaseService!.saveCrystalCollection(_collection);
    }
    // Fallback to backend sync
    else if (BackendService.isAuthenticated) {
      await _syncEntryToBackend(entry);
    }
    
    return entry;
  }

  /// Update a collection entry
  static Future<void> updateEntry(CollectionEntry entry) async {
    final index = _collection.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _collection[index] = entry;
      await _saveCollection();
      
      // Real-time sync with Firebase
      if (_firebaseService?.isAuthenticated == true) {
        await _firebaseService!.saveCrystalCollection(_collection);
      }
      // Fallback to backend sync
      else if (BackendService.isAuthenticated) {
        await _syncEntryToBackend(entry);
      }
    }
  }

  /// Record crystal usage
  static Future<UsageLog> recordUsage({
    required String collectionEntryId,
    required String purpose,
    String? intention,
    String? result,
    int? moodBefore,
    int? moodAfter,
    int? energyBefore,
    int? energyAfter,
  }) async {
    await initialize();
    
    // Create usage log
    final log = UsageLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      collectionEntryId: collectionEntryId,
      dateTime: DateTime.now(),
      purpose: purpose,
      intention: intention,
      result: result,
      moodBefore: moodBefore,
      moodAfter: moodAfter,
      energyBefore: energyBefore,
      energyAfter: energyAfter,
      moonPhase: MoonPhaseCalculator.getCurrentPhase(),
    );
    
    _usageLogs.add(log);
    
    // Update usage count
    final entryIndex = _collection.indexWhere((e) => e.id == collectionEntryId);
    if (entryIndex != -1) {
      _collection[entryIndex] = _collection[entryIndex].recordUsage();
    }
    
    await _saveCollection();
    await _saveUsageLogs();
    
    return log;
  }

  /// Get collection statistics
  static CollectionStats getStats() {
    return CollectionStats.fromCollection(_collection, _usageLogs);
  }

  /// Get crystals by purpose
  static List<CollectionEntry> getCrystalsByPurpose(String purpose) {
    return _collection.where((entry) => 
      entry.primaryUses.contains(purpose)
    ).toList();
  }

  /// Get crystals by chakra
  static List<CollectionEntry> getCrystalsByChakra(String chakra) {
    return _collection.where((entry) => 
      entry.crystal.chakras.contains(chakra)
    ).toList();
  }

  /// Get favorite crystals
  static List<CollectionEntry> getFavorites() {
    return _collection.where((entry) => entry.isFavorite).toList();
  }

  /// Get most used crystals
  static List<CollectionEntry> getMostUsed({int limit = 5}) {
    final sorted = List<CollectionEntry>.from(_collection)
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sorted.take(limit).toList();
  }

  /// Get usage logs for a specific crystal
  static List<UsageLog> getUsageLogsForCrystal(String collectionEntryId) {
    return _usageLogs.where((log) => 
      log.collectionEntryId == collectionEntryId
    ).toList();
  }

  /// Toggle favorite status
  static Future<void> toggleFavorite(String entryId) async {
    final index = _collection.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      final entry = _collection[index];
      _collection[index] = entry.copyWith(isFavorite: !entry.isFavorite);
      await _saveCollection();
    }
  }

  /// Search collection
  static List<CollectionEntry> searchCollection(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _collection.where((entry) {
      return entry.crystal.name.toLowerCase().contains(lowercaseQuery) ||
             entry.crystal.description.toLowerCase().contains(lowercaseQuery) ||
             entry.notes?.toLowerCase().contains(lowercaseQuery) == true ||
             entry.primaryUses.any((use) => use.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  /// Get AI recommendations context
  static Map<String, dynamic> getAIContext() {
    final stats = getStats();
    return {
      'collectionStats': stats.toAIContext(),
      'recentUsage': _getRecentUsageContext(),
      'preferences': _getUserPreferences(),
    };
  }

  /// Get recent usage context for AI
  static Map<String, dynamic> _getRecentUsageContext() {
    final recentLogs = _usageLogs.take(10).map((log) {
      final entry = _collection.firstWhere((e) => e.id == log.collectionEntryId);
      return {
        'crystal': entry.crystal.name,
        'purpose': log.purpose,
        'moodImprovement': log.moodAfter != null && log.moodBefore != null
            ? log.moodAfter! - log.moodBefore!
            : null,
        'energyImprovement': log.energyAfter != null && log.energyBefore != null
            ? log.energyAfter! - log.energyBefore!
            : null,
      };
    }).toList();
    
    return {
      'recentUsage': recentLogs,
      'totalUsageCount': _usageLogs.length,
    };
  }

  /// Get user preferences based on collection
  static Map<String, dynamic> _getUserPreferences() {
    final purposes = <String, int>{};
    final sizes = <String, int>{};
    final qualities = <String, int>{};
    
    for (final entry in _collection) {
      for (final purpose in entry.primaryUses) {
        purposes[purpose] = (purposes[purpose] ?? 0) + 1;
      }
      sizes[entry.size] = (sizes[entry.size] ?? 0) + 1;
      qualities[entry.quality] = (qualities[entry.quality] ?? 0) + 1;
    }
    
    return {
      'preferredPurposes': purposes,
      'preferredSizes': sizes,
      'preferredQualities': qualities,
    };
  }

  /// Save collection to local storage
  static Future<void> _saveCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_collection.map((e) => e.toJson()).toList());
    await prefs.setString(_collectionKey, json);
  }

  /// Save usage logs to local storage
  static Future<void> _saveUsageLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_usageLogs.map((e) => e.toJson()).toList());
    await prefs.setString(_usageLogsKey, json);
  }

  /// Sync collection with Firebase Firestore
  static Future<void> _syncWithFirebase() async {
    if (_firebaseService?.isAuthenticated != true) return;
    
    try {
      // Load from Firebase and merge with local data
      final firebaseCollection = await _firebaseService!.loadCrystalCollection();
      
      // Merge Firebase data with local data (Firebase is source of truth)
      if (firebaseCollection.isNotEmpty) {
        _collection = firebaseCollection;
        await _saveCollection(); // Update local storage
      } else if (_collection.isNotEmpty) {
        // Push local collection to Firebase if Firebase is empty
        await _firebaseService!.saveCrystalCollection(_collection);
      }
    } catch (e) {
      print('Firebase sync failed: $e');
      // Continue with local data if sync fails
    }
  }

  /// Start real-time sync with Firebase
  static void _startRealtimeSync() {
    if (_firebaseService?.isAuthenticated != true) return;
    
    try {
      _firebaseService!.getCrystalCollectionStream().listen(
        (firebaseCollection) {
          // Update local collection from Firebase real-time stream
          if (firebaseCollection.isNotEmpty) {
            _collection = firebaseCollection;
            _saveCollection(); // Update local storage
          }
        },
        onError: (error) {
          print('Real-time sync error: $error');
        },
      );
    } catch (e) {
      print('Failed to start real-time sync: $e');
    }
  }

  /// Get real-time collection stream
  static Stream<List<CollectionEntry>> getCollectionStream() {
    if (_firebaseService?.isAuthenticated == true) {
      return _firebaseService!.getCrystalCollectionStream();
    }
    
    // Return static stream if not authenticated
    return Stream.periodic(const Duration(seconds: 1), (_) => _collection);
  }

  /// Sync with backend (fallback)
  static Future<void> _syncWithBackend() async {
    // TODO: Implement backend sync when backend endpoints are ready
  }

  /// Sync single entry to backend (fallback)
  static Future<void> _syncEntryToBackend(CollectionEntry entry) async {
    // TODO: Implement backend sync when backend endpoints are ready
  }

  /// Clear all data (for logout)
  static Future<void> clear() async {
    _collection.clear();
    _usageLogs.clear();
    _isLoaded = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_collectionKey);
    await prefs.remove(_usageLogsKey);
  }
}

/// Moon phase calculator
class MoonPhaseCalculator {
  static String getCurrentPhase() {
    final now = DateTime.now();
    final newMoon = DateTime(2025, 1, 29); // Known new moon date
    final daysSince = now.difference(newMoon).inDays;
    final phase = (daysSince % 29.5) / 29.5;
    
    if (phase < 0.0625) return '🌑 New Moon';
    if (phase < 0.1875) return '🌒 Waxing Crescent';
    if (phase < 0.3125) return '🌓 First Quarter';
    if (phase < 0.4375) return '🌔 Waxing Gibbous';
    if (phase < 0.5625) return '🌕 Full Moon';
    if (phase < 0.6875) return '🌖 Waning Gibbous';
    if (phase < 0.8125) return '🌗 Last Quarter';
    return '🌘 Waning Crescent';
  }
}