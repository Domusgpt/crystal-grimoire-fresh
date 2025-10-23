import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/crystal_collection.dart';
import '../models/crystal.dart';
import 'firebase_guard.dart';

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
  String? _userId;
  StreamSubscription<User?>? _authSubscription;
  FirebaseFirestore? get _firestore => FirebaseGuard.firestore;
  FirebaseAuth? get _auth => FirebaseGuard.auth;
  bool get _hasFirebaseApp => FirebaseGuard.isConfigured;
  final Map<String, Crystal> _libraryCache = {};
  
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
      if (!_hasFirebaseApp) {
        _lastError =
            'Firebase not configured. Collection sync is running in offline mode.';
        _isLoaded = true;
        notifyListeners();
        return;
      }

      _authSubscription = _auth.authStateChanges().listen(_handleAuthChange);
      await _handleAuthChange(_auth.currentUser);
      _isLoaded = true;
      notifyListeners();

    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
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

  Future<void> _handleAuthChange(User? user) async {
    if (!_hasFirebaseApp) {
      return;
    }

    _userId = user?.uid;

    if (user == null) {
      _collection.clear();
      _usageLogs.clear();
      await _saveToLocal();
      notifyListeners();
      return;
    }

    await _loadFromBackend(user.uid);
  }

  CollectionReference<Map<String, dynamic>>? _collectionRef(String uid) {
    final store = _firestore;
    if (store == null) return null;
    return store.collection('users').doc(uid).collection('collection');
  }

  CollectionReference<Map<String, dynamic>>? _usageLogsRef(String uid) {
    final store = _firestore;
    if (store == null) return null;
    return store.collection('users').doc(uid).collection('collectionLogs');
  }

  Future<void> _loadFromBackend(String uid) async {
    if (!_hasFirebaseApp) {
      _lastError = 'Firebase not configured. Unable to sync collection.';
      notifyListeners();
      return;
    }

    final collectionRef = _collectionRef(uid);
    final logsRef = _usageLogsRef(uid);
    if (collectionRef == null || logsRef == null) {
      _lastError = 'Firebase not configured. Unable to sync collection.';
      notifyListeners();
      return;
    }

    try {
      final collectionSnapshot = await collectionRef
          .orderBy('addedAt', descending: true)
          .get();
      final logsSnapshot = await logsRef
          .orderBy('dateTime', descending: true)
          .limit(200)
          .get();

      final entries = await Future.wait(collectionSnapshot.docs.map((doc) async {
        final data = Map<String, dynamic>.from(doc.data());
        final libraryRef = (data['libraryRef'] ?? '').toString();
        final crystal = await _fetchCrystalFromLibrary(libraryRef);
        final tags = _stringList(data['tags']);
        final notes = data['notes']?.toString();
        final addedAt = _parseTimestamp(data['addedAt']) ?? DateTime.now();

        return CollectionEntry(
          id: doc.id,
          userId: uid,
          crystal: crystal.copyWith(
            userNotes: notes,
            metaphysicalProperties:
                tags.isNotEmpty ? tags : crystal.metaphysicalProperties,
          ),
          dateAdded: addedAt,
          source: 'Personal Collection',
          location: null,
          price: null,
          size: 'medium',
          quality: 'tumbled',
          primaryUses: tags,
          usageCount: 0,
          userRating: 0,
          notes: notes,
          images: List<String>.from(data['images'] ?? const <String>[]),
          isActive: true,
          isFavorite: data['isFavorite'] == true,
          customProperties: {
            ...(data['customProperties'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(data['customProperties'])
                : <String, dynamic>{}),
            'libraryRef': libraryRef,
            'tags': tags,
          },
          libraryRef: libraryRef,
        );
      }));

      _collection = entries;

      _usageLogs = logsSnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return UsageLog.fromJson(data);
      }).toList();

      await _saveToLocal();
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to load collection: $e';
      notifyListeners();
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
    final uid = _userId ?? _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Cannot add a crystal without an authenticated user.');
    }

    _userId = uid;
    final entryId = _collectionRef(uid).doc().id;
    final libraryRef = _normalizeLibraryRef(crystal);
    final entry = CollectionEntry(
      id: entryId,
      userId: uid,
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
      libraryRef: libraryRef,
    );

    _collection.add(entry);
    await _saveToLocal();
    notifyListeners();

    await _syncEntryToBackend(entry);

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
      libraryRef: entry.libraryRef,
    );
    
    _collection[index] = updated;
    await _saveToLocal();
    notifyListeners();

    if (_userId != null) {
      await _syncEntryToBackend(updated);
    }
  }

  /// Remove a crystal from the collection
  Future<void> removeCrystal(String entryId) async {
    _collection.removeWhere((e) => e.id == entryId);
    await _saveToLocal();
    notifyListeners();

    if (_userId != null) {
      await _deleteFromBackend(entryId);
    }
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
    CollectionEntry? updatedEntry;
    if (index != -1) {
      final entry = _collection[index];
      updatedEntry = entry.copyWith(
        usageCount: entry.usageCount + 1,
      );
      _collection[index] = updatedEntry;
    }

    await _saveToLocal();
    notifyListeners();

    if (_userId != null) {
      await _syncUsageLog(log);
      if (updatedEntry != null) {
        await _syncEntryToBackend(updatedEntry);
      }
    }
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
    if (_isSyncing || _userId == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await _loadFromBackend(_userId!);
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
    final uid = _userId;
    if (uid == null) return;

    final docRef = _collectionRef(uid).doc(entry.id);
    final payload = <String, dynamic>{
      'libraryRef': entry.libraryRef,
      'notes': entry.notes ?? '',
      'tags': List<String>.from(entry.primaryUses),
      'addedAt': Timestamp.fromDate(entry.dateAdded),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await docRef.set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to sync collection entry ${entry.id}: $e');
      rethrow;
    }
  }

  /// Delete entry from backend
  Future<void> _deleteFromBackend(String entryId) async {
    final uid = _userId;
    if (uid == null) return;

    await _collectionRef(uid).doc(entryId).delete();

    final logs = await _usageLogsRef(uid)
        .where('collectionEntryId', isEqualTo: entryId)
        .get();

    for (final doc in logs.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _syncUsageLog(UsageLog log) async {
    final uid = _userId;
    if (uid == null) return;

    final data = log.toJson();
    await _usageLogsRef(uid).doc(log.id).set(data, SetOptions(merge: true));
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
    
  }
  
  /// Clear all data
  Future<void> clearAll() async {
    _collection.clear();
    _usageLogs.clear();
    await _saveToLocal();
    notifyListeners();
  }

  String _normalizeLibraryRef(Crystal crystal) {
    final id = crystal.id.trim();
    if (id.isNotEmpty) {
      return id;
    }
    return _slugify(crystal.name);
  }

  List<String> _stringList(dynamic input) {
    if (input is Iterable) {
      return input
          .map((value) => value?.toString() ?? '')
          .where((value) => value.trim().isNotEmpty)
          .map((value) => value.trim())
          .toList();
    }
    return const <String>[];
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<Crystal> _fetchCrystalFromLibrary(String libraryRef) async {
    final key = libraryRef.trim();
    if (key.isNotEmpty && _libraryCache.containsKey(key)) {
      return _libraryCache[key]!;
    }

    final store = _firestore;
    if (store == null) {
      return _offlineCrystalFallback(key);
    }

    DocumentReference<Map<String, dynamic>> docRef;
    if (key.contains('/')) {
      docRef = store.doc(key);
    } else {
      docRef = store.collection('crystal_library').doc(
        key.isNotEmpty ? key : _slugify('mystery'),
      );
    }

    try {
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data != null) {
        final payload = Map<String, dynamic>.from(data)
          ..putIfAbsent('id', () => snapshot.id)
          ..putIfAbsent('name', () => 'Mystery Crystal')
          ..putIfAbsent('scientificName', () => '')
          ..putIfAbsent('description', () => '')
          ..putIfAbsent('careInstructions', () => '')
          ..putIfAbsent('metaphysicalProperties', () => const <String>[])
          ..putIfAbsent('healingProperties', () => const <String>[])
          ..putIfAbsent('chakras', () => const <String>[])
          ..putIfAbsent('elements', () => const <String>[])
          ..putIfAbsent('imageUrls', () => const <String>[]);

        final crystal = Crystal.fromJson(payload);
        _libraryCache[key.isNotEmpty ? key : payload['id'].toString()] = crystal;
        return crystal;
      }
    } catch (e) {
      debugPrint('Failed to load crystal library reference "$key": $e');
    }

    final fallback = _offlineCrystalFallback(key);
    if (key.isNotEmpty) {
      _libraryCache[key] = fallback;
    }

    return fallback;
  }

  Crystal _offlineCrystalFallback(String key) {
    final fallbackId = key.isNotEmpty ? key : _slugify('mystery');
    return Crystal(
      id: fallbackId,
      name: key.isNotEmpty
          ? key.replaceAll('-', ' ').split('/').last.trim().toUpperCase()
          : 'Mystery Crystal',
      scientificName: '',
      description:
          'Crystal details will sync once Firebase is configured for the collection service.',
      careInstructions: 'Keep exploring offline while setup completes.',
    );
  }

  String _slugify(String value) {
    final sanitized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (sanitized.isEmpty) {
      return 'crystal-${DateTime.now().millisecondsSinceEpoch}';
    }

    return sanitized;
  }
}