import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Provides persistence and retrieval for moon ritual preferences so that
/// users see consistent intentions and lunar context across devices.
class RitualPreferenceService {
  RitualPreferenceService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _collectionPath = 'ritual_preferences';
  static const String _moonDocumentId = 'moon';

  DocumentReference<Map<String, dynamic>>? _moonDocument() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection(_collectionPath)
        .doc(_moonDocumentId);
  }

  /// Fetches the stored moon ritual preference for the active user. Returns
  /// `null` when there is no authenticated user or the document has not been
  /// written yet.
  Future<MoonRitualPreference?> loadMoonPreference() async {
    final docRef = _moonDocument();
    if (docRef == null) return null;

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      return MoonRitualPreference.fromMap(data);
    } catch (error, stackTrace) {
      debugPrint('Failed to load moon ritual preference: $error\n$stackTrace');
      return null;
    }
  }

  /// Persists the provided moon ritual selections for the current user. If the
  /// user is signed out the request is silently ignored.
  Future<void> saveMoonPreference({
    required String phase,
    String? intention,
    Map<String, dynamic>? metadata,
  }) async {
    final docRef = _moonDocument();
    if (docRef == null) return;

    final sanitizedMetadata = sanitizeMoonMetadata(metadata);
    final trimmedIntention = intention?.trim();

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final now = FieldValue.serverTimestamp();
        final payload = <String, dynamic>{
          'phase': phase,
          'updatedAt': now,
        };

        if (trimmedIntention != null && trimmedIntention.isNotEmpty) {
          payload['intention'] = trimmedIntention;
        } else {
          payload['intention'] = FieldValue.delete();
        }

        if (sanitizedMetadata != null && sanitizedMetadata.isNotEmpty) {
          payload['moonMetadata'] = sanitizedMetadata;
        } else {
          payload['moonMetadata'] = FieldValue.delete();
        }

        if (!snapshot.exists) {
          payload['createdAt'] = now;
          payload['submittedBy'] = _auth.currentUser?.uid;
        }

        transaction.set(docRef, payload, SetOptions(merge: true));
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to save moon ritual preference: $error\n$stackTrace');
    }
  }

  /// Extracts a concise metadata payload that can be safely stored in
  /// Firestore without bloating the document size.
  static Map<String, dynamic>? sanitizeMoonMetadata(
      Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return null;

    final sanitized = <String, dynamic>{};

    final phase = raw['phase'] ?? raw['name'];
    if (phase is String && phase.trim().isNotEmpty) {
      sanitized['phase'] = phase.trim();
    }

    final emoji = raw['emoji'];
    if (emoji is String && emoji.isNotEmpty) {
      sanitized['emoji'] = emoji;
    }

    final illumination = raw['illumination'];
    if (illumination is num) {
      sanitized['illumination'] = illumination.toDouble();
    }

    final timestamp = raw['timestamp'];
    if (timestamp is String && timestamp.isNotEmpty) {
      sanitized['timestamp'] = timestamp;
    }

    final nextPhases = raw['nextPhases'] ?? raw['next_phases'];
    if (nextPhases is List && nextPhases.isNotEmpty) {
      sanitized['nextPhases'] = nextPhases
          .whereType<Map>()
          .map((phase) => phase.map((key, value) => MapEntry(
                key.toString(),
                value is String ? value : value?.toString(),
              )))
          .take(4)
          .toList();
    }

    final energy = raw['energy'] ?? raw['focus'];
    if (energy is String && energy.trim().isNotEmpty) {
      sanitized['focus'] = energy.trim();
    }

    return sanitized.isEmpty ? null : sanitized;
  }
}

/// Represents a user’s stored moon ritual preference.
class MoonRitualPreference {
  const MoonRitualPreference({
    required this.phase,
    this.intention,
    this.metadata,
    this.updatedAt,
    this.createdAt,
  });

  factory MoonRitualPreference.fromMap(Map<String, dynamic> data) {
    final phase = (data['phase'] as String?)?.trim();
    final intention = (data['intention'] as String?)?.trim();
    final metadata = data['moonMetadata'] is Map
        ? Map<String, dynamic>.from(data['moonMetadata'] as Map)
        : null;

    return MoonRitualPreference(
      phase: phase ?? 'Full Moon',
      intention: (intention != null && intention.isNotEmpty) ? intention : null,
      metadata: metadata,
      updatedAt: _timestampToDate(data['updatedAt']),
      createdAt: _timestampToDate(data['createdAt']),
    );
  }

  final String phase;
  final String? intention;
  final Map<String, dynamic>? metadata;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  static DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
