import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_state.dart';
import '../services/collection_service_v2.dart';
import '../services/crystal_service.dart';
import '../services/ritual_preference_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/no_particles.dart';

List<String> _coerceStringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }
  return const [];
}

Map<String, dynamic> _sanitizeCrystalDetail(Map<String, dynamic> data) {
  final name = (data['name'] ?? '').toString();
  final intents = _coerceStringList(data['intents']);
  final chakras = _coerceStringList(
    data['chakras'] ??
        (data['metaphysicalProperties'] is Map
            ? (data['metaphysicalProperties'] as Map)['primary_chakras']
            : null),
  );
  final elements = _coerceStringList(
    data['elements'] ??
        (data['metaphysicalProperties'] is Map
            ? (data['metaphysicalProperties'] as Map)['elements']
            : null),
  );
  final healing = _coerceStringList(
    data['healingProperties'] ??
        (data['metaphysicalProperties'] is Map
            ? (data['metaphysicalProperties'] as Map)['healing_properties']
            : null),
  );

  final meta = data['metaphysicalProperties'] is Map
      ? Map<String, dynamic>.from(data['metaphysicalProperties'] as Map)
      : <String, dynamic>{};
  meta['primary_chakras'] = chakras;
  meta['elements'] = elements;
  meta['healing_properties'] = healing;

  return {
    'name': name,
    'intents': intents,
    'chakras': chakras,
    'elements': elements,
    'healingProperties': healing,
    'metaphysicalProperties': meta,
  };
}

List<Map<String, dynamic>> _coerceCrystalDetailList(
  dynamic value, {
  int maxItems = 6,
}) {
  if (value is Iterable) {
    final sanitized = value
        .map((item) => item is Map ? Map<String, dynamic>.from(item) : null)
        .whereType<Map<String, dynamic>>()
        .map(_sanitizeCrystalDetail)
        .toList();
    if (sanitized.length > maxItems) {
      return sanitized.sublist(0, maxItems);
    }
    return sanitized;
  }
  return const [];
}

String? _optionalTrimmedString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

