import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/app_state.dart';
import '../services/collection_service_v2.dart';
import 'package:provider/provider.dart';

class MoonRitualScreen extends StatefulWidget {
  const MoonRitualScreen({Key? key}) : super(key: key);

  @override
  State<MoonRitualScreen> createState() => _MoonRitualScreenState();
}

class _MoonRitualScreenState extends State<MoonRitualScreen> {
  String selectedPhase = 'Waxing Crescent';
  List<String> recommendedCrystals = [];
  
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

  @override
  void initState() {
    super.initState();
    _updateRecommendedCrystals();
  }

  void _updateRecommendedCrystals() {
    final collectionService = context.read<CollectionServiceV2>();
    final phaseCrystals = moonPhaseData[selectedPhase]!['crystals'] as List<String>;
    
    // Filter to show only crystals the user owns
    recommendedCrystals = collectionService.collection
        .where((entry) => phaseCrystals.contains(entry.crystal.name))
        .map((entry) => entry.crystal.name)
        .toList();
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
          // Mystical background
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
          
          // Stars effect
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Moon phase selector
                  _buildMoonPhaseSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // Current phase info
                  _buildPhaseInfoCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Recommended crystals
                  _buildRecommendedCrystals(),
                  
                  const SizedBox(height: 24),
                  
                  // Ritual guidance
                  _buildRitualGuidance(),
                  
                  const SizedBox(height: 24),
                  
                  // Schedule ritual button
                  _buildScheduleButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonPhaseSelector() {
    return Container(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: moonPhaseData.keys.length,
        itemBuilder: (context, index) {
          final phase = moonPhaseData.keys.elementAt(index);
          final isSelected = phase == selectedPhase;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedPhase = phase;
                _updateRecommendedCrystals();
              });
            },
            child: Container(
              width: 80,
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
                  Icon(
                    _getMoonIcon(index),
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 32,
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

  IconData _getMoonIcon(int index) {
    final icons = [
      Icons.brightness_3, // New Moon
      Icons.brightness_2, // Waxing Crescent
      Icons.brightness_medium, // First Quarter
      Icons.brightness_4, // Waxing Gibbous
      Icons.brightness_1, // Full Moon
      Icons.brightness_5, // Waning Gibbous
      Icons.brightness_6, // Last Quarter
      Icons.brightness_7, // Waning Crescent
    ];
    return icons[index % icons.length];
  }

  Widget _buildPhaseInfoCard() {
    final phaseInfo = moonPhaseData[selectedPhase]!;
    
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
              Text(
                selectedPhase,
                style: GoogleFonts.cinzel(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                phaseInfo['meaning'],
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),
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
                  children: [
                    const Icon(
                      Icons.format_quote,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        phaseInfo['affirmation'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
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

  Widget _buildRecommendedCrystals() {
    final phaseCrystals = moonPhaseData[selectedPhase]!['crystals'] as List<String>;
    
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
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: phaseCrystals.length,
            itemBuilder: (context, index) {
              final crystal = phaseCrystals[index];
              final isOwned = recommendedCrystals.contains(crystal);
              
              return Container(
                width: 100,
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
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: isOwned 
                              ? const Color(0xFF10B981).withOpacity(0.5)
                              : Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.diamond,
                            color: isOwned 
                                ? const Color(0xFF10B981) 
                                : Colors.white60,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            crystal,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isOwned) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Owned',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildRitualGuidance() {
    final ritual = moonPhaseData[selectedPhase]!['ritual'];
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFFFD700),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Ritual Suggestion',
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                ritual,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),
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
                  'Ritual scheduled for $selectedPhase!',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: const Color(0xFF6366F1),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white,
                ),
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
}