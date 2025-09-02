import 'package:flutter/material.dart';
import 'crystal.dart';
import 'crystal_v2.dart' as v2;

/// Represents a crystal in the user's collection
class CollectionEntry {
  final String id;
  final String userId;
  final Crystal crystal;
  final DateTime dateAdded;
  final String source; // Where/how acquired: "purchased", "gifted", "found", "inherited"
  final String? location; // Where acquired/found
  final double? price; // If purchased
  final String size; // "small", "medium", "large", "pocket", "specimen"
  final String quality; // "raw", "tumbled", "polished", "cluster", "point"
  final List<String> primaryUses; // "meditation", "healing", "protection", "manifestation"
  final int usageCount; // How many times used
  final double userRating; // 1-5 stars
  final String? notes; // Personal notes
  final List<String> images; // Multiple photos of their specific crystal
  final bool isActive; // Currently in use/displayed
  final bool isFavorite;
  final Map<String, dynamic> customProperties; // For future expansion

  CollectionEntry({
    required this.id,
    required this.userId,
    required this.crystal,
    required this.dateAdded,
    required this.source,
    this.location,
    this.price,
    required this.size,
    required this.quality,
    required this.primaryUses,
    this.usageCount = 0,
    this.userRating = 0.0,
    this.notes,
    required this.images,
    this.isActive = true,
    this.isFavorite = false,
    Map<String, dynamic>? customProperties,
  }) : customProperties = customProperties ?? {};

  /// Create a new collection entry
  factory CollectionEntry.create({
    required String userId,
    required Crystal crystal,
    required String source,
    String? location,
    double? price,
    required String size,
    required String quality,
    List<String>? primaryUses,
    String? notes,
    List<String>? images,
  }) {
    return CollectionEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      crystal: crystal,
      dateAdded: DateTime.now(),
      source: source,
      location: location,
      price: price,
      size: size,
      quality: quality,
      primaryUses: primaryUses ?? [],
      images: images ?? [],
      notes: notes,
    );
  }

  /// Convert to JSON for storage/API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'crystal': crystal.toJson(),
      'dateAdded': dateAdded.toIso8601String(),
      'source': source,
      'location': location,
      'price': price,
      'size': size,
      'quality': quality,
      'primaryUses': primaryUses,
      'usageCount': usageCount,
      'userRating': userRating,
      'notes': notes,
      'images': images,
      'isActive': isActive,
      'isFavorite': isFavorite,
      'customProperties': customProperties,
    };
  }

  /// Create from JSON
  factory CollectionEntry.fromJson(Map<String, dynamic> json) {
    return CollectionEntry(
      id: json['id'],
      userId: json['userId'],
      crystal: Crystal.fromJson(json['crystal']),
      dateAdded: DateTime.parse(json['dateAdded']),
      source: json['source'],
      location: json['location'],
      price: json['price']?.toDouble(),
      size: json['size'],
      quality: json['quality'],
      primaryUses: List<String>.from(json['primaryUses'] ?? []),
      usageCount: json['usageCount'] ?? 0,
      userRating: (json['userRating'] ?? 0.0).toDouble(),
      notes: json['notes'],
      images: List<String>.from(json['images'] ?? []),
      isActive: json['isActive'] ?? true,
      isFavorite: json['isFavorite'] ?? false,
      customProperties: json['customProperties'] ?? {},
    );
  }

  /// Update entry with new data
  CollectionEntry copyWith({
    int? usageCount,
    double? userRating,
    String? notes,
    List<String>? images,
    bool? isActive,
    bool? isFavorite,
    List<String>? primaryUses,
  }) {
    return CollectionEntry(
      id: id,
      userId: userId,
      crystal: crystal,
      dateAdded: dateAdded,
      source: source,
      location: location,
      price: price,
      size: size,
      quality: quality,
      primaryUses: primaryUses ?? this.primaryUses,
      usageCount: usageCount ?? this.usageCount,
      userRating: userRating ?? this.userRating,
      notes: notes ?? this.notes,
      images: images ?? this.images,
      isActive: isActive ?? this.isActive,
      isFavorite: isFavorite ?? this.isFavorite,
      customProperties: customProperties,
    );
  }

  /// Increment usage count
  CollectionEntry recordUsage() {
    return copyWith(usageCount: usageCount + 1);
  }
}

/// Crystal usage log entry (simplified journal)
class UsageLog {
  final String id;
  final String collectionEntryId;
  final DateTime dateTime;
  final String purpose; // "meditation", "healing", "protection", etc.
  final String? intention; // What user wanted to achieve
  final String? result; // Brief outcome note
  final int? moodBefore; // 1-10 scale
  final int? moodAfter; // 1-10 scale
  final int? energyBefore; // 1-10 scale
  final int? energyAfter; // 1-10 scale
  final String? moonPhase;
  
  UsageLog({
    required this.id,
    required this.collectionEntryId,
    required this.dateTime,
    required this.purpose,
    this.intention,
    this.result,
    this.moodBefore,
    this.moodAfter,
    this.energyBefore,
    this.energyAfter,
    this.moonPhase,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collectionEntryId': collectionEntryId,
      'dateTime': dateTime.toIso8601String(),
      'purpose': purpose,
      'intention': intention,
      'result': result,
      'moodBefore': moodBefore,
      'moodAfter': moodAfter,
      'energyBefore': energyBefore,
      'energyAfter': energyAfter,
      'moonPhase': moonPhase,
    };
  }

