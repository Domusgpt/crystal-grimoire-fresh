import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/collection_service_v2.dart';
import '../services/crystal_service.dart';

class MoonRitualScreen extends StatefulWidget {
  const MoonRitualScreen({Key? key}) : super(key: key);

  @override
  State<MoonRitualScreen> createState() => _MoonRitualScreenState();
}

class _MoonRitualScreenState extends State<MoonRitualScreen> {
  final TextEditingController _intentionController = TextEditingController();

  final Map<String, Map<String, dynamic>> _phaseTemplates = {
    'New Moon': {
      'focus': 'New beginnings, setting intentions',
      'affirmation': 'I plant seeds of intention that will bloom with the moon.',
      'suggestedCrystals': ['Black Moonstone', 'Labradorite', 'Clear Quartz'],
      'prompts': [
        'What am I ready to begin?',
        'Which dream feels ready to be planted?'
      ],
    },
    'Waxing Crescent': {
      'focus': 'Growth, manifestation, taking action',
      'affirmation': 'I nurture my dreams into reality.',
      'suggestedCrystals': ['Citrine', 'Green Aventurine', 'Pyrite'],
      'prompts': [
        'What inspired action can I take this week?',
        'Where do I feel momentum building?'
      ],
    },
    'First Quarter': {
      'focus': 'Challenges, decisions, commitment',
      'affirmation': 'I face challenges with courage and wisdom.',
      'suggestedCrystals': ['Carnelian', 'Red Jasper', 'Tiger Eye'],
      'prompts': [
        'What resistance needs alchemy?',
        'How can I recommit to my intention?'
      ],
    },
    'Waxing Gibbous': {
      'focus': 'Refinement, adjustment, patience',
      'affirmation': 'I trust in divine timing.',
      'suggestedCrystals': ['Rose Quartz', 'Rhodonite', 'Pink Tourmaline'],
      'prompts': [
        'What refinement would bring more harmony?',
        'Where can I soften my expectations?'
      ],
    },
    'Full Moon': {
      'focus': 'Culmination, release, gratitude',
      'affirmation': 'I release and receive with grace.',
      'suggestedCrystals': ['Selenite', 'Moonstone', 'Clear Quartz'],
      'prompts': [
        'What is illuminated for me right now?',
        'What am I ready to release with gratitude?'
      ],
    },
    'Waning Gibbous': {
      'focus': 'Gratitude, sharing, generosity',
      'affirmation': 'I am grateful for all I have learned.',
      'suggestedCrystals': ['Amethyst', 'Lepidolite', 'Blue Lace Agate'],
      'prompts': [
        'How can I share my wisdom?',
        'Where can I express heartfelt gratitude?'
      ],
    },
    'Last Quarter': {
      'focus': 'Release, forgiveness, letting go',
      'affirmation': 'I release the past with love.',
      'suggestedCrystals': ['Smoky Quartz', 'Black Tourmaline', 'Obsidian'],
      'prompts': [
        'What am I still holding that wants release?',
        'Who (including myself) needs forgiveness?'
      ],
    },
    'Waning Crescent': {
      'focus': 'Rest, reflection, preparation',
      'affirmation': 'I honor the cycles of rest and action.',
      'suggestedCrystals': ['Selenite', 'Celestite', 'Blue Calcite'],
      'prompts': [
        'How can I restore my energy?',
        'What whispers are arriving in the quiet?'
      ],
    },
  };

