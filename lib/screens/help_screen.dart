import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/environment_config.dart';
import '../theme/app_theme.dart';
import '../widgets/no_particles.dart';
import 'onboarding_screen.dart';

class HelpScreen extends StatelessWidget {
  HelpScreen({super.key});

  final EnvironmentConfig _config = EnvironmentConfig.instance;

  final List<_HelpTutorial> _tutorials = const [
    _HelpTutorial(
      title: 'Crystal Identification Walkthrough',
      description:
          'Learn how to capture crystal photos, review AI confidence scores, and add discoveries to your personal library.',
      steps: [
        'Open the Crystal ID tool and allow camera permissions.',
        'Snap a well-lit photo or upload from your gallery.',
        'Review the Gemini analysis and tap “Add to Collection” to store insights.',
      ],
      icon: Icons.center_focus_strong,
    ),
    _HelpTutorial(
      title: 'Moon Ritual Planner',
      description:
          'Craft a ceremony aligned with the current moon phase, complete with crystals, breathwork, and journaling prompts.',
      steps: [
        'Visit the Moon Rituals screen and sync to the current lunar phase.',
        'Select your intention and preferred crystals from your collection.',
        'Follow the guided steps, breathwork timing, and integration prompts.',
      ],
      icon: Icons.nightlight_round,
    ),
    _HelpTutorial(
      title: 'Dream Journal + AI Analysis',
      description:
          'Capture vivid dreams, receive symbolism guidance, and save recommended crystals for bedside rituals.',
      steps: [
        'Open the Dream Journal after waking and describe the experience.',
        'Optional: set mood, moon phase, and crystals you slept with.',
        'Tap “Analyze” to receive insights, affirmations, and ritual suggestions.',
      ],
      icon: Icons.auto_stories,
    ),
  ];

  final List<_HelpFaq> _faqs = const [
    _HelpFaq(
      question: 'How do I unlock premium crystal features?',
      answer:
          'Visit the Subscription screen from Settings. Premium tiers unlock expanded AI identification limits, advanced healing layouts, and priority support.',
    ),
    _HelpFaq(
      question: 'Can I import an existing crystal spreadsheet?',
      answer:
          'Yes! Use the desktop web app to upload CSV files in Settings → Collection Tools. Each entry should include name, type, and notes.',
    ),
    _HelpFaq(
      question: 'What if the AI misidentifies a crystal?',
      answer:
          'You can edit the identification details before saving or flag the result. Flagged images are reviewed to refine the Gemini prompt library.',
    ),
    _HelpFaq(
      question: 'Do I need an internet connection?',
      answer:
          'Crystal identification, dream analysis, and cloud backups require connectivity. Offline mode still allows browsing your saved collection.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Tutorials')),
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
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              ..._tutorials.map((tutorial) => _TutorialCard(tutorial: tutorial)),
              const SizedBox(height: 32),
              _buildQuickActions(context),
              const SizedBox(height: 32),
              _buildFaqSection(),
              const SizedBox(height: 32),
              _buildSupportSection(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Master the Grimoire',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.crystalGlow,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tutorials, troubleshooting, and deployment tips for keepers of the crystal realm.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick actions',
              style: GoogleFonts.orbitron(
                color: AppTheme.crystalGlow,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.play_circle_outline, color: AppTheme.crystalGlow),
              title: const Text('Watch the onboarding tour again'),
              subtitle: const Text('Revisit the guided walkthrough of every core feature.'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined, color: AppTheme.mysticPink),
              title: const Text('Open the deployment checklist'),
              subtitle: const Text('Review the latest release plan, Firebase setup, and QA tasks.'),
              onTap: () => _openDocs(context, 'docs/RELEASE_PLAN.md'),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent, color: AppTheme.holoBlue),
              title: const Text('Contact support'),
              subtitle: Text(_config.supportEmail),
              onTap: () => _openSupport(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    return Card(
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequently asked questions',
              style: GoogleFonts.orbitron(
                color: AppTheme.crystalGlow,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._faqs.map((faq) => _FaqTile(faq: faq)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need extra help?',
              style: GoogleFonts.orbitron(
                color: AppTheme.crystalGlow,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Our support team can help with deployment blockers, Firebase errors, or advanced AI configurations.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openSupport(context),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email support'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openLink(context, _config.supportUrl),
                  icon: const Icon(Icons.language),
                  label: const Text('Knowledge base'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSupport(BuildContext context) async {
    final email = _config.supportEmail;
    final uri = Uri(scheme: 'mailto', path: email, queryParameters: {'subject': 'Crystal Grimoire Support'});
    await _launch(context, uri);
  }

  Future<void> _openDocs(BuildContext context, String relativePath) async {
    if (_config.websiteUrl.isEmpty) {
      _showSnack(context, 'Documentation is available in the repository at $relativePath.');
      return;
    }
    final base = _config.websiteUrl.endsWith('/')
        ? _config.websiteUrl.substring(0, _config.websiteUrl.length - 1)
        : _config.websiteUrl;
    final url = '$base/$relativePath';
    await _openLink(context, url);
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack(context, 'That resource is not configured yet.');
      return;
    }
    await _launch(context, uri);
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) {
        _showSnack(context, 'Unable to open ${uri.toString()}');
      }
    } catch (error) {
      _showSnack(context, 'Failed to open ${uri.toString()}: $error');
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  final _HelpTutorial tutorial;

  const _TutorialCard({required this.tutorial});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.holoBlue.withOpacity(0.7),
                        AppTheme.holoPink.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Icon(tutorial.icon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    tutorial.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.crystalGlow,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tutorial.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tutorial.steps
                  .asMap()
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${entry.key + 1}. ', style: const TextStyle(color: AppTheme.crystalGlow)),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _HelpFaq faq;

  const _FaqTile({required this.faq});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.white12),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(
              faq.answer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTutorial {
  final String title;
  final String description;
  final List<String> steps;
  final IconData icon;

  const _HelpTutorial({
    required this.title,
    required this.description,
    required this.steps,
    required this.icon,
  });
}

class _HelpFaq {
  final String question;
  final String answer;

  const _HelpFaq({required this.question, required this.answer});
}
