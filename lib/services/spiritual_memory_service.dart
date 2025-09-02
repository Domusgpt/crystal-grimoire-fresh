import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Spiritual Memory Service - Builds Personal Relationship with Crystallis Codexicus
/// Available for Premium+ users to create deep, personal spiritual guidance with the ancient crystal sage
class SpiritualMemoryService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user's spiritual memory profile
  static Future<Map<String, dynamic>?> getSpiritualMemory() async {
    try {
      final callable = _functions.httpsCallable('getSpiritualMemory');
      final result = await callable.call();
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      print('Error getting spiritual memory: $e');
      return null;
    }
  }

  /// Get spiritual journey summary for display
  static Future<SpiritualJourneySummary?> getJourneySummary() async {
    final memory = await getSpiritualMemory();
    if (memory == null) return null;

    return SpiritualJourneySummary.fromJson(memory);
  }

  /// Stream personal guidance messages
  static Stream<List<PersonalGuidanceMessage>> getPersonalGuidanceStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('crystal_identifications')
        .where('userId', isEqualTo: userId)
        .where('personal_guidance', isNull: false)
        .orderBy('guidance_generated_at', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PersonalGuidanceMessage.fromFirestore(doc))
            .toList());
  }

  /// Get Crystallis Codexicus's relationship insight
  static Future<String> getCrystallisRelationshipInsight() async {
    final memory = await getSpiritualMemory();
    if (memory == null) {
      return "Crystallis Codexicus is just beginning to know your spiritual essence. Each crystal session deepens your connection to ancient wisdom.";
    }

    final relationship = memory['sage_relationship'] as Map<String, dynamic>?;
    final communicationStyle = relationship?['communication_style'] ?? 'discovering';
    final journeyPhase = memory['spiritual_journey']?['phase'] ?? 'beginning';

    switch (communicationStyle) {
      case 'discovering':
        return "Crystallis Codexicus is learning the unique patterns of your spiritual energy. The ancient sage senses great potential in your crystal journey.";
      case 'trusting':
        return "A bond of trust has formed between you and Crystallis Codexicus. The wise codex recognizes your $journeyPhase spiritual path and offers guidance with growing confidence.";
      case 'intimate':
        return "Crystallis Codexicus knows your spiritual heart intimately. Ancient wisdom flows naturally, attuned to your deepest healing needs and growth patterns.";
      case 'soul-bonded':
        return "You and Crystallis Codexicus share a profound spiritual connection. The eternal sage speaks to your soul's evolution with wisdom spanning millennia.";
      default:
        return "Your relationship with Crystallis Codexicus continues to deepen with each crystal encounter.";
    }
  }

  /// Get spiritual milestones achieved
  static Future<List<SpiritualMilestone>> getSpiritualMilestones() async {
    final memory = await getSpiritualMemory();
    if (memory == null) return [];

    final milestones = memory['session_history']?['spiritual_milestones'] as List?;
    if (milestones == null) return [];

    return milestones
        .map((m) => SpiritualMilestone.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Check if user has spiritual memory access
  static Future<bool> hasMemoryAccess() async {
    try {
      await getSpiritualMemory();
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Spiritual Journey Summary Model
class SpiritualJourneySummary {
  final String phase;
  final List<String> focusAreas;
  final List<String> favoriteTypes;
  final String communicationStyle;
  final int totalSessions;
  final List<String> recurringThemes;

  SpiritualJourneySummary({
    required this.phase,
    required this.focusAreas,
    required this.favoriteTypes,
    required this.communicationStyle,
    required this.totalSessions,
    required this.recurringThemes,
  });

  factory SpiritualJourneySummary.fromJson(Map<String, dynamic> json) {
    return SpiritualJourneySummary(
      phase: json['spiritual_journey']?['phase'] ?? 'beginning',
      focusAreas: List<String>.from(json['spiritual_journey']?['focus_areas'] ?? []),
      favoriteTypes: List<String>.from(json['crystal_relationships']?['favorite_types'] ?? []),
      communicationStyle: json['sage_relationship']?['communication_style'] ?? 'discovering',
      totalSessions: json['session_history']?['total_identifications'] ?? 0,
      recurringThemes: List<String>.from(json['personal_insights']?['recurring_themes'] ?? []),
    );
  }

  String get phaseDescription {
    switch (phase) {
      case 'beginning':
        return 'Beginning your crystal journey with wonder and openness';
      case 'developing':
        return 'Developing deeper understanding of crystal energies';
      case 'advanced':
        return 'Advanced practitioner with strong intuitive connections';
      case 'master':
        return 'Master-level spiritual worker with crystal allies';
      default:
        return 'Walking your unique spiritual path';
    }
  }

  String get relationshipDescription {
    switch (communicationStyle) {
      case 'discovering':
        return 'Crystallis Codexicus is discovering your spiritual essence';
      case 'trusting':
        return 'A trusting relationship has formed with the ancient sage';
      case 'intimate':
        return 'An intimate spiritual bond guides your sessions with Crystallis';
      case 'soul-bonded':
        return 'A soul-deep connection with Crystallis Codexicus transcends ordinary guidance';
      default:
        return 'Your relationship with Crystallis Codexicus continues to evolve';
    }
  }
}

/// Personal Guidance Message Model
class PersonalGuidanceMessage {
  final String id;
  final String guidance;
  final DateTime timestamp;
  final String crystalName;
  final Map<String, dynamic> sessionContext;

  PersonalGuidanceMessage({
    required this.id,
    required this.guidance,
    required this.timestamp,
    required this.crystalName,
    required this.sessionContext,
  });

  factory PersonalGuidanceMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PersonalGuidanceMessage(
      id: doc.id,
      guidance: data['personal_guidance'] ?? '',
      timestamp: (data['guidance_generated_at'] as Timestamp).toDate(),
      crystalName: data['ai_response']?['identification']?['name'] ?? 'Unknown Crystal',
      sessionContext: Map<String, dynamic>.from(data),
    );
  }
}

/// Spiritual Milestone Model
class SpiritualMilestone {
  final String title;
  final String description;
  final DateTime achievedAt;
  final String type;

  SpiritualMilestone({
    required this.title,
    required this.description,
    required this.achievedAt,
    required this.type,
  });

  factory SpiritualMilestone.fromJson(Map<String, dynamic> json) {
    return SpiritualMilestone(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      achievedAt: DateTime.parse(json['achieved_at'] ?? DateTime.now().toIso8601String()),
      type: json['type'] ?? 'growth',
    );
  }
}