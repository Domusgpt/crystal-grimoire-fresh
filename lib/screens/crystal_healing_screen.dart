import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/collection_service_v2.dart';
import '../services/crystal_service.dart';

class CrystalHealingScreen extends StatefulWidget {
  const CrystalHealingScreen({Key? key}) : super(key: key);

  @override
  State<CrystalHealingScreen> createState() => _CrystalHealingScreenState();
}

class _CrystalHealingScreenState extends State<CrystalHealingScreen>
    with TickerProviderStateMixin {
  late AnimationController _chakraAnimationController;
  late AnimationController _pulseController;
  late Animation<double> _chakraAnimation;
  late Animation<double> _pulseAnimation;

  String? selectedChakra;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _layout;
  List<Map<String, dynamic>> _placements = [];
  List<String> _suggestedCrystals = [];

  final Map<String, Map<String, dynamic>> chakraData = {
    'Crown': {
      'color': const Color(0xFF9B59B6),
      'location': 'Top of head',
      'element': 'Thought',
      'affirmation': 'I am connected to divine wisdom',
    },
    'Third Eye': {
      'color': const Color(0xFF3498DB),
      'location': 'Between eyebrows',
      'element': 'Light',
      'affirmation': 'I trust my intuition',
    },
    'Throat': {
      'color': const Color(0xFF5DADE2),
      'location': 'Throat',
      'element': 'Sound',
      'affirmation': 'I speak my truth with clarity',
    },
    'Heart': {
      'color': const Color(0xFF27AE60),
      'location': 'Center of chest',
      'element': 'Air',
      'affirmation': 'I give and receive love freely',
    },
    'Solar Plexus': {
      'color': const Color(0xFFF39C12),
      'location': 'Above navel',
      'element': 'Fire',
      'affirmation': 'I am confident and empowered',
    },
    'Sacral': {
      'color': const Color(0xFFE67E22),
      'location': 'Below navel',
      'element': 'Water',
      'affirmation': 'I embrace pleasure and creativity',
    },
    'Root': {
      'color': const Color(0xFFE74C3C),
      'location': 'Base of spine',
      'element': 'Earth',
      'affirmation': 'I am grounded and secure',
    },
  };

  @override
  void initState() {
    super.initState();
    _chakraAnimationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _chakraAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _chakraAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) => _generateLayout());
  }

  @override
  void dispose() {
    _chakraAnimationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generateLayout({List<String>? targetChakras, String? intention}) async {
    final collectionService = context.read<CollectionServiceV2>();
    if (!collectionService.isLoaded) {
      await collectionService.initialize();
    }

    final availableCrystals = collectionService.collection
        .map((entry) => entry.crystal.name)
        .where((name) => name.isNotEmpty)
        .toList();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<CrystalService>();
      final response = await service.generateHealingLayout(
        availableCrystals: availableCrystals,
        targetChakras: targetChakras ?? chakraData.keys.toList(),
        intention: intention,
      );

      if (!mounted) return;

      if (response == null) {
        throw Exception('No healing layout returned from the server.');
      }

      final layout = Map<String, dynamic>.from(response['layout'] as Map? ?? {});
      final placements = (layout['placements'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final suggestions = List<String>.from(response['suggestedCrystals'] as List? ?? const []);

      setState(() {
        _layout = layout;
        _placements = placements;
        _suggestedCrystals = suggestions;
        selectedChakra = placements.isNotEmpty
            ? placements.first['chakra']?.toString()
            : (targetChakras?.isNotEmpty == true ? targetChakras!.first : selectedChakra);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to generate healing layout: $error';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? get _currentPlacement {
    if (selectedChakra == null) return null;
    try {
      return _placements.firstWhere(
        (placement) => placement['chakra']?.toString().toLowerCase() ==
            selectedChakra!.toLowerCase(),
        orElse: () => {},
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownedCrystals = context.select<CollectionServiceV2, Set<String>>(
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
          'Crystal Healing',
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
          AnimatedBuilder(
            animation: _chakraAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: EnergyParticlesPainter(
                  animationValue: _chakraAnimation.value,
                ),
              );
            },
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF9B59B6)),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) _buildErrorBanner(_errorMessage!),
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildChakraTimeline(),
                        const SizedBox(height: 24),
                        _buildPlacementDetail(),
                        const SizedBox(height: 24),
                        _buildBreathwork(),
                        const SizedBox(height: 24),
                        _buildIntegration(),
                        const SizedBox(height: 24),
                        _buildSuggestedCrystals(ownedCrystals),
                        const SizedBox(height: 24),
                        _buildActions(),
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

  Widget _buildHeader() {
    final intention = _layout?['intention']?.toString() ?? 'Align your energy centres with intentional crystal work.';
    final duration = _layout?['durationMinutes'] != null
        ? '${_layout!['durationMinutes']} min'
        : '20 min';

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
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Healing Intention',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                intention,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(Icons.timelapse, 'Duration', duration),
                  const SizedBox(width: 12),
                  if (_layout?['affirmation'] != null)
                    _buildInfoChip(Icons.favorite, 'Affirmation', 'Scroll below'),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white54,
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

  Widget _buildChakraTimeline() {
    final chakras = chakraData.keys.toList();
    final current = selectedChakra?.toLowerCase();

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: chakras.length,
        itemBuilder: (context, index) {
          final chakra = chakras[index];
          final data = chakraData[chakra]!;
          final isSelected = chakra.toLowerCase() == current;

          return GestureDetector(
            onTap: () => setState(() => selectedChakra = chakra),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    (data['color'] as Color).withOpacity(isSelected ? 0.8 : 0.4),
                    (data['color'] as Color).withOpacity(isSelected ? 0.6 : 0.2),
                  ],
                ),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: 1.8,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chakra,
                    style: GoogleFonts.cinzel(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['location'],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    data['element'],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  Widget _buildPlacementDetail() {
    final placement = _currentPlacement;
    final chakraInfo = selectedChakra != null ? chakraData[selectedChakra!] : null;

    if (placement == null) {
      return _buildGlassCard(
        title: 'Choose a Chakra',
        icon: Icons.self_improvement,
        child: Text(
          'Select a chakra above to reveal placement guidance and crystal assignments.',
          style: GoogleFonts.poppins(color: Colors.white70, height: 1.5),
        ),
      );
    }

    final focus = (placement['focus'] as List?)?.cast<String>() ?? const [];
    final instructions = placement['instructions']?.toString() ?? 'Hold space for gentle breath and visualise balanced energy.';

    return _buildGlassCard(
      title: '${placement['chakra']} Placement',
      icon: Icons.brightness_low,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chakraInfo != null) ...[
            Text(
              chakraInfo['affirmation'],
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            instructions,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
            ),
          ),
          if (focus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: focus
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        item,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreathwork() {
    final breathwork = _layout?['breathwork'];
    if (breathwork is! Map<String, dynamic>) {
      return const SizedBox.shrink();
    }

    return _buildGlassCard(
      title: breathwork['technique']?.toString() ?? 'Breathwork',
      icon: Icons.air,
      child: Text(
        breathwork['description']?.toString() ?? 'Use intentional breathing to anchor energy between placements.',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white.withOpacity(0.9),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildIntegration() {
    final integration = _layout?['integration'];
    final affirmation = _layout?['affirmation'];

    final integrationList = integration is List ? integration.cast<String>() : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (integrationList.isNotEmpty)
          _buildGlassCard(
            title: 'Integration',
            icon: Icons.spa,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: integrationList
                  .map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.white70, fontSize: 18)),
                          Expanded(
                            child: Text(
                              step,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (affirmation != null) ...[
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                  ),
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
                      affirmation.toString(),
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

  Widget _buildSuggestedCrystals(Set<String> ownedCrystals) {
    if (_suggestedCrystals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested Support Crystals',
          style: GoogleFonts.cinzel(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _suggestedCrystals.map((name) {
            final isOwned = ownedCrystals.contains(name.toLowerCase());
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isOwned ? Colors.greenAccent : Colors.white24),
                color: Colors.white.withOpacity(0.08),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  if (isOwned) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final chakra = selectedChakra;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: chakra == null
                ? null
                : () => _generateLayout(targetChakras: [chakra]),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Focus on this chakra'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B59B6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _generateLayout(),
            icon: const Icon(Icons.all_inclusive, color: Colors.white70),
            label: const Text('Full alignment', style: TextStyle(color: Colors.white70)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
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
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.purpleAccent),
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
}

class EnergyParticlesPainter extends CustomPainter {
  EnergyParticlesPainter({required this.animationValue});

  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = math.min(centerX, centerY) * 0.9;

    for (var i = 0; i < 7; i++) {
      final radius = maxRadius * ((i + animationValue) / 7);
      final opacity = (1 - (i / 7)).clamp(0.1, 0.6);

      final radialPaint = Paint()
        ..color = Colors.purpleAccent.withOpacity(opacity)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(Offset(centerX, centerY), radius, radialPaint);
    }

    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 60; i++) {
      final angle = (i / 60) * math.pi * 2;
      final radius = maxRadius * 0.7 * (0.4 + animationValue * 0.6);
      final x = centerX + radius * math.cos(angle + animationValue * math.pi * 2);
      final y = centerY + radius * math.sin(angle + animationValue * math.pi * 2);
      canvas.drawCircle(Offset(x, y), 2, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