DateTime? _timestampToDateTime(dynamic value) {
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

class CrystalCompatibilityScreen extends StatefulWidget {
  const CrystalCompatibilityScreen({super.key});

  @override
  State<CrystalCompatibilityScreen> createState() => _CrystalCompatibilityScreenState();
}

class _CrystalCompatibilityScreenState extends State<CrystalCompatibilityScreen> {
  static const int _maxSelection = 6;
  static const String _localHistoryKey = 'compatibility_history_v1';

  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _manualCrystalController = TextEditingController();
  final FocusNode _manualCrystalFocusNode = FocusNode();

  final Set<String> _selectedCrystals = <String>{};
  final List<String> _manualEntries = <String>[];
  final List<String> _intentionHistory = <String>[];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<_CompatibilitySession> _history = <_CompatibilitySession>[];
  bool _isLoadingHistory = false;
  String? _historyError;

  Map<String, dynamic>? _analysis;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillSelection();
      unawaited(_loadStoredIntention());
      unawaited(_loadCompatibilityHistory());
    });
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _manualCrystalController.dispose();
    _manualCrystalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStoredIntention() async {
    try {
      final service = RitualPreferenceService();
      final preference = await service.loadMoonPreference();
      if (!mounted || preference?.intention == null) return;
      final trimmed = preference!.intention!.trim();
      if (trimmed.isEmpty) return;
      setState(() {
        if (_purposeController.text.isEmpty) {
          _purposeController.text = trimmed;
        }
        _updateIntentionHistory(trimmed);
      });
    } catch (error) {
      debugPrint('Failed to hydrate stored intention: $error');
    }
  }

  Future<void> _loadCompatibilityHistory() async {
    await _loadLocalHistory();

    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) {
        _isLoadingHistory = false;
        return;
      }
      setState(() {
        _isLoadingHistory = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
        _historyError = null;
      });
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('compatibility_sessions')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final sessions = snapshot.docs
          .map((doc) => _CompatibilitySession.fromDocument(doc))
          .toList();

      _updateHistory(sessions);
    } catch (error, stackTrace) {
      debugPrint('Failed to load compatibility history: $error\n$stackTrace');
      if (!mounted) {
        _historyError ??= 'Unable to load your previous analyses right now.';
        return;
      }
      setState(() {
        _historyError = 'Unable to load your previous analyses right now.';
      });
    } finally {
      if (!mounted) {
        _isLoadingHistory = false;
        return;
      }
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localHistoryKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }

      final sessions = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item as Map))
          .map(_CompatibilitySession.fromLocalMap)
          .whereType<_CompatibilitySession>()
          .toList();

      if (sessions.isEmpty) {
        return;
      }

      _updateHistory(sessions, replace: true);
    } catch (error, stackTrace) {
      debugPrint('Failed to load local compatibility history: $error\n$stackTrace');
    }
  }

  void _prefillSelection() {
    final collectionService = context.read<CollectionServiceV2>();
    if (collectionService.collection.isEmpty) return;
    final seeds = collectionService.collection
        .take(3)
        .map((entry) => entry.crystal.name.trim())
        .where((name) => name.isNotEmpty);
    setState(() {
      for (final name in seeds) {
        _selectedCrystals.add(name);
      }
    });
  }

  void _toggleCrystal(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.toLowerCase();

    setState(() {
      if (_selectedCrystals.any((item) => item.toLowerCase() == normalized)) {
        _selectedCrystals.removeWhere((item) => item.toLowerCase() == normalized);
        _manualEntries.removeWhere((item) => item.toLowerCase() == normalized);
      } else {
        if (_selectedCrystals.length >= _maxSelection) {
          _showSnackBar('Select up to $_maxSelection crystals at a time.');
          return;
        }
        _selectedCrystals.add(trimmed);
      }
    });
  }

  void _addManualCrystal() {
    final value = _manualCrystalController.text.trim();
    if (value.isEmpty) {
      _manualCrystalFocusNode.requestFocus();
      return;
    }

    final normalized = value.toLowerCase();
    if (_selectedCrystals.any((item) => item.toLowerCase() == normalized)) {
      _showSnackBar('$value is already selected.');
      _manualCrystalController.clear();
      _manualCrystalFocusNode.requestFocus();
      return;
    }

    if (_selectedCrystals.length >= _maxSelection) {
      _showSnackBar('Select up to $_maxSelection crystals at a time.');
      return;
    }

    final collection = context.read<CollectionServiceV2>().collection;
    final existsInCollection = collection
        .any((entry) => entry.crystal.name.toLowerCase().trim() == normalized);

    setState(() {
      _selectedCrystals.add(value);
      if (!existsInCollection &&
          !_manualEntries.any((item) => item.toLowerCase() == normalized)) {
        _manualEntries.add(value);
      }
    });

    _manualCrystalController.clear();
    _manualCrystalFocusNode.requestFocus();
  }

  void _removeManualCrystal(String value) {
    final normalized = value.toLowerCase();
    setState(() {
      _manualEntries.removeWhere((item) => item.toLowerCase() == normalized);
      _selectedCrystals.removeWhere((item) => item.toLowerCase() == normalized);
    });
  }

  void _updateIntentionHistory(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.toLowerCase();
    final index = _intentionHistory.indexWhere((item) => item.toLowerCase() == normalized);
    if (index >= 0) {
      final existing = _intentionHistory.removeAt(index);
      _intentionHistory.insert(0, existing);
    } else {
      _intentionHistory.insert(0, trimmed);
      if (_intentionHistory.length > 6) {
        _intentionHistory.removeRange(6, _intentionHistory.length);
      }
    }
  }

  Future<void> _persistIntention(String intention) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final trimmed = intention.trim();
    if (trimmed.isEmpty) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'profile': {
          'intentions': FieldValue.arrayUnion([trimmed]),
          'intentionsUpdatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      debugPrint('Failed to persist compatibility intention: $error\n$stackTrace');
    }
  }

  Future<void> _persistAnalysisSession({
    required List<String> crystals,
    required String purpose,
    required Map<String, dynamic> analysis,
  }) async {
    final user = _auth.currentUser;

    final trimmedPurpose = purpose.trim();
    final scoreValue = analysis['score'];
    final score = scoreValue is num ? scoreValue.round().clamp(0, 100) : 0;
    final sanitizedRecommended =
        _coerceCrystalDetailList(analysis['recommendedAdditions'], maxItems: 4);
    final sanitizedAnalyzed =
        _coerceCrystalDetailList(analysis['analyzedCrystals'], maxItems: 6);

    final session = _CompatibilitySession(
      id: null,
      crystals: List<String>.from(crystals),
      purpose: trimmedPurpose.isEmpty ? null : trimmedPurpose,
      score: score,
      synergies: _coerceStringList(analysis['synergies']),
      cautions: _coerceStringList(analysis['cautions']),
      missing: _coerceStringList(analysis['missing']),
      recommendedAdditions: sanitizedRecommended,
      analyzedCrystals: sanitizedAnalyzed,
      dominantChakra:
          _optionalTrimmedString(analysis['dominantChakra'] ?? analysis['dominant_chakra']),
      dominantElement:
          _optionalTrimmedString(analysis['dominantElement'] ?? analysis['dominant_element']),
      createdAt: DateTime.now(),
    );

    _updateHistory([session]);

    if (user == null) {
      return;
    }

    try {
      final payload = {
        'crystals': session.crystals,
        'purpose': session.purpose,
        'createdAt': FieldValue.serverTimestamp(),
        'analysis': {
          'score': session.score,
          'synergies': session.synergies,
          'cautions': session.cautions,
          'missing': session.missing,
          'recommendedAdditions': session.recommendedAdditions,
          'analyzedCrystals': session.analyzedCrystals,
          'dominantChakra': session.dominantChakra,
          'dominantElement': session.dominantElement,
        },
      };

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('compatibility_sessions')
          .add(payload);

      _updateHistory([session.copyWith(id: doc.id)]);
    } catch (error, stackTrace) {
      debugPrint('Failed to save compatibility session: $error\n$stackTrace');
      if (!mounted) {
        _historyError ??= 'Unable to save this analysis to your history.';
        return;
      }
      setState(() {
        _historyError ??= 'Unable to save this analysis to your history.';
      });
    }
  }

  void _applySession(_CompatibilitySession session) {
    final crystals = session.crystals
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (crystals.isEmpty) {
      return;
    }

    final collection = context.read<CollectionServiceV2>().collection;
    final owned =
        collection.map((entry) => entry.crystal.name.toLowerCase().trim()).toSet();

    FocusScope.of(context).unfocus();

    setState(() {
      _selectedCrystals
        ..clear()
        ..addAll(crystals);
      _manualEntries
        ..clear()
        ..addAll(crystals.where((name) => !owned.contains(name.toLowerCase())));
      _purposeController.text = session.purpose ?? '';
      _analysis = session.toAnalysisMap();
      _errorMessage = null;
      if (session.purpose?.isNotEmpty == true) {
        _updateIntentionHistory(session.purpose!);
      }
    });

    _showSnackBar('Loaded saved compatibility insights.');
  }

  Future<void> _deleteSession(_CompatibilitySession session) async {
    final user = _auth.currentUser;
    final sessionId = session.id;

    if (sessionId == null) {
      if (mounted) {
        setState(() {
          _history.removeWhere((item) => identical(item, session));
        });
      } else {
        _history.removeWhere((item) => identical(item, session));
      }
      unawaited(_saveLocalHistory());
      return;
    }

    if (user == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('compatibility_sessions')
          .doc(sessionId)
          .delete();

      if (!mounted) {
        _history.removeWhere((item) => item.id == sessionId);
        await _saveLocalHistory();
        _showSnackBar('Saved analysis removed.');
        return;
      }
      setState(() {
        _history.removeWhere((item) => item.id == sessionId);
      });
      unawaited(_saveLocalHistory());
      _showSnackBar('Saved analysis removed.');
    } catch (error, stackTrace) {
      debugPrint('Failed to delete compatibility session: $error\n$stackTrace');
      if (!mounted) return;
      _showSnackBar('Unable to remove that analysis right now.');
    }
  }

  List<_CompatibilitySession> _mergeSessions(
    List<_CompatibilitySession> incoming, {
    bool replace = false,
  }) {
    final result = replace
        ? <_CompatibilitySession>[]
        : List<_CompatibilitySession>.from(_history);

    for (final session in incoming) {
      if (session.id != null) {
        final idIndex = result.indexWhere((existing) => existing.id == session.id);
        if (idIndex >= 0) {
          result[idIndex] = session;
          continue;
        }
      }

      final matchIndex = result.indexWhere((existing) => existing.isEquivalentTo(session));
      if (matchIndex >= 0) {
        final current = result[matchIndex];
        final shouldReplace = (current.id == null && session.id != null) ||
            ((session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .isAfter(current.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)) &&
                session.id != null);
        if (shouldReplace) {
          result[matchIndex] = session;
        }
      } else {
        result.add(session);
      }
    }

    result.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    if (result.length > 10) {
      result.removeRange(10, result.length);
    }

    return result;
  }

  void _updateHistory(
    List<_CompatibilitySession> sessions, {
    bool replace = false,
  }) {
    final merged = _mergeSessions(sessions, replace: replace);
    if (!mounted) {
      _history
        ..clear()
        ..addAll(merged);
      _historyError = null;
      unawaited(_saveLocalHistory());
      return;
    }
    setState(() {
      _history
        ..clear()
        ..addAll(merged);
      _historyError = null;
    });
    unawaited(_saveLocalHistory());
  }

  Future<void> _saveLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = _history.map((session) => session.toLocalMap()).toList();
      await prefs.setString(_localHistoryKey, jsonEncode(payload));
    } catch (error, stackTrace) {
      debugPrint('Failed to persist compatibility history locally: $error\n$stackTrace');
    }
  }

  Map<String, dynamic> _buildUserProfile(AppState state) {
    final profile = <String, dynamic>{
      'subscriptionTier': state.subscriptionTier,
      'preferredLanguage': state.preferredLanguage,
      'notificationsEnabled': state.notificationsEnabled,
    };

    if (_intentionHistory.isNotEmpty) {
      profile['intentions'] = List<String>.from(_intentionHistory);
    }

    return profile;
  }

  Future<void> _analyzeCompatibility() async {
    FocusScope.of(context).unfocus();

    final crystals = _selectedCrystals
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (crystals.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one crystal to analyse.';
        _analysis = null;
      });
      return;
    }

    final purpose = _purposeController.text.trim();
    final appState = context.read<AppState>();
    final crystalService = context.read<CrystalService>();
    final userProfile = _buildUserProfile(appState);

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final response = await crystalService.checkCompatibility(
        crystalNames: crystals,
        purpose: purpose.isEmpty ? null : purpose,
        userProfile: userProfile.isEmpty ? null : userProfile,
      );

      if (!mounted) return;

      if (response == null) {
        setState(() {
          _analysis = null;
          _errorMessage = 'Compatibility service returned no data.';
        });
        return;
      }

      final sanitizedRecommended =
          _coerceCrystalDetailList(response['recommendedAdditions'], maxItems: 4);
      final sanitizedAnalyzed =
          _coerceCrystalDetailList(response['analyzedCrystals'], maxItems: 6);
      final resolvedPurpose = (response['purpose'] is String)
          ? (response['purpose'] as String).trim()
          : '';
      final normalizedResponse = Map<String, dynamic>.from(response)
        ..['recommendedAdditions'] = sanitizedRecommended
        ..['analyzedCrystals'] = sanitizedAnalyzed
        ..['purpose'] =
            resolvedPurpose.isNotEmpty ? resolvedPurpose : purpose;
      final historyPurpose =
          (normalizedResponse['purpose'] is String)
              ? (normalizedResponse['purpose'] as String).trim()
              : '';

      setState(() {
        _analysis = normalizedResponse;
        _errorMessage = null;
        if (historyPurpose.isNotEmpty) {
          _updateIntentionHistory(historyPurpose);
        }
      });
      if (historyPurpose.isNotEmpty) {
        unawaited(_persistIntention(historyPurpose));
      }
      unawaited(_persistAnalysisSession(
        crystals: crystals,
        purpose: historyPurpose,
        analysis: normalizedResponse,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _analysis = null;
        _errorMessage = 'Failed to analyse compatibility: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.amethystPurple.withOpacity(0.85),
      ),
    );
  }

  void _applyIntention(String intention) {
    _purposeController.text = intention;
  }

  void _addRecommendedCrystal(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final normalized = trimmed.toLowerCase();
    if (_selectedCrystals.any((item) => item.toLowerCase() == normalized)) {
      _showSnackBar('$trimmed is already part of your analysis.');
      return;
    }
    if (_selectedCrystals.length >= _maxSelection) {
      _showSnackBar('Select up to $_maxSelection crystals at a time.');
      return;
    }

    final collection = context.read<CollectionServiceV2>().collection;
    final existsInCollection = collection
        .any((entry) => entry.crystal.name.toLowerCase().trim() == normalized);

    setState(() {
      _selectedCrystals.add(trimmed);
      if (!existsInCollection &&
          !_manualEntries.any((item) => item.toLowerCase() == normalized)) {
        _manualEntries.add(trimmed);
      }
    });

    _showSnackBar('$trimmed added to the compatibility check.');
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF34D399);
    if (score >= 70) return AppTheme.crystalGlow;
    if (score >= 55) return const Color(0xFFFCD34D);
    return const Color(0xFFF87171);
  }

  List<String> _stringList(dynamic value) {
    return _coerceStringList(value);
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  Widget _buildScoreDial(int score) {
    final clamped = score.clamp(0, 100);
    final color = _scoreColor(clamped);
    final label = clamped >= 85
        ? 'Harmonious'
        : clamped >= 70
            ? 'Aligned'
            : clamped >= 55
                ? 'Balanced'
                : 'Tense';

    return SizedBox(
      height: 150,
      width: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 150,
            width: 150,
            child: CircularProgressIndicator(
              value: clamped / 100,
              strokeWidth: 10,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                clamped.toString(),
                style: GoogleFonts.orbitron(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Text(
      title,
      style: GoogleFonts.cinzel(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? Colors.white,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildInsightList(
    String title,
    List<String> items,
    IconData icon,
    Color accent,
  ) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title, color: accent),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<Map<String, dynamic>> items) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Suggested companions', color: AppTheme.crystalGlow),
          const SizedBox(height: 12),
          const Text(
            'Add these crystals to deepen the energy of your layout.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _buildRecommendationCard(item),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> item) {
    final name = (item['name'] ?? '') as String;
    final intents = _stringList(item['intents']).take(3).toList();
    final meta = _mapFrom(item['metaphysicalProperties']);
    final chakras = _stringList(item['chakras'] ?? meta['primary_chakras']).take(3).toList();
    final elements = _stringList(item['elements'] ?? meta['elements']).take(2).toList();
    final healing = _stringList(item['healingProperties'] ?? meta['healing_properties']).take(2).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? 'Unnamed Crystal' : name,
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (healing.isNotEmpty)
            Text(
              healing.join(' • '),
              style: const TextStyle(color: Colors.white70, height: 1.3),
            ),
          if (chakras.isNotEmpty || elements.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final chakra in chakras)
                    _buildTag(chakra, AppTheme.crystalGlow, icon: Icons.brightness_5),
                  for (final element in elements)
                    _buildTag(element, const Color(0xFFFB7185), icon: Icons.local_fire_department),
                  for (final intent in intents)
                    _buildTag(intent, AppTheme.holoBlue.withOpacity(0.9)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _addRecommendedCrystal(name),
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.crystalGlow),
              label: const Text('Add to analysis'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.crystalGlow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzedCrystals(List<Map<String, dynamic>> items) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Crystal breakdown', color: Colors.white),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _buildCrystalSummary(item),
            ),
        ],
      ),
    );
  }

  Widget _buildCrystalSummary(Map<String, dynamic> item) {
    final name = (item['name'] ?? '') as String;
    final intents = _stringList(item['intents']).take(3).toList();
    final chakras = _stringList(item['chakras']).take(3).toList();
    final elements = _stringList(item['elements']).take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? 'Crystal' : name,
          style: GoogleFonts.cinzel(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        if (intents.isNotEmpty)
          Text(
            'Focus: ${intents.join(', ')}',
            style: const TextStyle(color: Colors.white70),
          ),
        if (chakras.isNotEmpty || elements.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final chakra in chakras)
                  _buildTag(chakra, AppTheme.crystalGlow, icon: Icons.brightness_5),
                for (final element in elements)
                  _buildTag(element, const Color(0xFFFB7185), icon: Icons.local_fire_department),
              ],
            ),
          ),
      ],
    );
  }

  String _relativeTime(DateTime? date) {
    if (date == null) {
      return 'Just now';
    }
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildHistorySection() {
    final user = _auth.currentUser;

    if (user == null) {
      return GlassmorphicContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Save your insights', color: Colors.white),
            const SizedBox(height: 8),
            const Text(
              'Sign in to store your compatibility readings and revisit your strongest pairings.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      );
    }

    if (_isLoadingHistory) {
      return GlassmorphicContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading your previous analyses...',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    if (_history.isEmpty) {
      return GlassmorphicContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Compatibility history', color: Colors.white),
            const SizedBox(height: 8),
            const Text(
              'Your saved readings will appear here once you run an analysis.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      );
    }

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Recent analyses', color: Colors.white),
          const SizedBox(height: 8),
          if (_historyError != null) ...[
            Text(
              _historyError!,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _history.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _buildHistoryCard(_history[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(_CompatibilitySession session) {
    final scoreColor = _scoreColor(session.score);
    final recommendedNames = session.recommendedNames;
    final timestamp = _relativeTime(session.createdAt);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scoreColor.withOpacity(0.45)),
                ),
                child: Text(
                  '${session.score}',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Score',
                style: TextStyle(color: Colors.white54),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _applySession(session),
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                tooltip: 'Load this reading',
              ),
              if (session.id != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteSession(session);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            session.displayPurpose,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cinzel(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final crystal in session.crystals.take(4))
                _buildTag(crystal, AppTheme.holoBlue.withOpacity(0.9)),
            ],
          ),
          if (session.synergies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              session.synergies.first,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],
          if (recommendedNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in recommendedNames)
                  _buildTag(name, AppTheme.crystalGlow, icon: Icons.auto_awesome),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            timestamp,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    final result = _analysis;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final scoreValue = result['score'];
    final score = scoreValue is num ? scoreValue.round().clamp(0, 100) : null;
    final purpose = (result['purpose'] ?? '') as String?;
    final dominantChakra = result['dominantChakra'] ?? result['dominant_chakra'];
    final dominantElement = result['dominantElement'] ?? result['dominant_element'];
    final synergies = _stringList(result['synergies']);
    final cautions = _stringList(result['cautions']);
    final recommended = result['recommendedAdditions'] is List
        ? (result['recommendedAdditions'] as List)
            .whereType<Map>()
            .map((item) => _mapFrom(item))
            .toList()
        : <Map<String, dynamic>>[];
    final analyzed = result['analyzedCrystals'] is List
        ? (result['analyzedCrystals'] as List)
            .whereType<Map>()
            .map((item) => _mapFrom(item))
            .toList()
        : <Map<String, dynamic>>[];
    final missing = _stringList(result['missing']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassmorphicContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSectionTitle('Compatibility score', color: AppTheme.crystalGlow),
              const SizedBox(height: 16),
              if (score != null) _buildScoreDial(score),
              if (purpose != null && purpose.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Intention focus: ${purpose.trim()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
              if (dominantChakra != null || dominantElement != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (dominantChakra != null && dominantChakra.toString().isNotEmpty)
                      _buildTag(
                        'Dominant Chakra: ${dominantChakra.toString()}',
                        AppTheme.crystalGlow,
                        icon: Icons.self_improvement,
                      ),
                    if (dominantElement != null && dominantElement.toString().isNotEmpty)
                      _buildTag(
                        'Dominant Element: ${dominantElement.toString()}',
                        const Color(0xFFFB7185),
                        icon: Icons.local_fire_department,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (synergies.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildInsightList(
            'Synergy highlights',
            synergies,
            Icons.auto_awesome,
            AppTheme.crystalGlow,
          ),
        ],
        if (cautions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildInsightList(
            'Cautionary notes',
            cautions,
            Icons.warning_amber_rounded,
            const Color(0xFFF87171),
          ),
        ],
        if (recommended.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildRecommendations(recommended),
        ],
        if (analyzed.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildAnalyzedCrystals(analyzed),
        ],
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 16),
          GlassmorphicContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Not yet in the library', color: Colors.white),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in missing)
                      _buildTag(name, Colors.white.withOpacity(0.9)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'We will expand the crystal library soon. Add notes in your collection so we can learn from your practice.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectionSection(CollectionServiceV2 collectionService) {
    final entries = collectionService.collection;

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Choose your crystals', color: Colors.white),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Text(
              'Add crystals to your collection to unlock personalised compatibility insights.',
              style: TextStyle(color: Colors.white70),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: entries.map((entry) {
                final name = entry.crystal.name.isNotEmpty
                    ? entry.crystal.name
                    : 'Unnamed crystal';
                final normalized = name.toLowerCase();
                final selected = _selectedCrystals
                    .any((item) => item.toLowerCase() == normalized);

                return FilterChip(
                  label: Text(name),
                  selected: selected,
                  onSelected: (_) => _toggleCrystal(name),
                  checkmarkColor: Colors.black,
                  selectedColor: AppTheme.crystalGlow.withOpacity(0.6),
                  backgroundColor: Colors.white.withOpacity(0.08),
                  labelStyle: TextStyle(
                    color: selected ? Colors.black : Colors.white70,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected
                          ? AppTheme.crystalGlow
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          _buildSectionTitle('Add crystals manually', color: Colors.white70),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualCrystalController,
                  focusNode: _manualCrystalFocusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addManualCrystal(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Larimar, Moldavite',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppTheme.crystalGlow),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addManualCrystal,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          if (_manualEntries.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _manualEntries.map((name) {
                return InputChip(
                  label: Text(name),
                  onDeleted: () => _removeManualCrystal(name),
                  deleteIconColor: Colors.white70,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  labelStyle: const TextStyle(color: Colors.white),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_selectedCrystals.length} of $_maxSelection selected',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeSection() {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Focus or intention', color: Colors.white),
          const SizedBox(height: 10),
          TextField(
            controller: _purposeController,
            textInputAction: TextInputAction.done,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Deep rest, manifesting love, psychic protection',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppTheme.crystalGlow),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Leave blank to let the grimoire infer your intention from recent rituals.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (_intentionHistory.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSectionTitle('Recent intentions', color: Colors.white70),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _intentionHistory.map((intent) {
                return ChoiceChip(
                  label: Text(intent),
                  selected: _purposeController.text.trim().toLowerCase() == intent.toLowerCase(),
                  onSelected: (_) => _applyIntention(intent),
                  labelStyle: const TextStyle(color: Colors.white),
                  selectedColor: AppTheme.crystalGlow.withOpacity(0.6),
                  backgroundColor: Colors.white.withOpacity(0.08),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: AppTheme.holographicShader,
            child: Text(
              'Crystal Harmony Analyzer',
              style: GoogleFonts.cinzel(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Discover how your crystals resonate together, highlight energetic gaps, and receive guidance on the allies that elevate your ritual work.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF87171)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionService = context.watch<CollectionServiceV2>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: AppTheme.mysticalShader,
          child: const Text(
            'Crystal Compatibility',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.deepMystical,
                  AppTheme.darkViolet,
                  AppTheme.midnightBlue,
                ],
              ),
            ),
          ),
          const SimpleGradientParticles(particleCount: 6),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 18),
                  _buildHistorySection(),
                  const SizedBox(height: 18),
                  _buildSelectionSection(collectionService),
                  const SizedBox(height: 18),
                  _buildPurposeSection(),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isAnalyzing ? null : _analyzeCompatibility,
                      icon: _isAnalyzing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze compatibility'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildErrorBanner(),
                  if (_analysis != null) ...[
                    const SizedBox(height: 18),
                    _buildAnalysisResult(),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilitySession {
  const _CompatibilitySession({
    required this.id,
    required this.crystals,
    required this.purpose,
    required this.score,
    required this.synergies,
    required this.cautions,
    required this.missing,
    required this.recommendedAdditions,
    required this.analyzedCrystals,
    required this.dominantChakra,
    required this.dominantElement,
    required this.createdAt,
  });

  factory _CompatibilitySession.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final analysisRaw = data['analysis'];
    final analysis = analysisRaw is Map
        ? Map<String, dynamic>.from(analysisRaw as Map)
        : <String, dynamic>{};

    return _CompatibilitySession(
      id: doc.id,
      crystals: _coerceStringList(data['crystals']).take(6).toList(),
      purpose: _optionalTrimmedString(data['purpose']),
      score: (analysis['score'] is num)
          ? (analysis['score'] as num).round().clamp(0, 100)
          : 0,
      synergies: _coerceStringList(analysis['synergies']).take(6).toList(),
      cautions: _coerceStringList(analysis['cautions']).take(4).toList(),
      missing: _coerceStringList(analysis['missing']).take(6).toList(),
      recommendedAdditions:
          _coerceCrystalDetailList(analysis['recommendedAdditions'], maxItems: 4),
      analyzedCrystals:
          _coerceCrystalDetailList(analysis['analyzedCrystals'], maxItems: 6),
      dominantChakra:
          _optionalTrimmedString(analysis['dominantChakra'] ?? analysis['dominant_chakra']),
      dominantElement:
          _optionalTrimmedString(analysis['dominantElement'] ?? analysis['dominant_element']),
      createdAt: _timestampToDateTime(data['createdAt']),
    );
  }

  factory _CompatibilitySession.fromLocalMap(Map<String, dynamic> data) {
    return _CompatibilitySession(
      id: _optionalTrimmedString(data['id']),
      crystals: _coerceStringList(data['crystals']).take(6).toList(),
      purpose: _optionalTrimmedString(data['purpose']),
      score: (data['score'] is num)
          ? (data['score'] as num).round().clamp(0, 100)
          : 0,
      synergies: _coerceStringList(data['synergies']).take(6).toList(),
      cautions: _coerceStringList(data['cautions']).take(4).toList(),
      missing: _coerceStringList(data['missing']).take(6).toList(),
      recommendedAdditions:
          _coerceCrystalDetailList(data['recommendedAdditions'], maxItems: 4),
      analyzedCrystals:
          _coerceCrystalDetailList(data['analyzedCrystals'], maxItems: 6),
      dominantChakra:
          _optionalTrimmedString(data['dominantChakra'] ?? data['dominant_chakra']),
      dominantElement:
          _optionalTrimmedString(data['dominantElement'] ?? data['dominant_element']),
      createdAt: _timestampToDateTime(data['createdAt']),
    );
  }

  final String? id;
  final List<String> crystals;
  final String? purpose;
  final int score;
  final List<String> synergies;
  final List<String> cautions;
  final List<String> missing;
  final List<Map<String, dynamic>> recommendedAdditions;
  final List<Map<String, dynamic>> analyzedCrystals;
  final String? dominantChakra;
  final String? dominantElement;
  final DateTime? createdAt;

  _CompatibilitySession copyWith({String? id, DateTime? createdAt}) {
    return _CompatibilitySession(
      id: id ?? this.id,
      crystals: crystals,
      purpose: purpose,
      score: score,
      synergies: synergies,
      cautions: cautions,
      missing: missing,
      recommendedAdditions: recommendedAdditions,
      analyzedCrystals: analyzedCrystals,
      dominantChakra: dominantChakra,
      dominantElement: dominantElement,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  List<String> get recommendedNames {
    final seen = <String>{};
    final names = <String>[];
    for (final item in recommendedAdditions) {
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) {
        names.add(name);
      }
    }
    return names;
  }

  String get displayPurpose =>
      purpose == null || purpose!.isEmpty ? 'General harmony' : purpose!;

  Map<String, dynamic> toAnalysisMap() {
    return {
      'score': score,
      'purpose': purpose ?? '',
      'synergies': synergies,
      'cautions': cautions,
      'missing': missing,
      'recommendedAdditions': recommendedAdditions,
      'analyzedCrystals': analyzedCrystals,
      'dominantChakra': dominantChakra,
      'dominantElement': dominantElement,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'crystals': crystals,
      'purpose': purpose,
      'score': score,
      'synergies': synergies,
      'cautions': cautions,
      'missing': missing,
      'recommendedAdditions': recommendedAdditions,
      'analyzedCrystals': analyzedCrystals,
      'dominantChakra': dominantChakra,
      'dominantElement': dominantElement,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool isEquivalentTo(_CompatibilitySession other) {
    final selfPurpose = (purpose ?? '').trim().toLowerCase();
    final otherPurpose = (other.purpose ?? '').trim().toLowerCase();
    if (selfPurpose != otherPurpose) {
      return false;
    }

    if (score != other.score) {
      return false;
    }

    final selfCrystals = _normalizedCrystals(crystals);
    final otherCrystals = _normalizedCrystals(other.crystals);
    if (selfCrystals.length != otherCrystals.length) {
      return false;
    }
    for (var i = 0; i < selfCrystals.length; i += 1) {
      if (selfCrystals[i] != otherCrystals[i]) {
        return false;
      }
    }

    if (createdAt != null && other.createdAt != null) {
      final diff =
          (createdAt!.millisecondsSinceEpoch - other.createdAt!.millisecondsSinceEpoch).abs();
      if (diff <= 60000) {
        return true;
      }
    }

    return true;
  }

  static List<String> _normalizedCrystals(List<String> values) {
    final normalized = values
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList();
    normalized.sort();
    return normalized;
  }
}
