import 'package:flutter/material.dart';
import 'crystal.dart';

/// Mood options for journal entries
enum MoodType {
  blissful('Blissful', '😊', Colors.yellow),
  peaceful('Peaceful', '😌', Colors.blue),
  energized('Energized', '⚡', Colors.orange),
  grounded('Grounded', '🌳', Colors.brown),
  anxious('Anxious', '😰', Colors.grey),
  melancholic('Melancholic', '😢', Colors.indigo);

  final String label;
  final String emoji;
  final Color color;

  const MoodType(this.label, this.emoji, this.color);
}

/// Energy level tracking
class EnergyLevel {
  final int level; // 1-10
  final String description;

  const EnergyLevel({
    required this.level,
    required this.description,
  });

  static const List<String> descriptions = [
    'Completely drained',
    'Very low energy',
    'Low energy',
    'Below average',
    'Neutral',
    'Good energy',
    'High energy',
    'Very energized',
    'Extremely energized',
    'Peak vitality'
  ];

  factory EnergyLevel.fromLevel(int level) {
    return EnergyLevel(
      level: level.clamp(1, 10),
      description: descriptions[(level - 1).clamp(0, 9)],
    );
  }
}

/// Journal entry for crystal experiences
class JournalEntry {
  final String id;
  final String userId;
  final Crystal crystal;
  final DateTime dateTime;
  final MoodType moodBefore;
  final MoodType moodAfter;
  final EnergyLevel energyBefore;
  final EnergyLevel energyAfter;
  final String experience;
  final List<String> intentions;
  final String moonPhase;
  final List<String> tags;
  final String? imageUrl;
  final bool isFavorite;

  JournalEntry({
    required this.id,
    required this.userId,
    required this.crystal,
    required this.dateTime,
    required this.moodBefore,
    required this.moodAfter,
    required this.energyBefore,
    required this.energyAfter,
    required this.experience,
    required this.intentions,
    required this.moonPhase,
    required this.tags,
    this.imageUrl,
    this.isFavorite = false,
  });

  /// Create a new journal entry
  factory JournalEntry.create({
    required String userId,
    required Crystal crystal,
    required MoodType moodBefore,
    required MoodType moodAfter,
    required int energyBefore,
    required int energyAfter,
    required String experience,
    required List<String> intentions,
    required String moonPhase,
    List<String>? tags,
    String? imageUrl,
  }) {
    return JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      crystal: crystal,
      dateTime: DateTime.now(),
      moodBefore: moodBefore,
      moodAfter: moodAfter,
      energyBefore: EnergyLevel.fromLevel(energyBefore),
      energyAfter: EnergyLevel.fromLevel(energyAfter),
      experience: experience,
      intentions: intentions,
      moonPhase: moonPhase,
      tags: tags ?? [],
      imageUrl: imageUrl,
      isFavorite: false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'crystal': crystal.toJson(),
      'dateTime': dateTime.toIso8601String(),
      'moodBefore': moodBefore.name,
      'moodAfter': moodAfter.name,
      'energyBefore': energyBefore.level,
      'energyAfter': energyAfter.level,
      'experience': experience,
      'intentions': intentions,
      'moonPhase': moonPhase,
      'tags': tags,
      'imageUrl': imageUrl,
      'isFavorite': isFavorite,
    };
  }

  /// Create from JSON
  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      userId: json['userId'],
      crystal: Crystal.fromJson(json['crystal']),
      dateTime: DateTime.parse(json['dateTime']),
      moodBefore: MoodType.values.firstWhere(
        (m) => m.name == json['moodBefore'],
        orElse: () => MoodType.peaceful,
      ),
      moodAfter: MoodType.values.firstWhere(
        (m) => m.name == json['moodAfter'],
        orElse: () => MoodType.peaceful,
      ),
      energyBefore: EnergyLevel.fromLevel(json['energyBefore']),
      energyAfter: EnergyLevel.fromLevel(json['energyAfter']),
      experience: json['experience'],
      intentions: List<String>.from(json['intentions']),
      moonPhase: json['moonPhase'],
      tags: List<String>.from(json['tags']),
      imageUrl: json['imageUrl'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  /// Create a copy with updated fields
  JournalEntry copyWith({
    bool? isFavorite,
    List<String>? tags,
  }) {
    return JournalEntry(
      id: id,
      userId: userId,
      crystal: crystal,
      dateTime: dateTime,
      moodBefore: moodBefore,
      moodAfter: moodAfter,
      energyBefore: energyBefore,
      energyAfter: energyAfter,
      experience: experience,
      intentions: intentions,
      moonPhase: moonPhase,
      tags: tags ?? this.tags,
      imageUrl: imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Get mood improvement
  String getMoodChange() {
    final moodValues = MoodType.values;
    final beforeIndex = moodValues.indexOf(moodBefore);
    final afterIndex = moodValues.indexOf(moodAfter);
    
    if (afterIndex > beforeIndex) {
      return 'Improved ↑';
    } else if (afterIndex < beforeIndex) {
      return 'Shifted ↓';
    } else {
      return 'Stable →';
    }
  }

  /// Get energy change
  String getEnergyChange() {
    final diff = energyAfter.level - energyBefore.level;
    if (diff > 0) {
      return '+$diff Energy ↑';
    } else if (diff < 0) {
      return '$diff Energy ↓';
    } else {
      return 'Stable Energy →';
    }
  }

  /// Get formatted date
  String getFormattedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (entryDate == today) {
      return 'Today ${_formatTime()}';
    } else if (entryDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${_formatTime()}';
    } else {
      return '${_formatDate()} ${_formatTime()}';
    }
  }

  String _formatTime() {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatDate() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }
}

/// Moon phase calculator (simplified)
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