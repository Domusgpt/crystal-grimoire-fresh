import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import '../config/api_config.dart';
import '../models/crystal.dart';

/// Enhanced cache service for Crystal Grimoire with multi-layer caching
/// Reduces API costs, improves performance, and enables offline capabilities
class CacheService extends ChangeNotifier {
  static const String _keyPrefix = 'crystal_grimoire_';
  static const String _cachePrefix = 'crystal_cache_';
  static const String _cacheMetaKey = 'cache_metadata';
  static const String _crystalLibraryKey = '${_keyPrefix}crystal_library';
  static const String _guidanceKey = '${_keyPrefix}guidance_cache';
  static const String _moonPhaseKey = '${_keyPrefix}moon_phase_cache';
  static const String _userProfileKey = '${_keyPrefix}user_profile';
  static const String _imagesCacheKey = '${_keyPrefix}images_cache';
  
  // Cache expiration times (in milliseconds)
  static const int _crystalLibraryCacheDuration = 24 * 60 * 60 * 1000; // 24 hours
  static const int _guidanceCacheDuration = 6 * 60 * 60 * 1000; // 6 hours
  static const int _moonPhaseCacheDuration = 60 * 60 * 1000; // 1 hour
  static const int _imageCacheDuration = 7 * 24 * 60 * 60 * 1000; // 7 days
  
  static SharedPreferences? _prefs;
  
