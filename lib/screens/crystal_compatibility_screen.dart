import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/collection_service_v2.dart';
import '../services/crystal_service.dart';
import '../services/ritual_preference_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/no_particles.dart';

class CrystalCompatibilityScreen extends StatefulWidget {
  const CrystalCompatibilityScreen({super.key});

  @override
  State<CrystalCompatibilityScreen> createState() => _CrystalCompatibilityScreenState();
}

class _CrystalCompatibilityScreenState extends State<CrystalCompatibilityScreen> {
  static const int _maxSelection = 6;

  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _manualCrystalController = TextEditingController();
  final FocusNode _manualCrystalFocusNode = FocusNode();

  final Set<String> _selectedCrystals = <String>{};
  final List<String> _manualEntries = <String>[];
  final List<String> _intentionHistory = <String>[];

  Map<String, dynamic>? _analysis;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillSelection();
      unawaited(_loadStoredIntention());
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

      setState(() {
        _analysis = response;
        _errorMessage = null;
        if (purpose.isNotEmpty) {
          _updateIntentionHistory(purpose);
        }
      });
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
    if (value is Iterable) {
      return value
          .map((item) => item?.toString() ?? '')
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
    }
    return const [];
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
