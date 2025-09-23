import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_state.dart';
import '../services/collection_service_v2.dart';
import '../services/crystal_service.dart';
import '../services/ritual_preference_service.dart';

class MoonRitualScreen extends StatefulWidget {
  const MoonRitualScreen({Key? key}) : super(key: key);

  @override
  State<MoonRitualScreen> createState() => _MoonRitualScreenState();
}

const List<String> _phaseOrder = [
  'New Moon',
  'Waxing Crescent',
  'First Quarter',
  'Waxing Gibbous',
  'Full Moon',
  'Waning Gibbous',
  'Last Quarter',
  'Waning Crescent',
];

final Map<String, Map<String, dynamic>> moonPhaseData = {
  'New Moon': {
    'meaning': 'New beginnings, setting intentions',
    'crystals': ['Black Moonstone', 'Labradorite', 'Clear Quartz'],
    'ritual': 'Write down your intentions for the lunar cycle',
    'affirmation': 'I plant seeds of intention that will bloom with the moon',
  },
  'Waxing Crescent': {
    'meaning': 'Growth, manifestation, taking action',
    'crystals': ['Citrine', 'Green Aventurine', 'Pyrite'],
    'ritual': 'Charge your crystals under moonlight',
    'affirmation': 'I nurture my dreams into reality',
  },
  'First Quarter': {
    'meaning': 'Challenges, decisions, commitment',
    'crystals': ['Carnelian', 'Red Jasper', 'Tiger Eye'],
    'ritual': 'Meditate on obstacles and solutions',
    'affirmation': 'I face challenges with courage and wisdom',
  },
  'Waxing Gibbous': {
    'meaning': 'Refinement, adjustment, patience',
    'crystals': ['Rose Quartz', 'Rhodonite', 'Pink Tourmaline'],
    'ritual': 'Practice gratitude for progress made',
    'affirmation': 'I trust in divine timing',
  },
  'Full Moon': {
    'meaning': 'Culmination, release, gratitude',
    'crystals': ['Selenite', 'Moonstone', 'Clear Quartz'],
    'ritual': 'Release what no longer serves you',
    'affirmation': 'I release and receive with grace',
  },
  'Waning Gibbous': {
    'meaning': 'Gratitude, sharing, generosity',
    'crystals': ['Amethyst', 'Lepidolite', 'Blue Lace Agate'],
    'ritual': 'Share your wisdom and abundance',
    'affirmation': 'I am grateful for all I have learned',
  },
  'Last Quarter': {
    'meaning': 'Release, forgiveness, letting go',
    'crystals': ['Smoky Quartz', 'Black Tourmaline', 'Obsidian'],
    'ritual': 'Cleanse your space and crystals',
    'affirmation': 'I release the past with love',
  },
  'Waning Crescent': {
    'meaning': 'Rest, reflection, preparation',
    'crystals': ['Selenite', 'Celestite', 'Blue Calcite'],
    'ritual': 'Rest and prepare for the new cycle',
    'affirmation': 'I honor the cycles of rest and action',
  },
};

const _prefsMoonIntentionKey = 'moon_ritual_last_intention';
const _prefsMoonPhaseKey = 'moon_ritual_last_phase';
const _prefsMoonSyncTimestampKey = 'moon_ritual_pref_synced_at';

final DateFormat _moonDateFormat = DateFormat.yMMMEd();

class _MoonRitualScreenState extends State<MoonRitualScreen> {
  final TextEditingController _intentionController = TextEditingController();
  Timer? _intentionSaveDebounce;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  String _selectedPhase = _phaseOrder[4];
  Map<String, dynamic>? _moonData;
  Map<String, dynamic>? _ritualData;
  List<Map<String, dynamic>> _recommendedCrystals = [];
  Set<String> _ownedCrystals = {};
  late final RitualPreferenceService _preferenceService;
  DateTime? _localPreferenceTimestamp;