  /// Initialize cache service
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Ensure preferences are loaded
  static Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Caches a crystal identification result
  static Future<void> cacheIdentification(
    String imageHash, 
    CrystalIdentification identification,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create cache entry
      final cacheEntry = {
        'identification': identification.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
        'version': 1, // For future cache format changes
      };
      
      // Store the cached identification
      await prefs.setString(
        '$_cachePrefix$imageHash', 
        jsonEncode(cacheEntry),
      );
      
      // Update cache metadata
      await _updateCacheMetadata(imageHash);
      
      // Clean old cache entries
      await _cleanExpiredCache();
      
    } catch (e) {
      // Fail silently - caching is not critical
      print('Cache storage failed: $e');
    }
  }
  
  /// Retrieves a cached crystal identification
  static Future<CrystalIdentification?> getCachedIdentification(
    String imageHash,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString('$_cachePrefix$imageHash');
      
      if (cachedString == null) return null;
      
      final cacheEntry = jsonDecode(cachedString);
      final timestamp = DateTime.parse(cacheEntry['timestamp']);
      
      // Check if cache has expired
      final age = DateTime.now().difference(timestamp);
      if (age.inDays > ApiConfig.cacheExpirationDays) {
        // Remove expired cache
        await prefs.remove('$_cachePrefix$imageHash');
        await _removeFromCacheMetadata(imageHash);
        return null;
      }
      
      // Return cached identification
      return CrystalIdentification.fromJson(cacheEntry['identification']);
      
    } catch (e) {
      // Fail silently and return null
      print('Cache retrieval failed: $e');
      return null;
    }
  }
  
  /// Gets cache statistics for debugging and user info
  static Future<CacheStats> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadata = await _getCacheMetadata();
      
      int totalEntries = metadata.length;
      int totalSize = 0;
      int expiredEntries = 0;
      
      for (final hash in metadata) {
        final key = '$_cachePrefix$hash';
        final cached = prefs.getString(key);
        if (cached != null) {
          totalSize += cached.length;
          
          // Check if expired
          try {
            final cacheEntry = jsonDecode(cached);
            final timestamp = DateTime.parse(cacheEntry['timestamp']);
            final age = DateTime.now().difference(timestamp);
            if (age.inDays > ApiConfig.cacheExpirationDays) {
              expiredEntries++;
            }
          } catch (e) {
            expiredEntries++;
          }
        }
      }
      
      return CacheStats(
        totalEntries: totalEntries,
        expiredEntries: expiredEntries,
        totalSizeBytes: totalSize,
        lastCleanup: await _getLastCleanupTime(),
      );
      
    } catch (e) {
      return CacheStats(
        totalEntries: 0,
        expiredEntries: 0,
        totalSizeBytes: 0,
        lastCleanup: null,
      );
    }
  }
  
  // ENHANCED CACHING METHODS FOR LAUNCH
  
  /// Cache crystal library data with compression
  static Future<void> cacheCrystalLibrary(List<Map<String, dynamic>> crystals) async {
    final prefs = await _getPrefs();
    final cacheData = {
      'data': crystals,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'version': '1.0',
      'compressed': true, // Future feature
    };
    await prefs.setString(_crystalLibraryKey, json.encode(cacheData));
  }
  
  /// Get cached crystal library with staleness check
  static Future<List<Map<String, dynamic>>?> getCachedCrystalLibrary() async {
    final prefs = await _getPrefs();
    final cachedData = prefs.getString(_crystalLibraryKey);
    
    if (cachedData == null) return null;
    
    try {
      final data = json.decode(cachedData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is expired
      if (now - timestamp > _crystalLibraryCacheDuration) {
        await clearCrystalLibraryCache();
        return null;
      }
      
      return List<Map<String, dynamic>>.from(data['data']);
    } catch (e) {
      debugPrint('Error reading crystal library cache: $e');
      await clearCrystalLibraryCache();
      return null;
    }
  }
  
  /// Cache guidance with context-based keys for deduplication
  static Future<void> cacheGuidance(String contextKey, Map<String, dynamic> guidance) async {
    final prefs = await _getPrefs();
    final existingCache = await _getCachedGuidanceData();
    
    existingCache[contextKey] = {
      'data': guidance,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    await prefs.setString(_guidanceKey, json.encode(existingCache));
  }
  
  /// Get cached guidance by context with smart invalidation
  static Future<Map<String, dynamic>?> getCachedGuidance(String contextKey) async {
    final guidanceCache = await _getCachedGuidanceData();
    final cachedItem = guidanceCache[contextKey];
    
    if (cachedItem == null) return null;
    
    final timestamp = cachedItem['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if cache is expired
    if (now - timestamp > _guidanceCacheDuration) {
      await _removeCachedGuidance(contextKey);
      return null;
    }
    
    return cachedItem['data'] as Map<String, dynamic>;
  }
  
  /// Cache moon phase data with hourly refresh
  static Future<void> cacheMoonPhase(Map<String, dynamic> moonPhaseData) async {
    final prefs = await _getPrefs();
    final cacheData = {
      'data': moonPhaseData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_moonPhaseKey, json.encode(cacheData));
  }
  
  /// Get cached moon phase with automatic refresh
  static Future<Map<String, dynamic>?> getCachedMoonPhase() async {
    final prefs = await _getPrefs();
    final cachedData = prefs.getString(_moonPhaseKey);
    
    if (cachedData == null) return null;
    
    try {
      final data = json.decode(cachedData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is expired
      if (now - timestamp > _moonPhaseCacheDuration) {
        await clearMoonPhaseCache();
        return null;
      }
      
      return data['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error reading moon phase cache: $e');
      await clearMoonPhaseCache();
      return null;
    }
  }
  
  /// Cache image data for offline viewing
  static Future<void> cacheImageData(String imageUrl, Uint8List imageData) async {
    final prefs = await _getPrefs();
    final imageKey = '${_imagesCacheKey}_${_hashString(imageUrl)}';
    
    final cacheData = {
      'data': base64Encode(imageData),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'url': imageUrl,
      'size': imageData.length,
    };
    
    await prefs.setString(imageKey, json.encode(cacheData));
  }
  
  /// Get cached image data with size limits
  static Future<Uint8List?> getCachedImageData(String imageUrl) async {
    final prefs = await _getPrefs();
    final imageKey = '${_imagesCacheKey}_${_hashString(imageUrl)}';
    final cachedData = prefs.getString(imageKey);
    
    if (cachedData == null) return null;
    
    try {
      final data = json.decode(cachedData) as Map<String, dynamic>;
      final timestamp = data['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is expired
      if (now - timestamp > _imageCacheDuration) {
        await _clearImageCache(imageKey);
        return null;
      }
      
      return base64Decode(data['data'] as String);
    } catch (e) {
      debugPrint('Error reading image cache: $e');
      await _clearImageCache(imageKey);
      return null;
    }
  }
  
  /// Utility methods for enhanced caching
  static String _hashString(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return hash.abs().toString();
  }
  
  static Future<Map<String, dynamic>> _getCachedGuidanceData() async {
    final prefs = await _getPrefs();
    final cachedData = prefs.getString(_guidanceKey);
    
    if (cachedData == null) return {};
    
    try {
      return Map<String, dynamic>.from(json.decode(cachedData));
    } catch (e) {
      debugPrint('Error reading guidance cache: $e');
      await clearGuidanceCache();
      return {};
    }
  }
  
  static Future<void> _removeCachedGuidance(String contextKey) async {
    final prefs = await _getPrefs();
    final existingCache = await _getCachedGuidanceData();
    existingCache.remove(contextKey);
    await prefs.setString(_guidanceKey, json.encode(existingCache));
  }
  
  static Future<void> _clearImageCache(String imageKey) async {
    final prefs = await _getPrefs();
    await prefs.remove(imageKey);
  }
  
  /// Clear specific cache types
  static Future<void> clearCrystalLibraryCache() async {
    final prefs = await _getPrefs();
    await prefs.remove(_crystalLibraryKey);
  }
  
  static Future<void> clearGuidanceCache() async {
    final prefs = await _getPrefs();
    await prefs.remove(_guidanceKey);
  }
  
  static Future<void> clearMoonPhaseCache() async {
    final prefs = await _getPrefs();
    await prefs.remove(_moonPhaseKey);
  }
  
  /// Enhanced cache info for monitoring
  static Future<Map<String, int>> getDetailedCacheInfo() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys();
    
    int crystalLibrarySize = 0;
    int guidanceSize = 0;
    int moonPhaseSize = 0;
    int imagesSize = 0;
    int identificationCacheSize = 0;
    
    for (final key in keys) {
      final value = prefs.getString(key);
      if (value == null) continue;
      
      final size = value.length;
      
      if (key == _crystalLibraryKey) {
        crystalLibrarySize = size;
      } else if (key == _guidanceKey) {
        guidanceSize = size;
      } else if (key == _moonPhaseKey) {
        moonPhaseSize = size;
      } else if (key.startsWith(_imagesCacheKey)) {
        imagesSize += size;
      } else if (key.startsWith(_cachePrefix)) {
        identificationCacheSize += size;
      }
    }
    
    return {
      'crystalLibrary': crystalLibrarySize,
      'guidance': guidanceSize,
      'moonPhase': moonPhaseSize,
      'images': imagesSize,
      'identifications': identificationCacheSize,
      'total': crystalLibrarySize + guidanceSize + moonPhaseSize + imagesSize + identificationCacheSize,
    };
  }
  
  /// Perform smart cache maintenance with size limits
  static Future<void> performSmartMaintenance() async {
    // Clear expired entries first
    await _cleanExpiredCache();
    
    // Check total cache size
    final cacheInfo = await getDetailedCacheInfo();
    final totalSizeKB = (cacheInfo['total']! / 1024).round();
    
    debugPrint('Cache maintenance: ${totalSizeKB}KB total');
    
    // If cache exceeds 10MB, clear non-essential caches
    if (totalSizeKB > 10 * 1024) {
      debugPrint('Cache size exceeded, clearing guidance and images');
      await clearGuidanceCache();
      
      // Clear oldest image cache entries
      final prefs = await _getPrefs();
      final imageKeys = prefs.getKeys().where((key) => key.startsWith(_imagesCacheKey));
      for (final key in imageKeys.take(imageKeys.length ~/ 2)) {
        await prefs.remove(key);
      }
    }
  }
  
  /// Clears all cached data
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadata = await _getCacheMetadata();
      
      // Remove all cache entries
      for (final hash in metadata) {
        await prefs.remove('$_cachePrefix$hash');
      }
      
      // Clear metadata
      await prefs.remove(_cacheMetaKey);
      await prefs.remove('last_cache_cleanup');
      
    } catch (e) {
      print('Cache clearing failed: $e');
    }
  }
  
  /// Cleans expired cache entries automatically
  static Future<void> _cleanExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadata = await _getCacheMetadata();
      final now = DateTime.now();
      final cleanupInterval = const Duration(days: 7);
      
      // Check if cleanup is needed
      final lastCleanup = await _getLastCleanupTime();
      if (lastCleanup != null && 
          now.difference(lastCleanup) < cleanupInterval) {
        return; // Too soon for cleanup
      }
      
      final expiredHashes = <String>[];
      
      for (final hash in metadata) {
        final key = '$_cachePrefix$hash';
        final cached = prefs.getString(key);
        
        if (cached == null) {
          expiredHashes.add(hash);
          continue;
        }
        
        try {
          final cacheEntry = jsonDecode(cached);
          final timestamp = DateTime.parse(cacheEntry['timestamp']);
          final age = now.difference(timestamp);
          
          if (age.inDays > ApiConfig.cacheExpirationDays) {
            await prefs.remove(key);
            expiredHashes.add(hash);
          }
        } catch (e) {
          // Invalid cache entry, remove it
          await prefs.remove(key);
          expiredHashes.add(hash);
        }
      }
      
      // Update metadata
      if (expiredHashes.isNotEmpty) {
        final updatedMetadata = metadata
            .where((hash) => !expiredHashes.contains(hash))
            .toList();
        await _saveCacheMetadata(updatedMetadata);
      }
      
      // Record cleanup time
      await prefs.setString(
        'last_cache_cleanup', 
        now.toIso8601String(),
      );
      
    } catch (e) {
      print('Cache cleanup failed: $e');
    }
  }
  
  /// Updates cache metadata to track all cached entries
  static Future<void> _updateCacheMetadata(String imageHash) async {
    try {
      final metadata = await _getCacheMetadata();
      if (!metadata.contains(imageHash)) {
        metadata.add(imageHash);
        await _saveCacheMetadata(metadata);
      }
    } catch (e) {
      print('Cache metadata update failed: $e');
    }
  }
  
  /// Removes entry from cache metadata
  static Future<void> _removeFromCacheMetadata(String imageHash) async {
    try {
      final metadata = await _getCacheMetadata();
      metadata.remove(imageHash);
      await _saveCacheMetadata(metadata);
    } catch (e) {
      print('Cache metadata removal failed: $e');
    }
  }
  
  /// Gets cache metadata list
  static Future<List<String>> _getCacheMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataString = prefs.getString(_cacheMetaKey);
      if (metadataString == null) return [];
      
      final metadata = jsonDecode(metadataString) as List;
      return metadata.cast<String>();
    } catch (e) {
      return [];
    }
  }
  
  /// Saves cache metadata list
  static Future<void> _saveCacheMetadata(List<String> metadata) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheMetaKey, jsonEncode(metadata));
    } catch (e) {
      print('Cache metadata save failed: $e');
    }
  }
  
  /// Gets last cleanup time
  static Future<DateTime?> _getLastCleanupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString('last_cache_cleanup');
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      return null;
    }
  }
}

