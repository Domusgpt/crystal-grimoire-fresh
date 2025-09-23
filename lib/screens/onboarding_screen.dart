import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_state.dart';
import '../services/economy_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/holographic_button.dart';
import '../widgets/no_particles.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  final Set<String> _selectedIntentions = {'Clarity'};
  final Set<String> _selectedChakras = {'Third Eye'};
  String _experienceLevel = 'Seeker';
  String? _sunSign;
  String? _moonSign;
  String? _risingSign;
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  final TextEditingController _birthPlaceController = TextEditingController();

  final List<String> _intentionOptions = const [
    'Clarity',
    'Protection',
    'Love',
    'Abundance',
    'Healing',
    'Creativity',
    'Grounding',
    'Intuition',
  ];

  final List<String> _chakraOptions = const [
    'Root',
    'Sacral',
    'Solar Plexus',
    'Heart',
    'Throat',
    'Third Eye',
    'Crown',
  ];

  final List<String> _experienceLevels = const [
    'Seeker',
    'Apprentice',
    'Adept',
    'Luminary',
  ];

  final List<String> _zodiacSigns = const [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _birthPlaceController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select birth date',
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _pickBirthTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _birthTime ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Select birth time',
    );

    if (picked != null) {
      setState(() {
        _birthTime = picked;
      });
    }
  }

  void _goToPage(int index) {
    setState(() {
      _currentPage = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    setState(() {
      _isCompleting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final appState = context.read<AppState>();
      final intentions = _selectedIntentions.toList();
      final chakras = _selectedChakras.toList();

      final onboardingPayload = {
        'completedAt': FieldValue.serverTimestamp(),
        'intentions': intentions,
        'chakraFocus': chakras,
        'experienceLevel': _experienceLevel,
        'birthLocation': _birthPlaceController.text.trim().isEmpty
            ? null
            : _birthPlaceController.text.trim(),
        'birthDate': _birthDate?.toIso8601String(),
        'birthTime': _birthTime == null
            ? null
            : '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}',
        'zodiacProfile': {
          'sun': _sunSign,
          'moon': _moonSign,
          'rising': _risingSign,
        },
      };

      if (user != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userRef.set({
          'onboarding': onboardingPayload,
          'profile': {
            'intentions': intentions,
            'focusChakras': chakras,
            'experienceLevel': _experienceLevel,
            'zodiacProfile': {
              'sun': _sunSign,
              'moon': _moonSign,
              'rising': _risingSign,
            },
          },
        }, SetOptions(merge: true));

        await userRef.collection('activity').doc('welcome').set({
          'type': 'onboarding_complete',
          'timestamp': FieldValue.serverTimestamp(),
          'intentions': intentions,
          'chakraFocus': chakras,
        }, SetOptions(merge: true));
      }

      await appState.completeOnboarding();

      final economyService = context.read<EconomyService>();
      final uid = user?.uid;
      if (uid != null) {
        await economyService.initializeForUser(uid);
        await economyService.earnCredits(
          userId: uid,
          action: 'onboarding_complete',
          metadata: {
            'intentionsCount': intentions.length,
            'experienceLevel': _experienceLevel,
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Welcome! Your crystal path is set.'),
          backgroundColor: AppTheme.amethystPurple,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Onboarding failed: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  Widget _buildChoiceGrid({
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) => onToggle(option),
          selectedColor: AppTheme.amethystPurple.withOpacity(0.4),
          backgroundColor: Colors.white.withOpacity(0.1),
          labelStyle: TextStyle(
            color: isSelected ? AppTheme.crystalGlow : Colors.white,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: isActive ? 24 : 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [AppTheme.holoPink, AppTheme.holoBlue],
                  )
                : null,
            color: isActive
                ? null
                : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

  Widget _buildNavigation() {
    final isLastPage = _currentPage == 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () => _goToPage(_currentPage - 1),
              child: const Text(
                'Back',
                style: TextStyle(color: AppTheme.crystalGlow),
              ),
            )
          else
            TextButton(
              onPressed: () => context.read<AppState>().completeOnboarding(),
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          const Spacer(),
          if (isLastPage)
            HolographicButton(
              text: _isCompleting ? 'Blessing...' : 'Enter the Grimoire',
              onPressed: _isCompleting ? () {} : _completeOnboarding,
              width: 220,
              height: 54,
              icon: Icons.auto_awesome,
            )
          else
            HolographicButton(
              text: 'Next',
              onPressed: () => _goToPage(_currentPage + 1),
              width: 160,
              height: 54,
              icon: Icons.arrow_forward,
            ),
        ],
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
        title: ShaderMask(
          shaderCallback: AppTheme.mysticalShader,
          child: const Text(
            'Crystal Initiation',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.read<AppState>().completeOnboarding(),
            child: const Text('Skip', style: TextStyle(color: Colors.white70)),
          )
        ],
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
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildPageIndicator(),
                const SizedBox(height: 16),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      _buildWelcomeStep(),
                      _buildIntentionsStep(),
                      _buildAlignmentStep(),
                      _buildSummaryStep(),
                    ],
                  ),
                ),
                _buildNavigation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GlassmorphicContainer(
        borderRadius: 30,
        blur: 25,
        opacity: 0.12,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: AppTheme.holographicShader,
              child: const Text(
                'Welcome, Seeker',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Let’s attune the Crystal Grimoire to your energy signature. Share a bit about your journey so far and we’ll craft a personalized path for you.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _buildIllustratedHighlight(
              icon: Icons.auto_fix_high,
              title: 'Personalized Rituals',
              description: 'Curated moon rituals aligned with your intentions and crystal allies.',
            ),
            const SizedBox(height: 16),
            _buildIllustratedHighlight(
              icon: Icons.self_improvement,
              title: 'Healing Layouts',
              description: 'Step-by-step crystal placements tailored to your chakric focus.',
            ),
            const SizedBox(height: 16),
            _buildIllustratedHighlight(
              icon: Icons.library_books,
              title: 'Crystal Wisdom',
              description: 'Instant access to metaphysical insights for every stone you meet.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIllustratedHighlight({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.amethystPurple, AppTheme.mysticPink],
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.crystalGlow,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntentionsStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GlassmorphicContainer(
        borderRadius: 30,
        blur: 25,
        opacity: 0.12,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: AppTheme.holographicShader,
              child: const Text(
                'Set Your Intentions',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose the energies you’d like to cultivate. These guide our recommendations and rituals.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _buildChoiceGrid(
              options: _intentionOptions,
              selected: _selectedIntentions,
              onToggle: (value) {
                setState(() {
                  if (_selectedIntentions.contains(value) && _selectedIntentions.length > 1) {
                    _selectedIntentions.remove(value);
                  } else {
                    _selectedIntentions.add(value);
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: AppTheme.mysticalShader,
              child: const Text(
                'Experience Level',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _experienceLevel,
              dropdownColor: const Color(0xFF1C1235),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              items: _experienceLevels
                  .map((level) => DropdownMenuItem(
                        value: level,
                        child: Text(level),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _experienceLevel = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlignmentStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GlassmorphicContainer(
        borderRadius: 30,
        blur: 25,
        opacity: 0.12,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: AppTheme.holographicShader,
                child: const Text(
                  'Energy Alignment',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select chakras you’re focusing on and share optional birth data for deeper astro guidance.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _buildChoiceGrid(
                options: _chakraOptions,
                selected: _selectedChakras,
                onToggle: (value) {
                  setState(() {
                    if (_selectedChakras.contains(value) && _selectedChakras.length > 1) {
                      _selectedChakras.remove(value);
                    } else {
                      _selectedChakras.add(value);
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: AppTheme.mysticalShader,
                child: const Text(
                  'Birth Chart (optional)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildBirthField(
                    label: _birthDate == null
                        ? 'Birth Date'
                        : 'Birth Date: ${_birthDate!.toLocal().toString().split(' ').first}',
                    icon: Icons.calendar_today,
                    onTap: _pickBirthDate,
                  ),
                  _buildBirthField(
                    label: _birthTime == null
                        ? 'Birth Time'
                        : 'Birth Time: ${_birthTime!.format(context)}',
                    icon: Icons.schedule,
                    onTap: _pickBirthTime,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthPlaceController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Birth Location',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildSignDropdown('Sun Sign', _sunSign, (value) => setState(() => _sunSign = value))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSignDropdown('Moon Sign', _moonSign, (value) => setState(() => _moonSign = value))),
                ],
              ),
              const SizedBox(height: 12),
              _buildSignDropdown('Rising Sign', _risingSign, (value) => setState(() => _risingSign = value)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthField({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.crystalGlow),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignDropdown(
    String label,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1C1235),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      hint: const Text('Optional', style: TextStyle(color: Colors.white54)),
      items: _zodiacSigns
          .map(
            (sign) => DropdownMenuItem(
              value: sign,
              child: Text(sign),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSummaryStep() {
    final intentions = _selectedIntentions.join(', ');
    final chakras = _selectedChakras.join(', ');
    final zodiac = [
      if (_sunSign != null) '☀️ Sun: $_sunSign',
      if (_moonSign != null) '🌙 Moon: $_moonSign',
      if (_risingSign != null) '↗️ Rising: $_risingSign',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GlassmorphicContainer(
        borderRadius: 30,
        blur: 25,
        opacity: 0.12,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: AppTheme.holographicShader,
              child: const Text(
                'Ready to Begin',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Here’s a glimpse of how we’ll tailor your experience. You can update these anytime from your profile.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _buildSummaryTile(
              title: 'Intentions',
              details: intentions,
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 12),
            _buildSummaryTile(
              title: 'Chakra Focus',
              details: chakras,
              icon: Icons.bubble_chart,
            ),
            const SizedBox(height: 12),
            _buildSummaryTile(
              title: 'Experience',
              details: _experienceLevel,
              icon: Icons.school,
            ),
            if (zodiac.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSummaryTile(
                title: 'Astro Alignment',
                details: zodiac.join('\n'),
                icon: Icons.nights_stay,
              ),
            ],
            const Spacer(),
            Text(
              'Completing onboarding unlocks Seer Credits and personalized rituals aligned to your energy signature.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTile({
    required String title,
    required String details,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.holoPink, AppTheme.holoBlue],
              ),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.crystalGlow,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  details,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
