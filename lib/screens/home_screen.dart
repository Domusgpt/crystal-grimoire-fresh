import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/crystal.dart' as collection_models;
import '../services/auth_service.dart';
import '../services/collection_service_v2.dart';
import '../services/crystal_service.dart';
import '../widgets/common/mystical_button.dart';
import '../widgets/glassmorphic_container.dart';
import "../widgets/no_particles.dart";
import '../widgets/holographic_button.dart';
import 'crystal_identification_screen.dart';
import 'collection_screen.dart';
import 'moon_rituals_screen.dart';
import 'crystal_healing_screen.dart';
import 'dream_journal_screen.dart';
import 'sound_bath_screen.dart';
import 'marketplace_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'help_screen.dart';
import 'crystal_compatibility_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _dailyCrystal;
  bool _isLoading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDailyCrystal();
  }

  Future<void> _loadUserData() async {
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated && AuthService.currentUser != null) {
      setState(() {
        _userName = AuthService.currentUser!.displayName ?? 'Crystal Seeker';
      });
    }
  }

  Future<void> _loadDailyCrystal() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final crystalService = context.read<CrystalService>();
      final crystalData = await crystalService.getDailyCrystal();

      setState(() {
        _dailyCrystal = crystalData ?? {
          'name': 'Amethyst',
          'description': 'A powerful crystal for spiritual growth, protection, and clarity. Amethyst enhances intuition and promotes peaceful energy.',
          'properties': ['Spiritual Growth', 'Protection', 'Clarity', 'Peace']
        };
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to a real crystal instead of placeholder
      setState(() {
        _dailyCrystal = {
          'name': 'Clear Quartz',
          'description': 'The master healer crystal that amplifies energy and intentions. Known as the most versatile healing stone.',
          'properties': ['Amplification', 'Healing', 'Clarity', 'Energy']
        };
        _isLoading = false;
      });
    }
  }

  bool get _hasDailyCrystal => !_isLoading && _dailyCrystal != null;

  bool _isCrystalInCollection(
    String name, {
    CollectionServiceV2? service,
  }) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    final collection = (service ?? context.read<CollectionServiceV2>()).collection;
    return collection.any(
      (entry) => entry.crystal.name.trim().toLowerCase() == normalized,
    );
  }

  void _openDailyCrystalDetail() {
    if (!_hasDailyCrystal) {
      return;
    }

    final data = Map<String, dynamic>.from(_dailyCrystal!);
    final collectionService = context.read<CollectionServiceV2>();
    final crystalService = context.read<CrystalService>();
    final alreadySaved = _isCrystalInCollection(
      data['name']?.toString() ?? '',
      service: collectionService,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _DailyCrystalDetailSheet(
          dailyCrystal: data,
          collectionService: collectionService,
          crystalService: crystalService,
          alreadyInCollection: alreadySaved,
          onSaved: () {
            if (!mounted) return;
            setState(() {});
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: AppTheme.mysticalShader,
          child: const Text(
            '✨ Crystal Grimoire ✨',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppTheme.crystalGlow),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.crystalGlow),
            tooltip: 'Help & Tutorials',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppTheme.crystalGlow),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AccountScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
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
          
          // Floating crystals
          const SimpleGradientParticles(particleCount: 5),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Crystal of the Day
                  _buildCrystalOfTheDay(),
                  
                  const SizedBox(height: 30),
                  
                  // Feature Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: [
                      _buildFeatureCard(
                        title: 'Crystal ID',
                        icon: Icons.camera_alt,
                        gradientColors: [AppTheme.amethystPurple, AppTheme.cosmicPurple],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CrystalIdentificationScreen()),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'Collection',
                        icon: Icons.diamond,
                        gradientColors: [AppTheme.blueViolet, AppTheme.mysticPink],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CollectionScreen()),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'Moon Rituals',
                        icon: Icons.nightlight_round,
                        gradientColors: [AppTheme.mysticPink, AppTheme.plum],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => MoonRitualScreen()),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'Crystal Healing',
                        icon: Icons.healing,
                        gradientColors: [AppTheme.cosmicPurple, AppTheme.holoBlue],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CrystalHealingScreen()),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'Compatibility',
                        icon: Icons.auto_awesome,
                        gradientColors: [AppTheme.holoPink, AppTheme.holoBlue],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CrystalCompatibilityScreen()),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'Dream Journal',
                        icon: Icons.auto_stories,
                        gradientColors: [AppTheme.holoPink, AppTheme.amethystPurple],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => JournalScreen()),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'Sound Bath',
                        icon: Icons.music_note,
                        gradientColors: [AppTheme.holoBlue, AppTheme.holoYellow],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SoundBathScreen()),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Marketplace Button
                  HolographicButton(
                    text: '🛍️ Crystal Marketplace',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MarketplaceScreen()),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCrystalOfTheDay() {
    final collectionService = context.watch<CollectionServiceV2>();
    final data = _dailyCrystal;
    final hasData = _hasDailyCrystal && data != null;

    final name = hasData ? data['name']?.toString() ?? 'Mystery Crystal' : 'Crystal of the Day';
    final description = hasData
        ? data['description']?.toString() ??
            'The master healer crystal that amplifies energy and intentions.'
        : 'Discovering your daily crystal...';
    final properties = hasData ? _normalizeStringList(data['properties']) : const <String>[];
    final keywords = hasData ? _normalizeStringList(data['keywords']) : const <String>[];
    final selectionCriteria = hasData && data['selectionCriteria'] is Map
        ? Map<String, dynamic>.from(data['selectionCriteria'] as Map)
        : const <String, dynamic>{};
    final moonPhase = hasData && data['moonPhase'] is Map
        ? Map<String, dynamic>.from(data['moonPhase'] as Map)
        : null;
    final highlight = hasData && data['highlight'] == true;
    final recommendedIntents = hasData && data['ritualSuggestion'] is Map
        ? _normalizeStringList((data['ritualSuggestion'] as Map)['recommendedIntents'])
        : const <String>[];
    final alreadySaved = hasData
        ? _isCrystalInCollection(name, service: collectionService)
        : false;

    final selectionChips = selectionCriteria.entries
        .map((entry) {
          final value = entry.value?.toString().trim();
          if (value == null || value.isEmpty) {
            return null;
          }
          return _buildInfoChip('${_formatCriteriaLabel(entry.key)}: $value');
        })
        .whereType<Widget>()
        .toList();

    return GestureDetector(
      onTap: hasData ? _openDailyCrystalDetail : null,
      child: GlassmorphicContainer(
        borderRadius: 25,
        blur: 20,
        opacity: 0.12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: AppTheme.holographicShader,
                      child: const Text(
                        '🔮 Crystal of the Day',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MysticalIconButton(
                    icon: Icons.refresh,
                    color: AppTheme.crystalGlow,
                    tooltip: 'Refresh daily crystal',
                    onPressed: () {
                      if (_isLoading) return;
                      _loadDailyCrystal();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      AppTheme.amethystPurple,
                      AppTheme.cosmicPurple,
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.amethystPurple.withOpacity(0.28),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(30),
                          child: CircularProgressIndicator(
                            color: AppTheme.crystalGlow,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(
                          Icons.diamond,
                          size: 80,
                          color: Colors.white,
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasData ? name : 'Finding guidance...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.crystalGlow,
                ),
              ),
              if (moonPhase != null || highlight || alreadySaved) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (moonPhase != null)
                      _buildInfoChip(
                        '${moonPhase['emoji'] ?? '🌙'} ${moonPhase['phase'] ?? ''}',
                        icon: Icons.nightlight_round,
                      ),
                    if (moonPhase != null && moonPhase['illumination'] != null)
                      _buildInfoChip(
                        'Illumination ${moonPhase['illumination']}%',
                        icon: Icons.brightness_3,
                      ),
                    if (highlight)
                      _buildInfoChip(
                        'Featured crystal',
                        icon: Icons.auto_awesome,
                        accent: Colors.amberAccent,
                      ),
                    if (alreadySaved)
                      _buildInfoChip(
                        'In your collection',
                        icon: Icons.check_circle,
                        accent: Colors.lightGreenAccent,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.82),
                  height: 1.45,
                ),
              ),
              if (selectionChips.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: selectionChips,
                ),
              ],
              if (properties.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: properties
                      .map((property) => _buildInfoChip(property, accent: AppTheme.cosmicPurple))
                      .toList(),
                ),
              ],
              if (keywords.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: keywords
                      .map((keyword) => _buildInfoChip('#$keyword', accent: AppTheme.holoBlue))
                      .toList(),
                ),
              ],
              if (recommendedIntents.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: recommendedIntents
                      .map((intent) => _buildInfoChip('Focus: $intent', accent: AppTheme.holoPink))
                      .toList(),
                ),
              ],
              if (hasData) ...[
                const SizedBox(height: 18),
                MysticalButton(
                  text: alreadySaved ? 'View guidance' : 'View guidance & care',
                  icon: Icons.menu_book,
                  onPressed: _openDailyCrystalDetail,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    String label, {
    IconData? icon,
    Color? accent,
  }) {
    final color = accent ?? AppTheme.crystalGlow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withOpacity(0.16),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassmorphicContainer(
        borderRadius: 20,
        blur: 15,
        opacity: 0.1,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientColors[0].withOpacity(0.2),
            gradientColors[1].withOpacity(0.1),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 35,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.crystalGlow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyCrystalDetailSheet extends StatefulWidget {
  final Map<String, dynamic> dailyCrystal;
  final CollectionServiceV2 collectionService;
  final CrystalService crystalService;
  final bool alreadyInCollection;
  final VoidCallback onSaved;

  const _DailyCrystalDetailSheet({
    required this.dailyCrystal,
    required this.collectionService,
    required this.crystalService,
    required this.alreadyInCollection,
    required this.onSaved,
  });

  @override
  State<_DailyCrystalDetailSheet> createState() => _DailyCrystalDetailSheetState();
}

class _DailyCrystalDetailSheetState extends State<_DailyCrystalDetailSheet> {
  final DateFormat _dateFormat = DateFormat.yMMMMd();
  late bool _inCollection;
  bool _isSaving = false;
  bool _isLoadingCare = false;
  String? _error;
  Map<String, dynamic>? _carePayload;
  Map<String, List<String>> _careSections = const {};
  List<String> _recommendedCompanions = const [];

  @override
  void initState() {
    super.initState();
    _inCollection = widget.alreadyInCollection;
    _hydrateInitialCare();
  }

  void _hydrateInitialCare() {
    final initialCare = widget.dailyCrystal['careInstructions'];
    _careSections = _normalizeCareSections(initialCare);
    _recommendedCompanions = _extractCompanionNames(initialCare);
    if (initialCare is Map<String, dynamic>) {
      _carePayload = Map<String, dynamic>.from(initialCare);
    }
  }

  Future<void> _handleFetchCare() async {
    final name = widget.dailyCrystal['name']?.toString() ?? '';
    if (name.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingCare = true;
      _error = null;
    });

    try {
      final response = await widget.crystalService.getCareInstructions(name);
      if (!mounted) return;

      if (response == null) {
        setState(() {
          _error = 'Unable to load care guidance right now. Please try again later.';
          _isLoadingCare = false;
        });
        return;
      }

      final sections = _normalizeCareSections(response);
      final companions = _extractCompanionNames(response);

      setState(() {
        _careSections = sections;
        _recommendedCompanions = companions;
        _carePayload = Map<String, dynamic>.from(response);
        _isLoadingCare = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Care guidance failed: $error';
        _isLoadingCare = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_inCollection || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final crystal = _buildCrystalFromDaily(
        widget.dailyCrystal,
        _careSections,
        _recommendedCompanions,
      );

      final customProperties = <String, dynamic>{
        'source': 'daily_crystal',
        if (widget.dailyCrystal['date'] != null) 'date': widget.dailyCrystal['date'],
        if (widget.dailyCrystal['dayOfYear'] != null) 'dayOfYear': widget.dailyCrystal['dayOfYear'],
      };

      final selection = widget.dailyCrystal['selectionCriteria'];
      if (selection is Map<String, dynamic>) {
        customProperties['selectionCriteria'] = selection;
      }

      final moonPhase = widget.dailyCrystal['moonPhase'];
      if (moonPhase is Map<String, dynamic>) {
        customProperties['moonPhase'] = moonPhase;
      }

      final ritualSuggestion = widget.dailyCrystal['ritualSuggestion'];
      if (ritualSuggestion is Map<String, dynamic>) {
        customProperties['ritualSuggestion'] = ritualSuggestion;
      }

      if (_carePayload != null) {
        customProperties['carePayload'] = _carePayload;
      }

      if (_recommendedCompanions.isNotEmpty) {
        customProperties['recommendedCompanions'] = _recommendedCompanions;
      }

      customProperties.removeWhere((_, value) => value == null);

      final primaryUses = _normalizeStringList(
        (ritualSuggestion is Map<String, dynamic>)
            ? ritualSuggestion['recommendedIntents']
            : widget.dailyCrystal['properties'],
      );

      await widget.collectionService.addCrystal(
        crystal,
        primaryUses: primaryUses,
        customProperties: customProperties,
      );

      if (!mounted) return;

      widget.onSaved();
      setState(() {
        _inCollection = true;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.dailyCrystal['name'] ?? 'Crystal'} added to your collection.'),
          backgroundColor: AppTheme.amethystPurple,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Unable to save crystal: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save crystal: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.dailyCrystal;
    final selectionCriteria = data['selectionCriteria'] is Map
        ? Map<String, dynamic>.from(data['selectionCriteria'] as Map)
        : const <String, dynamic>{};
    final moonPhase = data['moonPhase'] is Map
        ? Map<String, dynamic>.from(data['moonPhase'] as Map)
        : null;
    final properties = _normalizeStringList(data['properties']);
    final keywords = _normalizeStringList(data['keywords']);
    final ritualSuggestion = data['ritualSuggestion'] is Map
        ? Map<String, dynamic>.from(data['ritualSuggestion'] as Map)
        : const <String, dynamic>{};
    final recommendedIntents = _normalizeStringList(ritualSuggestion['recommendedIntents']);
    final affirmation = ritualSuggestion['affirmation']?.toString();
    final focus = ritualSuggestion['focus']?.toString();
    final energy = ritualSuggestion['energy']?.toString();

    final dateValue = data['date'];
    DateTime? guidanceDate;
    if (dateValue is String) {
      guidanceDate = DateTime.tryParse(dateValue);
    }

    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, viewInsets.bottom + 16),
      child: GlassmorphicContainer(
        borderRadius: 28,
        blur: 30,
        opacity: 0.16,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['name']?.toString() ?? 'Crystal of the Day',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (guidanceDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Guidance for ${_dateFormat.format(guidanceDate.toLocal())}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  data['description']?.toString() ??
                      'The master healer crystal that amplifies energy and intentions.',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.45),
                ),
                if (moonPhase != null) ...[
                  const SizedBox(height: 16),
                  _buildMoonPhaseCard(moonPhase),
                ],
                if (selectionCriteria.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Selected for you',
                    style: TextStyle(
                      color: AppTheme.crystalGlow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: selectionCriteria.entries
                        .map((entry) {
                          final value = entry.value?.toString().trim();
                          if (value == null || value.isEmpty) {
                            return null;
                          }
                          return _buildMiniChip('${_formatCriteriaLabel(entry.key)} • $value');
                        })
                        .whereType<Widget>()
                        .toList(),
                  ),
                ],
                if (properties.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Key properties',
                    style: TextStyle(
                      color: AppTheme.cosmicPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: properties.map(_buildMiniChip).toList(),
                  ),
                ],
                if (keywords.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Keywords',
                    style: TextStyle(
                      color: AppTheme.holoBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: keywords.map((kw) => _buildMiniChip('#$kw')).toList(),
                  ),
                ],
                if (focus != null || energy != null || recommendedIntents.isNotEmpty || affirmation != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Ritual focus',
                    style: TextStyle(
                      color: AppTheme.holoPink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (focus != null)
                    _buildBulletRow('Focus', focus),
                  if (energy != null)
                    _buildBulletRow('Energy', energy),
                  if (recommendedIntents.isNotEmpty)
                    _buildBulletRow(
                      'Recommended intents',
                      recommendedIntents.join(', '),
                    ),
                  if (affirmation != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.holoPink.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.holoPink.withOpacity(0.4)),
                      ),
                      child: Text(
                        'Affirmation — $affirmation',
                        style: const TextStyle(
                          color: AppTheme.holoPink,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                Text(
                  'Care guidance',
                  style: TextStyle(
                    color: AppTheme.crystalGlow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoadingCare) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      CircularProgressIndicator(color: AppTheme.crystalGlow, strokeWidth: 2.5),
                      SizedBox(width: 12),
                      Text('Refreshing guidance...', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ] else ...[
                  _buildCareSection('Cleansing', _careSections['cleansing'] ?? const []),
                  _buildCareSection('Charging', _careSections['charging'] ?? const []),
                  _buildCareSection('Storage', _careSections['storage'] ?? const []),
                  _buildCareSection('Usage', _careSections['usage'] ?? const []),
                  _buildCautions(_careSections['cautions'] ?? const []),
                  if (_recommendedCompanions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Companion crystals',
                      style: TextStyle(
                        color: AppTheme.holoBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _recommendedCompanions
                          .map((name) => _buildMiniChip(name))
                          .toList(),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 22),
                if (_inCollection) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withOpacity(0.08),
                      border: Border.all(color: AppTheme.crystalGlow.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle, color: AppTheme.crystalGlow),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This crystal is already saved in your collection.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  if (_isSaving) ...[
                    Row(
                      children: const [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppTheme.crystalGlow,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Saving to your collection...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ] else ...[
                    MysticalButton(
                      text: 'Save to collection',
                      icon: Icons.save_alt,
                      onPressed: _handleSave,
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                MysticalButton(
                  text: 'Refresh care guidance',
                  icon: Icons.auto_fix_high,
                  onPressed: _handleFetchCare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoonPhaseCard(Map<String, dynamic> moonPhase) {
    final phase = moonPhase['phase']?.toString() ?? 'Moon phase';
    final emoji = moonPhase['emoji']?.toString() ?? '🌙';
    final illumination = moonPhase['illumination']?.toString();
    final timestamp = _coerceDate(moonPhase['timestamp']);
    final nextFull = _coerceDate(moonPhase['nextFullMoon']);
    final nextNew = _coerceDate(moonPhase['nextNewMoon']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.crystalGlow.withOpacity(0.4)),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$emoji $phase',
                style: const TextStyle(
                  color: AppTheme.crystalGlow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (illumination != null)
                Text(
                  'Illumination $illumination%',
                  style: TextStyle(color: Colors.white.withOpacity(0.75)),
                ),
            ],
          ),
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Current cycle • ${_dateFormat.format(timestamp.toLocal())}',
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
              ),
            ),
          if (nextFull != null || nextNew != null) ...[
            const SizedBox(height: 8),
            if (nextFull != null)
              _buildBulletRow('Next full moon', _dateFormat.format(nextFull.toLocal())),
            if (nextNew != null)
              _buildBulletRow('Next new moon', _dateFormat.format(nextNew.toLocal())),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBulletRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white70)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.35),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareSection(String title, List<String> values) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• $value',
                style: TextStyle(color: Colors.white.withOpacity(0.78), height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCautions(List<String> cautions) {
    if (cautions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cautions',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...cautions.map(
              (value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $value',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _coerceDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

List<String> _normalizeStringList(dynamic source) {
  final results = LinkedHashSet<String>();

  void addValue(dynamic value) {
    if (value == null) {
      return;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        results.add(trimmed);
      }
    } else if (value is Iterable) {
      for (final item in value) {
        addValue(item);
      }
    } else if (value is Map) {
      for (final entry in value.entries) {
        addValue(entry.value);
      }
    } else {
      addValue(value.toString());
    }
  }

  addValue(source);
  return results.toList();
}

Map<String, List<String>> _normalizeCareSections(dynamic source) {
  final sections = <String, List<String>>{
    'cleansing': const [],
    'charging': const [],
    'storage': const [],
    'usage': const [],
    'cautions': const [],
  };

  if (source is Map) {
    final map = Map<String, dynamic>.from(source);
    final care = map['care'];
    if (care is Map) {
      map.addAll(care.cast<String, dynamic>());
    }

    sections['cleansing'] = _normalizeStringList(map['cleansing'] ?? map['cleanse']);
    sections['charging'] = _normalizeStringList(map['charging']);
    sections['storage'] = _normalizeStringList(map['storage']);
    sections['usage'] = _normalizeStringList(map['usage']);
    sections['cautions'] = _normalizeStringList(map['cautions']);
  }

  return sections;
}

String _formatCriteriaLabel(String raw) {
  final normalized = raw.toLowerCase();
  switch (normalized) {
    case 'intent':
    case 'intention':
      return 'Intent';
    case 'chakra':
    case 'focuschakra':
    case 'focus_chakra':
      return 'Chakra';
    case 'mood':
    case 'emotion':
      return 'Mood';
    default:
      final cleaned = raw.replaceAll(RegExp(r'[_-]'), ' ').trim();
      if (cleaned.isEmpty) {
        return 'Focus';
      }
      return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

List<String> _extractCompanionNames(dynamic source) {
  final results = <String>[];
  if (source is Map) {
    final map = Map<String, dynamic>.from(source);
    final care = map['care'];
    if (care is Map) {
      map.addAll(care.cast<String, dynamic>());
    }
    final companions = map['recommendedCompanions'];
    if (companions is Iterable) {
      for (final companion in companions) {
        if (companion is Map && companion['name'] != null) {
          results.add(companion['name'].toString());
        } else if (companion != null) {
          results.add(companion.toString());
        }
      }
    }
  }
  return results;
}

String _formatCareSummary(Map<String, List<String>> sections) {
  final buffer = StringBuffer();

  void append(String label, String key) {
    final values = sections[key];
    if (values == null || values.isEmpty) {
      return;
    }
    if (buffer.isNotEmpty) {
      buffer.writeln();
    }
    buffer.writeln('$label: ${values.join(', ')}');
  }

  append('Cleansing', 'cleansing');
  append('Charging', 'charging');
  append('Storage', 'storage');
  append('Usage', 'usage');
  append('Cautions', 'cautions');

  if (buffer.isEmpty) {
    return 'Handle with care and cleanse regularly.';
  }
  return buffer.toString();
}

collection_models.Crystal _buildCrystalFromDaily(
  Map<String, dynamic> data,
  Map<String, List<String>> careSections,
  List<String> recommendedCompanions,
) {
  final meta = data['metaphysicalProperties'] is Map
      ? Map<String, dynamic>.from(data['metaphysicalProperties'] as Map)
      : const <String, dynamic>{};
  final physical = data['physicalProperties'] is Map
      ? Map<String, dynamic>.from(data['physicalProperties'] as Map)
      : const <String, dynamic>{};
  final imageUrl = data['imageUrl']?.toString() ?? '';
  final careSummary = _formatCareSummary(careSections);
  final keywords = _normalizeStringList(data['keywords']);
  final recommendedIntents = _normalizeStringList(
    (data['ritualSuggestion'] is Map)
        ? (data['ritualSuggestion'] as Map)['recommendedIntents']
        : null,
  );

  final metaList = [
    ..._normalizeStringList(data['properties']),
    ..._normalizeStringList(meta['affirmations']),
    ..._normalizeStringList(meta['healing_properties']),
  ];

  final healing = _normalizeStringList(data['healingProperties'])
    ..addAll(_normalizeStringList(meta['healing_properties']));

  final chakras = _normalizeStringList(data['chakras'])
    ..addAll(_normalizeStringList(meta['primary_chakras']));

  final elements = _normalizeStringList(data['elements'])
    ..addAll(_normalizeStringList(meta['elements']));

  final zodiac = _normalizeStringList(data['zodiacSigns'])
    ..addAll(_normalizeStringList(meta['zodiac_signs']));

  final crystal = collection_models.Crystal(
    id: (data['id'] ?? _slugifyName(data['name']?.toString() ?? 'daily-crystal')).toString(),
    name: data['name']?.toString() ?? 'Mystery Crystal',
    scientificName: data['scientificName']?.toString() ?? '',
    group: data['variety']?.toString() ?? data['group']?.toString() ?? 'Unknown',
    description: data['description']?.toString() ?? '',
    metaphysicalProperties: metaList,
    healingProperties: healing,
    chakras: chakras,
    elements: elements,
    properties: physical,
    colorDescription: physical['colorRange']?.toString() ?? '',
    hardness: physical['hardness']?.toString() ?? '',
    formation: physical['crystal_system']?.toString() ?? physical['formation']?.toString() ?? '',
    careInstructions: careSummary,
    identificationDate: DateTime.now(),
    imageUrl: imageUrl,
    imageUrls: imageUrl.isNotEmpty ? [imageUrl] : const <String>[],
    zodiacSigns: zodiac,
    recommendedIntentions: recommendedIntents,
    keywords: keywords,
    bestCombinations: recommendedCompanions,
  );

  return crystal;
}

String _slugifyName(String value) {
  final sanitized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  if (sanitized.isEmpty) {
    return 'crystal-${DateTime.now().millisecondsSinceEpoch}';
  }
  return sanitized;
}
