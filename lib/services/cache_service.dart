import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/crystal.dart';

/// Service for caching crystal identifications to reduce API costs
/// and improve user experience with offline capabilities
class CacheService {
  static const String _cachePrefix = 'crystal_cache_';
  static const String _cacheMetaKey = 'cache_metadata';
  
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