  factory UsageLog.fromJson(Map<String, dynamic> json) {
    return UsageLog(
      id: json['id'],
      collectionEntryId: json['collectionEntryId'],
      dateTime: DateTime.parse(json['dateTime']),
      purpose: json['purpose'],
      intention: json['intention'],
      result: json['result'],
      moodBefore: json['moodBefore'],
      moodAfter: json['moodAfter'],
      energyBefore: json['energyBefore'],
      energyAfter: json['energyAfter'],
      moonPhase: json['moonPhase'],
    );
  }
}

/// Collection statistics for AI recommendations
class CollectionStats {
  final int totalCrystals;
  final Map<String, int> crystalsByType; // Type -> count
  final Map<String, int> crystalsByChakra; // Chakra -> count
  final Map<String, int> crystalsByPurpose; // Purpose -> count
  final List<String> mostUsedCrystals; // Top 5 by usage
  final List<String> favoriteCrystals; // User favorites
  final Map<String, double> effectivenessRatings; // Crystal -> avg mood improvement
  final DateTime lastUpdated;

  CollectionStats({
    required this.totalCrystals,
    required this.crystalsByType,
    required this.crystalsByChakra,
    required this.crystalsByPurpose,
    required this.mostUsedCrystals,
    required this.favoriteCrystals,
    required this.effectivenessRatings,
    required this.lastUpdated,
  });

  /// Generate stats from collection
  factory CollectionStats.fromCollection(List<CollectionEntry> collection, List<UsageLog> logs) {
    final crystalsByType = <String, int>{};
    final crystalsByChakra = <String, int>{};
    final crystalsByPurpose = <String, int>{};
    final usageCount = <String, int>{};
    final favorites = <String>[];
    final effectiveness = <String, List<double>>{};

    // Analyze collection
    for (final entry in collection) {
      // Count by type
      final type = entry.crystal.group;
      crystalsByType[type] = (crystalsByType[type] ?? 0) + 1;

      // Count by chakra
      for (final chakra in entry.crystal.chakras) {
        crystalsByChakra[chakra] = (crystalsByChakra[chakra] ?? 0) + 1;
      }

      // Count by purpose
      for (final purpose in entry.primaryUses) {
        crystalsByPurpose[purpose] = (crystalsByPurpose[purpose] ?? 0) + 1;
      }

      // Track usage
      usageCount[entry.crystal.name] = entry.usageCount;

      // Track favorites
      if (entry.isFavorite) {
        favorites.add(entry.crystal.name);
      }
    }

    // Analyze usage logs for effectiveness
    for (final log in logs) {
      if (log.moodBefore != null && log.moodAfter != null) {
        final entry = collection.firstWhere((e) => e.id == log.collectionEntryId);
        final improvement = (log.moodAfter! - log.moodBefore!).toDouble();
        effectiveness.putIfAbsent(entry.crystal.name, () => []).add(improvement);
      }
    }

    // Calculate average effectiveness
    final effectivenessRatings = <String, double>{};
    effectiveness.forEach((crystal, improvements) {
      if (improvements.isNotEmpty) {
        effectivenessRatings[crystal] = improvements.reduce((a, b) => a + b) / improvements.length;
      }
    });

    // Get most used crystals
    final sortedByUsage = usageCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostUsed = sortedByUsage.take(5).map((e) => e.key).toList();

    return CollectionStats(
      totalCrystals: collection.length,
      crystalsByType: crystalsByType,
      crystalsByChakra: crystalsByChakra,
      crystalsByPurpose: crystalsByPurpose,
      mostUsedCrystals: mostUsed,
      favoriteCrystals: favorites,
      effectivenessRatings: effectivenessRatings,
      lastUpdated: DateTime.now(),
    );
  }

  /// Convert to JSON for AI context
  Map<String, dynamic> toAIContext() {
    return {
      'totalCrystals': totalCrystals,
      'crystalTypes': crystalsByType,
      'chakraCoverage': crystalsByChakra,
      'primaryPurposes': crystalsByPurpose,
      'favorites': favoriteCrystals,
      'mostEffective': effectivenessRatings.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.key} (+${e.value.toStringAsFixed(1)} mood)')
          .toList(),
      'gaps': _identifyCollectionGaps(),
    };
  }

  /// Identify what's missing from collection
  List<String> _identifyCollectionGaps() {
    final gaps = <String>[];
    
    // Check chakra coverage
    const mainChakras = ['root', 'sacral', 'solar plexus', 'heart', 'throat', 'third eye', 'crown'];
    for (final chakra in mainChakras) {
      if (!crystalsByChakra.containsKey(chakra)) {
        gaps.add('No crystals for $chakra chakra');
      }
    }

    // Check essential purposes
    const essentialPurposes = ['protection', 'grounding', 'healing', 'meditation'];
    for (final purpose in essentialPurposes) {
      if (!crystalsByPurpose.containsKey(purpose)) {
        gaps.add('No crystals for $purpose');
      }
    }

    return gaps;
  }
}