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
  final Map<String, Map<String, dynamic>> _fallbackTemplates = {
    'New Moon': {
      'emoji': '🌑',
      'meaning': 'New beginnings, setting intentions',
      'energy': 'Intention',
      'timing': 'First two nights of the lunar cycle',
      'crystals': ['Black Moonstone', 'Labradorite', 'Clear Quartz'],
      'ritual': 'Write down three intentions for the coming cycle and charge them beneath moonlight or a selenite plate.',
      'steps': [
        'Cleanse your space with incense or sound.',
        'Write three specific intentions for the lunar month.',
        'Hold a crystal while visualising each intention infusing with light.',
      ],
      'prompts': [
        'What do I want to call into my world this cycle?',
        'What energetic clutter am I ready to release so new growth can emerge?',
      ],
      'affirmation': 'I plant seeds of intention that bloom with the moon.',
    },
    'Waxing Crescent': {
      'emoji': '🌒',
      'meaning': 'Growth, manifestation, taking action',
      'energy': 'Momentum',
      'timing': 'Three to seven days after the new moon',
      'crystals': ['Citrine', 'Green Aventurine', 'Pyrite'],
      'ritual': 'Charge your crystals under gentle moonlight and take one inspired action toward each intention.',
      'steps': [
        'Visualise your intentions already in motion.',
        'Charge supporting crystals in the moonlight.',
        'Journal one tangible step you will take this week.',
      ],
      'prompts': [
        'Where am I already seeing glimmers of progress?',
        'What supportive habits will keep my momentum strong?',
      ],
      'affirmation': 'I nurture my dreams into reality.',
    },
    'First Quarter': {
      'emoji': '🌓',
      'meaning': 'Challenges, decisions, commitment',
      'energy': 'Courage',
      'timing': 'Seven to ten days after the new moon',
      'crystals': ['Carnelian', 'Red Jasper', 'Tiger Eye'],
      'ritual': 'Meditate on current obstacles and call in the fire to move through them with courage.',
      'steps': [
        'Ground yourself with breath or movement.',
        'Place energising crystals on your solar plexus.',
        'Speak aloud one bold commitment you will honour.',
      ],
      'prompts': [
        'What fear is ready to be transformed into action?',
        'How can I lovingly recommit to my intentions?',
      ],
      'affirmation': 'I face challenges with courage and wisdom.',
    },
    'Waxing Gibbous': {
      'emoji': '🌔',
      'meaning': 'Refinement, adjustment, patience',
      'energy': 'Refinement',
      'timing': 'Ten to thirteen days after the new moon',
      'crystals': ['Rose Quartz', 'Rhodonite', 'Pink Tourmaline'],
      'ritual': 'Pause to acknowledge progress, refine intentions, and soften with gratitude.',
      'steps': [
        'List recent wins and the lessons they brought.',
        'Hold a heart-based crystal while expressing gratitude.',
        'Adjust intentions or timelines where needed.',
      ],
      'prompts': [
        'What progress deserves celebration today?',
        'Where can patience and compassion create more space?',
      ],
      'affirmation': 'I trust in divine timing.',
    },
    'Full Moon': {
      'emoji': '🌕',
      'meaning': 'Culmination, release, gratitude',
      'energy': 'Illumination',
      'timing': 'Fourteen to seventeen days after the new moon',
      'crystals': ['Selenite', 'Moonstone', 'Clear Quartz'],
      'ritual': 'Release what no longer serves, bask in lunar light, and celebrate your journey.',
      'steps': [
        'Write down what you are ready to release.',
        'Burn or tear the list as a release ceremony.',
        'Bathed in moonlight, express gratitude for lessons learned.',
      ],
      'prompts': [
        'What is illuminated that I previously could not see?',
        'What am I grateful to release at this time?',
      ],
      'affirmation': 'I release and receive with grace.',
    },
    'Waning Gibbous': {
      'emoji': '🌖',
      'meaning': 'Gratitude, sharing, generosity',
      'energy': 'Integration',
      'timing': 'Seventeen to twenty days after the new moon',
      'crystals': ['Amethyst', 'Lepidolite', 'Blue Lace Agate'],
      'ritual': 'Share your wisdom, express gratitude, and integrate lessons with calm.',
      'steps': [
        'Journal about lessons from the cycle so far.',
        'Offer gratitude to a mentor, friend, or the universe.',
        'Meditate with calming crystals to integrate insights.',
      ],
      'prompts': [
        'Which experiences am I ready to share with others?',
        'How can generosity keep this energy flowing?',
      ],
      'affirmation': 'I am grateful for all I have learned.',
    },
    'Last Quarter': {
      'emoji': '🌗',
      'meaning': 'Release, forgiveness, letting go',
      'energy': 'Closure',
      'timing': 'Twenty to twenty-three days after the new moon',
      'crystals': ['Smoky Quartz', 'Black Tourmaline', 'Obsidian'],
      'ritual': 'Cleanse your space, offer forgiveness, and prepare the soil for the next cycle.',
      'steps': [
        'Smoke cleanse or sound clear your environment.',
        'Hold grounding stones while affirming forgiveness.',
        'Create space—physically or energetically—for what is next.',
      ],
      'prompts': [
        'Who (including myself) is ready to be forgiven?',
        'What clutter can I release to feel lighter?',
      ],
      'affirmation': 'I release the past with love.',
    },
    'Waning Crescent': {
      'emoji': '🌘',
      'meaning': 'Rest, reflection, preparation',
      'energy': 'Surrender',
      'timing': 'Twenty-three to twenty-nine days after the new moon',
      'crystals': ['Selenite', 'Celestite', 'Blue Calcite'],
      'ritual': 'Slow down, dream, and listen for intuitive whispers as you prepare for renewal.',
      'steps': [
        'Create a calming bedtime ritual with soothing crystals.',
        'Record dreams or intuitive hits each morning.',
        'Visualise the seeds you will soon plant.',
      ],
      'prompts': [
        'What does my body and spirit need for renewal?',
        'What intuitive nudges are whispering for my attention?',
      ],
      'affirmation': 'I honour the cycles of rest and action.',
    },
  };

  String? _selectedPhase;
  Map<String, dynamic>? _moonData;
  Map<String, dynamic>? _ritualData;
  List<Map<String, dynamic>> _recommendedCrystals = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRitual());
  }

  Future<void> _loadRitual({String? phase}) async {
    final user = FirebaseAuth.instance.currentUser;
    final fallbackPhase = phase ?? _selectedPhase ?? 'New Moon';

    if (user == null) {
      setState(() {
        _errorMessage = 'Sign in to receive personalised moon rituals.';
      });
      _applyFallback(fallbackPhase, loading: false);
      return;
    }

    final collectionService = context.read<CollectionServiceV2>();
    if (!collectionService.isLoaded) {
      await collectionService.initialize();
    }

    final ownedCrystals = collectionService.collection
        .map((entry) => entry.crystal.name)
        .where((name) => name.isNotEmpty)
        .toList();

    final profilePayload = <String, dynamic>{
      'subscriptionTier': context.read<AppState>().subscriptionTier,
    };

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final profile = userDoc.data()?['profile'];
      if (profile is Map<String, dynamic>) {
        profilePayload.addAll(Map<String, dynamic>.from(profile));
      }

      final onboarding = userDoc.data()?['onboarding'];
      if (onboarding is Map<String, dynamic>) {
        if (!profilePayload.containsKey('intentions') && onboarding['intentions'] is List) {
          profilePayload['intentions'] = onboarding['intentions'];
        }
        if (!profilePayload.containsKey('focusChakras') && onboarding['chakraFocus'] is List) {
          profilePayload['focusChakras'] = onboarding['chakraFocus'];
        }
      }
    } catch (error) {
      debugPrint('Failed to load profile for moon ritual: $error');
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (phase != null) {
        _selectedPhase = phase;
      }
    });

    try {
      final service = context.read<CrystalService>();
      final response = await service.getMoonRituals(
        moonPhase: phase ?? _selectedPhase ?? fallbackPhase,
        userCrystals: ownedCrystals,
        userProfile: profilePayload,
      );

      if (!mounted) return;

      if (response == null) {
        _errorMessage = 'No ritual data returned. Showing offline guidance.';
        _applyFallback(fallbackPhase, loading: false);
        return;
      }

      final ritualMap = Map<String, dynamic>.from(response['ritual'] as Map? ?? {});
      final moonMap = Map<String, dynamic>.from(response['moonData'] as Map? ?? {});
      final recommended = (ritualMap['recommendedCrystals'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        _selectedPhase = moonMap['phase']?.toString() ?? fallbackPhase;
        _moonData = moonMap;
        _ritualData = ritualMap;
        _recommendedCrystals = recommended;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('Moon ritual fetch failed: $error');
      setState(() {
        _errorMessage = 'Unable to fetch lunar guidance. Showing offline template.';
      });
      _applyFallback(fallbackPhase, loading: false);
    }
  }

  void _applyFallback(String phase, {bool loading = false}) {
    final template = _fallbackTemplates[phase] ?? _fallbackTemplates['New Moon']!;
    setState(() {
      _selectedPhase = phase;
      _moonData = {
        'phase': phase,
        'emoji': template['emoji'],
        'illumination': template['illumination'],
      };
      _ritualData = {
        'focus': template['meaning'],
        'energy': template['energy'],
        'timing': template['timing'],
        'steps': template['steps'] ?? [template['ritual']],
        'journalingPrompts': template['prompts'] ?? const <String>[],
        'affirmation': template['affirmation'],
        'narrative': template['ritual'],
      };
      _recommendedCrystals = (template['crystals'] as List<String>)
          .map((name) => {'name': name})
          .toList();
      _isLoading = loading;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ownedCrystalNames = context.select<CollectionServiceV2, Set<String>>(
      (service) => service.collection
          .map((entry) => entry.crystal.name.toLowerCase())
          .toSet(),
    );

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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMoonPhaseSelector(),
                        const SizedBox(height: 24),
                        if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
                        if (_selectedPhase != null) ...[
                          _buildPhaseInfoCard(),
                          const SizedBox(height: 24),
                          _buildRecommendedCrystals(ownedCrystalNames),
                          const SizedBox(height: 24),
                          _buildRitualDetails(),
                          const SizedBox(height: 24),
                          _buildScheduleButton(),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.deepOrange.withOpacity(0.25),
        border: Border.all(color: Colors.deepOrange.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(color: Colors.white, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonPhaseSelector() {
    final phases = _fallbackTemplates.keys.toList();
    final currentPhase = _selectedPhase ?? phases.first;

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: phases.length,
        itemBuilder: (context, index) {
          final phase = phases[index];
          final isSelected = phase == currentPhase;

          return GestureDetector(
            onTap: () => _loadRitual(phase: phase),
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      )
                    : null,
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white30,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _fallbackTemplates[phase]?['emoji']?.toString() ?? '🌙',
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
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

  Widget _buildPhaseInfoCard() {
    final ritual = _ritualData ?? const <String, dynamic>{};
    final moon = _moonData ?? const <String, dynamic>{};

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    moon['emoji']?.toString() ?? '🌙',
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedPhase ?? 'Lunar Guidance',
                      style: GoogleFonts.cinzel(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ritual['focus']?.toString() ?? 'Align with lunar wisdom and set sacred intentions.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildInfoChip(Icons.auto_awesome, 'Energy', ritual['energy'] ?? 'Alignment'),
                  _buildInfoChip(Icons.access_time, 'Timing', ritual['timing'] ?? 'Anytime under the moon'),
                  if (moon['illumination'] != null)
                    _buildInfoChip(
                      Icons.brightness_2,
                      'Illumination',
                      '${(moon['illumination'] as num).toStringAsFixed(0)}% light',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCrystals(Set<String> ownedNames) {
    final crystals = _recommendedCrystals.isNotEmpty
        ? _recommendedCrystals
        : (_ritualData?['recommendedCrystals'] as List? ?? []);

    if (crystals.isEmpty) {
      return const SizedBox.shrink();
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
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: crystals.length,
            itemBuilder: (context, index) {
              final crystal = crystals[index];
              final name = crystal['name']?.toString() ?? 'Crystal';
              final isOwned = ownedNames.contains(name.toLowerCase());
              final intents = (crystal['intents'] as List?)?.cast<String>() ?? const [];
              final subtitle = intents.isNotEmpty ? intents.take(2).join(' • ') : null;

              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.04),
                          ],
                        ),
                        border: Border.all(
                          color: isOwned
                              ? const Color(0xFF10B981).withOpacity(0.6)
                              : Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.diamond,
                            color: isOwned ? const Color(0xFF10B981) : Colors.white70,
                            size: 34,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
    final ritual = _ritualData ?? const <String, dynamic>{};
    final steps = (ritual['steps'] as List?)?.cast<String>() ?? const [];
    final prompts = (ritual['journalingPrompts'] as List?)?.cast<String>() ?? const [];
    final narrative = ritual['narrative']?.toString();
    final affirmation = ritual['affirmation']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (narrative != null && narrative.isNotEmpty)
          _buildGlassCard(
            title: 'Ritual Narrative',
            icon: Icons.auto_awesome,
            child: Text(
              narrative,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.white.withOpacity(0.9),
                height: 1.6,
              ),
            ),
          ),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildGlassCard(
            title: 'Moonlit Steps',
            icon: Icons.format_list_numbered,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(steps.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                          color: Colors.white.withOpacity(0.08),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          steps[index],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
        if (prompts.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildGlassCard(
            title: 'Journal Prompts',
            icon: Icons.menu_book,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: prompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.white70, fontSize: 18)),
                      Expanded(
                        child: Text(
                          prompt,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (affirmation != null && affirmation.isNotEmpty) ...[
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Affirmation',
                      style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      affirmation,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGlassCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.04),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFFFFD700)),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
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
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ritual scheduled for ${_selectedPhase ?? 'this lunar phase'}!',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: const Color(0xFF6366F1),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
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
    );
  }
}
