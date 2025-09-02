import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/crystal_collection.dart';
import '../models/crystal.dart';
import 'backend_service.dart';

/// Production-ready Collection Service with proper instance management
/// This is NOT a static service - it uses proper dependency injection
class CollectionServiceV2 extends ChangeNotifier {
  static const String _collectionKey = 'crystal_collection_v2';
  static const String _usageLogsKey = 'crystal_usage_logs_v2';
  
  List<CollectionEntry> _collection = [];
  List<UsageLog> _usageLogs = [];
  bool _isLoaded = false;
  bool _isSyncing = false;
  String? _lastError;
  
  /// Get the current collection
  List<CollectionEntry> get collection => List.unmodifiable(_collection);
  
  /// Get usage logs
  List<UsageLog> get usageLogs => List.unmodifiable(_usageLogs);
  
  /// Check if service is loaded
  bool get isLoaded => _isLoaded;
  
  /// Check if syncing with backend
  bool get isSyncing => _isSyncing;
  
  /// Get last error
  String? get lastError => _lastError;
  
  /// Initialize the collection service
  Future<void> initialize() async {
    if (_isLoaded) return;
    
    try {
      await _loadFromLocal();
      _isLoaded = true;
      notifyListeners();
      
      // Sync with backend if needed
      // await syncWithBackend(); // TODO: Enable when backend is ready
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }
  
  /// Load collection from local storage
  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load collection
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
  }
  
  /// Save collection to local storage
  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save collection
    final collectionJson = json.encode(_collection.map((e) => e.toJson()).toList());
    await prefs.setString(_collectionKey, collectionJson);
    