  @override
  void initState() {
    super.initState();
    _preferenceService = RitualPreferenceService();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restorePersistedSelections();
      if (!mounted) return;
      await _refreshRitual();
    });
  }

  @override
  void dispose() {
    _intentionController.dispose();
    _intentionSaveDebounce?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _buildUserProfile(AppState state) {
    return {
      'subscriptionTier': state.subscriptionTier,
      'notificationsEnabled': state.notificationsEnabled,
      'preferredLanguage': state.preferredLanguage,
    };
  }

  Future<void> _refreshRitual({String? phase}) async {
    final collectionService = context.read<CollectionServiceV2>();
    final appState = context.read<AppState>();
    final crystalService = context.read<CrystalService>();

    final availableCrystals = collectionService.collection
        .map((entry) => entry.crystal.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    final targetPhase = phase ?? _selectedPhase;
    final intention = _intentionController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _ownedCrystals = availableCrystals.map((name) => name.toLowerCase()).toSet();
      if (phase != null) {
        _selectedPhase = phase;
      }
    });

    try {
      final payload = await crystalService.getMoonRituals(
        moonPhase: targetPhase,
        userCrystals: availableCrystals.toList(),
        userProfile: _buildUserProfile(appState),
        intention: intention.isEmpty ? null : intention,
      );

      if (!mounted) return;

      if (payload == null) {
        throw Exception('Empty response from getMoonRituals');
      }

      final moonData = Map<String, dynamic>.from(payload['moonData'] ?? {});
      final ritualData = Map<String, dynamic>.from(payload['ritual'] ?? {});
      final recommended = _parseRecommendedCrystals(ritualData);

      setState(() {
        _moonData = moonData.isEmpty ? null : moonData;
        _ritualData = ritualData.isEmpty ? null : ritualData;
        _recommendedCrystals = recommended;
        _selectedPhase = moonData['phase']?.toString() ?? targetPhase;
        _hasLoadedOnce = true;
      });

      unawaited(_persistSelections(
        phase: _selectedPhase,
        intention: intention,
        moonData: moonData,
      ));
    } catch (error, stack) {
      debugPrint('getMoonRituals failed for $targetPhase: $error');
      debugPrint('$stack');
      if (!mounted) return;
      _applyFallback(targetPhase);
      setState(() {
        _errorMessage =
            'Unable to reach the moon ritual service right now. Showing offline guidance.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _parseRecommendedCrystals(Map<String, dynamic> ritual) {
    final raw = ritual['recommendedCrystals'] ?? ritual['recommended_crystals'];
    final recommendations = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          recommendations.add(Map<String, dynamic>.from(item));
        } else if (item is String) {
          recommendations.add({'name': item});
        }
      }
    }
    return recommendations;
  }

  void _applyFallback(String phase) {
    final fallback = moonPhaseData[phase] ?? moonPhaseData['Full Moon'];
    final crystals = fallback?['crystals'] is List
        ? List<String>.from(fallback!['crystals'])
        : <String>[];
    final narrative = fallback?['ritual'];
    final prompts = fallback?['prompts'] is List
        ? List<String>.from(fallback!['prompts'])
        : <String>[];

    setState(() {
      _moonData = {
        'phase': phase,
        'emoji': '🌙',
        'illumination': null,
      };
      _ritualData = {
        'focus': fallback?['meaning'] ?? 'Attune to lunar wisdom',
        'energy': fallback?['meaning'] ?? 'Reflection',
        'timing': 'Work with this energy during the ${phase.toLowerCase()} phase.',
        'steps': narrative != null ? [narrative] : <String>[],
        'journalingPrompts': prompts,
        'affirmation': fallback?['affirmation'] ??
            'I honour the wisdom of the moon.',
        'narrative': null,
      };
      _recommendedCrystals = crystals.map((name) => {'name': name}).toList();
      _selectedPhase = phase;
      _hasLoadedOnce = true;
    });

    unawaited(_persistSelections(
      phase: phase,
      intention: _intentionController.text.trim(),
      moonData: _moonData,
    ));
  }

  void _onPhaseSelected(String phase) {
    if (phase == _selectedPhase) return;
    _refreshRitual(phase: phase);
  }

  Future<void> _restorePersistedSelections() async {
    DateTime? syncedAt;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIntention = prefs.getString(_prefsMoonIntentionKey);
      final savedPhase = prefs.getString(_prefsMoonPhaseKey);
      final syncedIso = prefs.getString(_prefsMoonSyncTimestampKey);

      if (!mounted) return;

      if (savedIntention != null && savedIntention.isNotEmpty) {
        _intentionController.text = savedIntention;
      }
      if (savedPhase != null && _phaseOrder.contains(savedPhase)) {
        setState(() {
          _selectedPhase = savedPhase;
        });
      }
      if (syncedIso != null && syncedIso.isNotEmpty) {
        syncedAt = DateTime.tryParse(syncedIso);
      }
    } catch (error) {
      debugPrint('Failed to restore moon ritual preferences: $error');
    }

    _localPreferenceTimestamp = syncedAt;
    await _hydrateRemotePreference(localTimestamp: syncedAt);
  }

  Future<void> _hydrateRemotePreference({DateTime? localTimestamp}) async {
    try {
      final preference = await _preferenceService.loadMoonPreference();
      if (!mounted || preference == null) {
        return;
      }

      final remoteUpdated = preference.updatedAt;
      final shouldApply = remoteUpdated == null ||
          localTimestamp == null ||
          remoteUpdated.isAfter(localTimestamp);

      if (!shouldApply) {
        return;
      }

      if (preference.intention != null) {
        _intentionController.text = preference.intention!;
      }

      setState(() {
        if (_phaseOrder.contains(preference.phase)) {
          _selectedPhase = preference.phase;
        }
        if (preference.metadata != null && preference.metadata!.isNotEmpty) {
          _moonData = preference.metadata;
        }
      });

      await _persistLocalSelections(
        phase: _selectedPhase,
        intention: _intentionController.text.trim(),
        moonData: preference.metadata ?? _moonData,
        remoteUpdatedAt: preference.updatedAt,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to hydrate moon ritual preference: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _persistSelections({
    required String phase,
    String? intention,
    Map<String, dynamic>? moonData,
    bool syncRemote = true,
  }) async {
    final normalizedIntention = intention ?? _intentionController.text.trim();
    final metadata = moonData ?? _moonData;

    await _persistLocalSelections(
      phase: phase,
      intention: normalizedIntention,
      moonData: metadata,
    );

    if (syncRemote) {
      unawaited(_persistRemoteSelections(
        phase: phase,
        intention: normalizedIntention,
        moonData: metadata,
      ));
    }
  }

  Future<void> _persistLocalSelections({
    required String phase,
    required String intention,
    Map<String, dynamic>? moonData,
    DateTime? remoteUpdatedAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsMoonPhaseKey, phase);
      await prefs.setString(_prefsMoonIntentionKey, intention);

      final syncedAt = remoteUpdatedAt ?? DateTime.now();
      _localPreferenceTimestamp = syncedAt;
      await prefs.setString(
        _prefsMoonSyncTimestampKey,
        syncedAt.toIso8601String(),
      );

      final metadataTimestamp = moonData?['timestamp']?.toString();
      if (metadataTimestamp != null && metadataTimestamp.isNotEmpty) {
        await prefs.setString('moon_ritual_last_timestamp', metadataTimestamp);
      }
    } catch (error) {
      debugPrint('Failed to persist moon ritual preferences: $error');
    }
  }

  Future<void> _persistRemoteSelections({
    required String phase,
    required String intention,
    Map<String, dynamic>? moonData,
  }) async {
    try {
      await _preferenceService.saveMoonPreference(
        phase: phase,
        intention: intention,
        metadata: moonData,
      );
    } catch (error) {
      debugPrint('Failed to sync moon ritual preference: $error');
    }
  }

  void _queueIntentionPersist() {
    _intentionSaveDebounce?.cancel();
    _intentionSaveDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_persistSelections(phase: _selectedPhase));
    });
  }

  DateTime? _parseMoonDate(dynamic value) {
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String) {
      try {
        return DateTime.tryParse(value)?.toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _formatMoonDate(dynamic value) {
    final parsed = _parseMoonDate(value);
    if (parsed == null) {
      return null;
    }
    return _moonDateFormat.format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Moon Rituals',
          style: GoogleFonts.cinzel(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0015),
                  Color(0xFF1A0B2E),
                  Color(0xFF2D1B69),
                ],
              ),
            ),
          ),
          ...List.generate(50, (index) {
            return Positioned(
              top: (index * 37.0) % MediaQuery.of(context).size.height,
              left: (index * 47.0) % MediaQuery.of(context).size.width,
              child: Container(
                width: 2,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
          SafeArea(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: Color(0xFF6366F1),
              minHeight: 2,
            ),
          const SizedBox(height: 12),
          Text(
            'Attune to the lunar cycle with personalised ritual guidance. '
            'Select a phase, add your intention, and we will curate crystals, steps, '
            'and journaling prompts for tonight\'s ceremony.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildIntentionEditor(),
          const SizedBox(height: 24),
          _buildMoonPhaseSelector(),
          const SizedBox(height: 24),
          if (_errorMessage != null) _buildErrorBanner(),
          _buildPhaseSummary(),
          const SizedBox(height: 24),
          _buildRecommendedCrystals(),
          const SizedBox(height: 24),
          _buildRitualDetails(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentionEditor() {
    return _GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Intention',
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optional: tailor the ritual to a focus such as "emotional healing" or '
            '"career momentum".',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _intentionController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Deep emotional healing',
              hintStyle: GoogleFonts.poppins(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _refreshRitual(),
            onChanged: (_) => _queueIntentionPersist(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Last intention is saved for your next ritual.',
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _refreshRitual(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Refresh Guidance'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonPhaseSelector() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _phaseOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final phase = _phaseOrder[index];
          final isSelected = phase == _selectedPhase;

          return GestureDetector(
            onTap: () => _onPhaseSelected(phase),
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      )
                    : null,
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white24,
                  width: 1.2,
                ),
                color: isSelected ? null : Colors.white.withOpacity(0.05),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getMoonIcon(index),
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 30,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    phase,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getMoonIcon(int index) {
    const icons = [
      Icons.brightness_3,
      Icons.brightness_2,
      Icons.brightness_medium,
      Icons.brightness_4,
      Icons.brightness_1,
      Icons.brightness_5,
      Icons.brightness_6,
      Icons.brightness_7,
    ];
    return icons[index % icons.length];
  }

  Widget _buildPhaseSummary() {
    if (!_hasLoadedOnce) {
      return const SizedBox.shrink();
    }

    final focus = _ritualData?['focus']?.toString() ??
        moonPhaseData[_selectedPhase]?['meaning']?.toString() ??
            'Attune to lunar wisdom';
    final energy = _ritualData?['energy']?.toString() ?? focus;
    final timing = _ritualData?['timing']?.toString() ??
        'Work with this energy during the ${_selectedPhase.toLowerCase()} phase.';
    final affirmation =
        _ritualData?['affirmation']?.toString() ?? moonPhaseData[_selectedPhase]?
                ['affirmation']?.toString() ??
            '';
    final illumination = _moonData?['illumination'];
    final emoji = _moonData?['emoji']?.toString() ?? '🌙';
    final illuminationText = illumination is num
        ? '${(illumination * 100).clamp(0, 100).toStringAsFixed(0)}% illumination'
        : null;
    final metaChips = _buildMoonMetaChips();

    return _GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPhase,
                      style: GoogleFonts.cinzel(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (illuminationText != null)
                      Text(
                        illuminationText,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Focus', value: focus),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Energy', value: energy),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Timing', value: timing),
          if (affirmation.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF6366F1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      affirmation,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (metaChips != null) ...[
            const SizedBox(height: 16),
            metaChips,
          ],
        ],
      ),
    );
  }

  Widget? _buildMoonMetaChips() {
    final chips = <Widget>[];
    final nextFull = _formatMoonDate(_moonData?['nextFullMoon']);
    final nextNew = _formatMoonDate(_moonData?['nextNewMoon']);

    if (nextFull != null) {
      chips.add(_MetaChip(
        label: 'Next full moon',
        value: nextFull,
        icon: Icons.brightness_5,
      ));
    }
    if (nextNew != null) {
      chips.add(_MetaChip(
        label: 'Next new moon',
        value: nextNew,
        icon: Icons.brightness_3,
      ));
    }

    if (chips.isEmpty) {
      return null;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _buildRecommendedCrystals() {
    if (!_hasLoadedOnce) {
      return const SizedBox.shrink();
    }

    if (_recommendedCrystals.isEmpty) {
      return _GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended Crystals',
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add crystals to your collection to receive personalised suggestions.',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Crystals',
          style: GoogleFonts.cinzel(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recommendedCrystals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final crystal = _recommendedCrystals[index];
              final name = crystal['name']?.toString() ?? 'Unknown';
              final description = crystal['description']?.toString();
              final isOwned = _ownedCrystals.contains(name.toLowerCase());

              return _GlassContainer(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.diamond,
                          color:
                              isOwned ? const Color(0xFF10B981) : Colors.white70,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (description != null && description.isNotEmpty)
                      Expanded(
                        child: Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          isOwned
                              ? 'In your collection'
                              : 'Consider adding to your toolkit',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRitualDetails() {
    if (!_hasLoadedOnce) {
      return const SizedBox.shrink();
    }

    final steps = (_ritualData?['steps'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    final prompts = (_ritualData?['journalingPrompts'] as List?)
            ?.whereType<String>()
            .toList() ??
        <String>[];
    final narrative = _ritualData?['narrative']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (steps.isNotEmpty)
          _GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ritual Steps',
                  style: GoogleFonts.cinzel(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(steps.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. ',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF6366F1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            steps[index],
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        if (prompts.isNotEmpty) ...[
          const SizedBox(height: 20),
          _GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Journaling Prompts',
                  style: GoogleFonts.cinzel(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ...prompts.map(
                  (prompt) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.north_east, color: Colors.white60, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            prompt,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (narrative != null && narrative.isNotEmpty) ...[
          const SizedBox(height: 20),
          _GlassContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ceremony Narrative',
                  style: GoogleFonts.cinzel(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  narrative,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GlassContainer extends StatelessWidget {
  const _GlassContainer({
    required this.child,
    this.width,
  });

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