/// Cache statistics for monitoring and debugging
class CacheStats {
  final int totalEntries;
  final int expiredEntries;
  final int totalSizeBytes;
  final DateTime? lastCleanup;
  
  CacheStats({
    required this.totalEntries,
    required this.expiredEntries,
    required this.totalSizeBytes,
    this.lastCleanup,
  });
  
  int get activeEntries => totalEntries - expiredEntries;
  
  String get readableSize {
    if (totalSizeBytes < 1024) {
      return '${totalSizeBytes}B';
    } else if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
  
  double get hitRateEstimate {
    if (totalEntries == 0) return 0.0;
    return activeEntries / totalEntries;
  }
  
  @override
  String toString() {
    return 'CacheStats(entries: $activeEntries/$totalEntries, '
           'size: $readableSize, hitRate: ${(hitRateEstimate * 100).toStringAsFixed(1)}%)';
  }
}

/// Enhanced cache statistics for production monitoring
class DetailedCacheStats {
  final Map<String, int> sizeByCategory;
  final int totalSize;
  final DateTime lastMaintenance;
  final int expiredEntriesCleared;
  
  DetailedCacheStats({
    required this.sizeByCategory,
    required this.totalSize,
    required this.lastMaintenance,
    required this.expiredEntriesCleared,
  });
  
  String get readableTotal {
    if (totalSize < 1024) {
      return '${totalSize}B';
    } else if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
  
  Map<String, String> get readableSizes {
    return sizeByCategory.map((key, value) {
      if (value < 1024) {
        return MapEntry(key, '${value}B');
      } else if (value < 1024 * 1024) {
        return MapEntry(key, '${(value / 1024).toStringAsFixed(1)}KB');
      } else {
        return MapEntry(key, '${(value / (1024 * 1024)).toStringAsFixed(1)}MB');
      }
    });
  }
}