    // Save usage logs
    final logsJson = json.encode(_usageLogs.map((e) => e.toJson()).toList());
    await prefs.setString(_usageLogsKey, logsJson);
  }
  
  /// Add a crystal to the collection
  Future<CollectionEntry> addCrystal(Crystal crystal, {
    String? notes,
    String? source,
    double? purchasePrice,
    List<String>? primaryUses,
    Map<String, dynamic>? customProperties,
    String? location,
    String size = 'medium',
    String quality = 'tumbled',
    List<String>? images,
  }) async {
    final entry = CollectionEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'local-user', // TODO: Get from auth service
      crystal: crystal,
      dateAdded: DateTime.now(),
      notes: notes,
      source: source ?? 'Personal Collection',
      price: purchasePrice,
      customProperties: customProperties ?? {},
      primaryUses: primaryUses ?? [],
      images: images ?? [],
      isFavorite: false,
      size: size,
      quality: quality,
      location: location,
    );
    
    _collection.add(entry);
    await _saveToLocal();
    notifyListeners();
    
    // Sync with backend if needed
    // await _syncEntryToBackend(entry); // TODO: Enable when backend is ready
    
    return entry;
  }
  
  /// Update a crystal in the collection
  Future<void> updateCrystal(String entryId, {
    String? notes,
    List<String>? primaryUses,
    Map<String, dynamic>? customProperties,
    bool? isFavorite,
    List<String>? images,
    String? size,
    String? quality,
    double? userRating,
  }) async {
    final index = _collection.indexWhere((e) => e.id == entryId);
    if (index == -1) return;
    
    final entry = _collection[index];
    final updated = CollectionEntry(
      id: entry.id,
      userId: entry.userId,
      crystal: entry.crystal,
      dateAdded: entry.dateAdded,
      notes: notes ?? entry.notes,
      source: entry.source,
      price: entry.price,
      location: entry.location,
      customProperties: customProperties ?? entry.customProperties,
      primaryUses: primaryUses ?? entry.primaryUses,
      images: images ?? entry.images,
      isFavorite: isFavorite ?? entry.isFavorite,
      size: size ?? entry.size,
      quality: quality ?? entry.quality,
      usageCount: entry.usageCount,
      userRating: userRating ?? entry.userRating,
      isActive: entry.isActive,
    );
    
    _collection[index] = updated;
    await _saveToLocal();
    notifyListeners();
    
    // Sync with backend if needed
    // await _syncEntryToBackend(updated); // TODO: Enable when backend is ready
  }
  
  /// Remove a crystal from the collection
  Future<void> removeCrystal(String entryId) async {
    _collection.removeWhere((e) => e.id == entryId);
    await _saveToLocal();
    notifyListeners();
    
    // Sync deletion with backend if needed
    // await _deleteFromBackend(entryId); // TODO: Enable when backend is ready
  }
  
  /// Log crystal usage
  Future<void> logUsage(String entryId, {
    required String purpose,
    String? intention,
    String? result,
    int? moodBefore,
    int? moodAfter,
    int? energyBefore,
    int? energyAfter,
    String? moonPhase,
  }) async {
    final log = UsageLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      collectionEntryId: entryId,
      dateTime: DateTime.now(),
      purpose: purpose,
      intention: intention,
      result: result,
      moodBefore: moodBefore,
      moodAfter: moodAfter,
      energyBefore: energyBefore,
      energyAfter: energyAfter,
      moonPhase: moonPhase,
    );
    
    _usageLogs.add(log);
    
    // Update usage count
    final index = _collection.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      final entry = _collection[index];
      _collection[index] = entry.copyWith(
        usageCount: entry.usageCount + 1,
      );
    }
    
    await _saveToLocal();
    notifyListeners();
  }
  
  /// Get crystals by chakra
  List<CollectionEntry> getCrystalsByChakra(String chakra) {
    return _collection.where((entry) => 
      entry.crystal.chakras.contains(chakra)
    ).toList();
  }
  
  /// Get crystals by purpose
  List<CollectionEntry> getCrystalsByPurpose(String purpose) {
    return _collection.where((entry) => 
      entry.crystal.metaphysicalProperties.any((prop) => 
        prop.toLowerCase().contains(purpose.toLowerCase())
      )
    ).toList();
  }
  
  /// Get crystals by element
  List<CollectionEntry> getCrystalsByElement(String element) {
    return _collection.where((entry) => 
      entry.crystal.elements.contains(element)
    ).toList();
  }
  
  /// Get favorite crystals
  List<CollectionEntry> getFavorites() {
    return _collection.where((entry) => entry.isFavorite).toList();
  }
  
  /// Get recently used crystals
  List<CollectionEntry> getRecentlyUsed({int limit = 5}) {
    // Map to store last used date for each crystal
    final lastUsedMap = <String, DateTime>{};
    
    // Find the most recent usage for each crystal
    for (final log in _usageLogs) {
      final currentDate = lastUsedMap[log.collectionEntryId];
      if (currentDate == null || log.dateTime.isAfter(currentDate)) {
        lastUsedMap[log.collectionEntryId] = log.dateTime;
      }
    }
    
    // Sort collection by last used date
    final entriesWithUsage = _collection
        .where((e) => lastUsedMap.containsKey(e.id))
        .toList()
      ..sort((a, b) => 
        lastUsedMap[b.id]!.compareTo(lastUsedMap[a.id]!));
    
    return entriesWithUsage.take(limit).toList();
  }
  
  /// Get last used date for a specific crystal
  DateTime? getLastUsedDate(String entryId) {
    final logs = _usageLogs.where((log) => log.collectionEntryId == entryId);
    if (logs.isEmpty) return null;
    
    return logs
        .map((log) => log.dateTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }
  
  /// Get collection statistics
  CollectionStats getStats() {
    return CollectionStats.fromCollection(_collection, _usageLogs);
  }
  
  /// Search crystals
  List<CollectionEntry> searchCrystals(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _collection.where((entry) {
      return entry.crystal.name.toLowerCase().contains(lowercaseQuery) ||
             entry.crystal.scientificName.toLowerCase().contains(lowercaseQuery) ||
             entry.crystal.description.toLowerCase().contains(lowercaseQuery) ||
             (entry.notes?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }
  
  /// Sync with backend
  Future<void> syncWithBackend() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      // Get collection from backend - stub implementation
      final backendData = <String, dynamic>{}; // TODO: Implement real backend sync
      
      if (backendData != null && backendData['collection'] != null) {
        final List<dynamic> backendCollection = backendData['collection'];
        _collection = backendCollection.map((e) => CollectionEntry.fromJson(e)).toList();
        await _saveToLocal();
      }
      
      _lastError = null;
    } catch (e) {
      _lastError = 'Sync failed: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Sync single entry to backend
  Future<void> _syncEntryToBackend(CollectionEntry entry) async {
    // TODO: Implement real backend sync
    print('Would sync entry to backend: ${entry.id}');
  }
  
  /// Delete entry from backend
  Future<void> _deleteFromBackend(String entryId) async {
    // TODO: Implement real backend deletion
    print('Would delete entry from backend: $entryId');
  }
  
  /// Export collection data
  Map<String, dynamic> exportCollection() {
    return {
      'version': '2.0',
      'exported_at': DateTime.now().toIso8601String(),
      'collection': _collection.map((e) => e.toJson()).toList(),
      'usage_logs': _usageLogs.map((e) => e.toJson()).toList(),
      'stats': getStats().toAIContext(),
    };
  }
  
  /// Import collection data
  Future<void> importCollection(Map<String, dynamic> data) async {
    if (data['version'] != '2.0') {
      throw Exception('Incompatible collection version');
    }
    
    final List<dynamic> collectionData = data['collection'] ?? [];
    final List<dynamic> logsData = data['usage_logs'] ?? [];
    
    _collection = collectionData.map((e) => CollectionEntry.fromJson(e)).toList();
    _usageLogs = logsData.map((e) => UsageLog.fromJson(e)).toList();
    
    await _saveToLocal();
    notifyListeners();
    
    // Sync with backend if needed
    // await syncWithBackend(); // TODO: Enable when backend is ready
  }
  
  /// Clear all data
  Future<void> clearAll() async {
    _collection.clear();
    _usageLogs.clear();
    await _saveToLocal();
    notifyListeners();
  }
}