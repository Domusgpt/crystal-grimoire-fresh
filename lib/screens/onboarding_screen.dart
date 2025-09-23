import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
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

  static final List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      title: 'Scan & Identify Crystals',
      description:
          'Use the AI-powered crystal identifier to reveal the name, lineage, and metaphysical properties of every stone you encounter.',
      highlights: const [
        'Instant image recognition powered by Gemini AI',
        'Confidence scores and scientific references',
        'Save discoveries directly to your collection',
      ],
      icon: Icons.center_focus_strong,
    ),
    _OnboardingSlide(
      title: 'Moon Rituals & Healing Layouts',
      description:
          'Sync your practice with lunar phases. Receive guided rituals, chakra layouts, and breathwork calibrated to your intentions.',
      highlights: const [
        'Personalized ceremonies for each moon phase',
        'Chakra-aligned healing spreads with placements',
        'Audio guidance and journaling prompts to integrate',
      ],
      icon: Icons.nightlight_round,
    ),
    _OnboardingSlide(
      title: 'Dream Journal & Marketplace',
      description:
          'Capture dreams, decode symbolism, and trade curated crystals with a trusted community of mystics and healers.',
      highlights: const [
        'AI-assisted dream analysis with crystal pairings',
        'Secure marketplace listings with Stripe checkout',
        'Build a living grimoire tailored to your path',
      ],
      icon: Icons.auto_stories,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
          const SimpleGradientParticles(particleCount: 4),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) => _OnboardingCard(slide: _slides[index]),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPageIndicator(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isCompleting ? null : _handlePrimaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.crystalGlow,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isCompleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Text(
                              _currentPage == _slides.length - 1 ? 'Enter the Grimoire' : 'Next',
                              style: theme.textTheme.labelLarge?.copyWith(color: Colors.black, fontSize: 16),
                            ),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: AppTheme.holographicShader,
            child: Text(
              'Crystal Grimoire',
              style: GoogleFonts.cinzelDecorative(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          if (_currentPage < _slides.length - 1)
            TextButton(
              onPressed: _isCompleting ? null : _completeOnboarding,
              child: const Text(
                'Skip',
                style: TextStyle(color: AppTheme.crystalGlow, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          height: 8,
          width: isActive ? 36 : 12,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.crystalGlow : Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      return;
    }

    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);

    try {
      await StorageService.setOnboardingSeen();
      await context.read<AppState>().completeOnboarding();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/auth-check');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to finish onboarding: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }
}

class _OnboardingSlide {
  final String title;
  final String description;
  final List<String> highlights;
  final IconData icon;

  const _OnboardingSlide({
    required this.title,
    required this.description,
    required this.highlights,
    required this.icon,
  });
}

class _OnboardingCard extends StatelessWidget {
  final _OnboardingSlide slide;

  const _OnboardingCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cosmicPurple.withOpacity(0.2),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      AppTheme.holoBlue,
                      AppTheme.holoPink,
                      AppTheme.holoYellow,
                      AppTheme.holoBlue,
                    ],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.8),
                  ),
                  child: Icon(slide.icon, size: 36, color: AppTheme.crystalGlow),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              slide.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppTheme.crystalGlow,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              slide.description,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            ...slide.highlights.map((highlight) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.crystalGlow, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          highlight,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