  String selectedPhase = 'New Moon';
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _moonData;
  Map<String, dynamic>? _ritualData;
  List<Map<String, dynamic>> _recommendedCrystals = [];
  List<String> _ownedCrystals = [];
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _intentionController.text =
        _phaseTemplates[selectedPhase]?['focus']?.toString() ?? 'Set aligned intentions';
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _intentionController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadUserProfile();
    await _refreshOwnedCrystals();
    await _fetchRitual();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Sign in to access moon rituals.';
        _isLoading = false;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profile = snapshot.data()?['profile'];
      if (profile is Map<String, dynamic>) {
        setState(() {
          _userProfile = Map<String, dynamic>.from(profile);
        });
      }
    } catch (error) {
      debugPrint('Failed to load user profile: $error');
    }
  }

  Future<void> _refreshOwnedCrystals() async {
    final collectionService = context.read<CollectionServiceV2>();
    final names = collectionService.collection
        .map((entry) => entry.crystal.name)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
    setState(() {
      _ownedCrystals = names;
    });
  }

  Future<void> _fetchRitual({String? newPhase}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sign in to access moon rituals.';
      });
      return;
    }

    final phase = newPhase ?? selectedPhase;
    setState(() {
      selectedPhase = phase;
      _isLoading = true;
      _errorMessage = null;
    });

    await _refreshOwnedCrystals();

    try {
      final crystalService = context.read<CrystalService>();
      final response = await crystalService.getMoonRituals(
        moonPhase: phase,
        userCrystals: _ownedCrystals,
        userProfile: _userProfile ?? {},
        intention: _intentionController.text,
      );

      if (response == null) {
        throw Exception('No ritual data returned.');
      }

      final moon = Map<String, dynamic>.from(response['moonData'] as Map? ?? {});
      final ritual = Map<String, dynamic>.from(response['ritual'] as Map? ?? {});
      final recommended = (ritual['recommendedCrystals'] as List?)
              ?.map((item) => Map<String, dynamic>.from(item as Map))
              .toList() ??
          <Map<String, dynamic>>[];

      setState(() {
        _moonData = moon;
        _ritualData = ritual;
        _recommendedCrystals = recommended;
        selectedPhase = moon['phase']?.toString() ?? phase;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Moon ritual fetch failed: $error');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load ritual guidance. Try again soon.';
      });
    }
  }

  Future<void> _scheduleRitual() async {
    try {
      await context.read<AppState>().incrementUsage('ritual_complete');
    } catch (_) {
      // Ignore tracking failures during UI interactions.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ritual scheduled for $selectedPhase!'),
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            tooltip: 'Refresh guidance',
            onPressed: _isLoading ? null : () => _fetchRitual(),
          )
        ],
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
          ...List.generate(60, (index) {
            return Positioned(
              top: (index * 43.0) % MediaQuery.of(context).size.height,
              left: (index * 53.0) % MediaQuery.of(context).size.width,
              child: Container(
                width: 2,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }

    if (_errorMessage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.nightlight_round, size: 54, color: Colors.pinkAccent.shade100),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchRitual,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Try Again'),
          )
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMoonPhaseSelector(),
          const SizedBox(height: 20),
          _buildIntentionField(),
          const SizedBox(height: 20),
          _buildPhaseInfoCard(),
          const SizedBox(height: 24),
          _buildRecommendedCrystals(),
          const SizedBox(height: 24),
          _buildRitualDetails(),
          const SizedBox(height: 24),
          _buildScheduleButton(),
        ],
      ),
    );
  }

  Widget _buildMoonPhaseSelector() {
    final phases = _phaseTemplates.keys.toList();
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: phases.length,
        itemBuilder: (context, index) {
          final phase = phases[index];
          final isSelected = phase == selectedPhase;
          return GestureDetector(
            onTap: () {
              _intentionController.text =
                  _phaseTemplates[phase]?['focus']?.toString() ?? _intentionController.text;
              _fetchRitual(newPhase: phase);
            },
            child: Container(
              width: 88,
              margin: EdgeInsets.only(right: index == phases.length - 1 ? 0 : 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      )
                    : null,
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _phaseEmoji(phase),
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    phase.split(' ').first,
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

  Widget _buildIntentionField() {
    return TextField(
      controller: _intentionController,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Intention',
        labelStyle: const TextStyle(color: Colors.white70),
        suffixIcon: IconButton(
          icon: const Icon(Icons.auto_fix_high, color: Color(0xFF9F7AEA)),
          onPressed: _isLoading ? null : () => _fetchRitual(),
          tooltip: 'Refresh guidance with this intention',
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
        ),
      ),
    );
  }

  Widget _buildPhaseInfoCard() {
    final template = _phaseTemplates[selectedPhase] ?? const {};
    final ritual = _ritualData ?? const {};
    final moon = _moonData ?? const {};

    final focus = ritual['focus']?.toString() ?? template['focus']?.toString() ?? '';
    final affirmation = ritual['affirmation']?.toString() ?? template['affirmation']?.toString() ?? '';
    final energy = ritual['energy']?.toString();
    final timing = ritual['timing']?.toString();
    final illumination = _formatIllumination(moon['illumination']);
    final nextFullMoon = moon['nextFullMoon']?.toString();
    final nextNewMoon = moon['nextNewMoon']?.toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white24, width: 1.4),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${moon['emoji'] ?? _phaseEmoji(selectedPhase)} $selectedPhase',
                    style: GoogleFonts.cinzel(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (illumination != null)
                    Text(
                      'Illumination $illumination',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                focus,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.92),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              if (energy != null || timing != null)
                Row(
                  children: [
                    if (energy != null)
                      Expanded(
                        child: _buildInfoChip('Energy', energy),
                      ),
                    if (energy != null && timing != null)
                      const SizedBox(width: 12),
                    if (timing != null)
                      Expanded(
                        child: _buildInfoChip('Timing', timing),
                      ),
                  ],
                ),
              if (nextFullMoon != null || nextNewMoon != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (nextFullMoon != null)
                      Expanded(
                        child: _buildInfoChip('Next Full Moon', _formatDate(nextFullMoon)),
                      ),
                    if (nextFullMoon != null && nextNewMoon != null)
                      const SizedBox(width: 12),
                    if (nextNewMoon != null)
                      Expanded(
                        child: _buildInfoChip('Next New Moon', _formatDate(nextNewMoon)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFFFD700)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        affirmation,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCrystals() {
    final templateCrystals =
        List<String>.from(_phaseTemplates[selectedPhase]?['suggestedCrystals'] ?? const <String>[]);
    final ownedSet = _ownedCrystals.map((e) => e.toLowerCase()).toSet();
    final items = _recommendedCrystals.isNotEmpty
        ? _recommendedCrystals
        : templateCrystals
            .map((name) => {
                  'name': name,
                  'healingProperties': const <String>[],
                })
            .toList();

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
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final crystal = items[index];
              final name = crystal['name']?.toString() ?? 'Crystal';
              final healingProps = List<String>.from(crystal['healingProperties'] ?? const <String>[]);
              final isOwned = ownedSet.contains(name.toLowerCase());

              return Container(
                width: 160,
                margin: EdgeInsets.only(right: index == items.length - 1 ? 0 : 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: isOwned ? const Color(0xFF10B981) : Colors.white30,
                          width: 1.4,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.diamond, color: Colors.white70, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (healingProps.isNotEmpty)
                            Text(
                              healingProps.take(2).join(' • '),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                          const Spacer(),
                          if (isOwned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'In Collection',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRitualDetails() {
    final ritual = _ritualData ?? const {};
    final narrative = ritual['narrative']?.toString();
    final steps = List<String>.from(ritual['steps'] ?? const <String>[]);
    final prompts = List<String>.from(
      ritual['journalingPrompts'] ?? _phaseTemplates[selectedPhase]?['prompts'] ?? const <String>[],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (narrative != null && narrative.isNotEmpty) ...[
          Text(
            'Ritual Narrative',
            style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            child: Text(
              narrative,
              style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (steps.isNotEmpty) ...[
          Text(
            'Suggested Flow',
            style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${i + 1}. ', style: GoogleFonts.poppins(color: Colors.white70)),
                        Expanded(
                          child: Text(
                            steps[i],
                            style: GoogleFonts.poppins(color: Colors.white, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (prompts.isNotEmpty) ...[
          Text(
            'Journaling Prompts',
            style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final prompt in prompts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.edit_note, color: Color(0xFF9F7AEA), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            prompt,
                            style: GoogleFonts.poppins(color: Colors.white70, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white24),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildScheduleButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _scheduleRitual,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Schedule Ritual',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _phaseEmoji(String phase) {
    final key = phase.toLowerCase();
    if (key.contains('new')) return '🌑';
    if (key.contains('waxing crescent')) return '🌒';
    if (key.contains('first quarter')) return '🌓';
    if (key.contains('waxing gibbous')) return '🌔';
    if (key.contains('full')) return '🌕';
    if (key.contains('waning gibbous')) return '🌖';
    if (key.contains('last quarter')) return '🌗';
    return '🌘';
  }

  String? _formatIllumination(dynamic value) {
    if (value == null) return null;
    final doubleValue = value is num ? value.toDouble() : double.tryParse(value.toString());
    if (doubleValue == null) return null;
    return '${(doubleValue.clamp(0, 1) * 100).toStringAsFixed(0)}%';
  }

  String _formatDate(String raw) {
    try {
      final parsed = DateTime.parse(raw).toLocal();
      return '${parsed.month}/${parsed.day}';
    } catch (_) {
      return raw;
    }
  }
}
