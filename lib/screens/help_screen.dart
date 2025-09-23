import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/environment_config.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/holographic_button.dart';
import '../widgets/no_particles.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static final List<_HelpTopic> _topics = [
    _HelpTopic(
      title: 'Crystal Identification',
      icon: Icons.camera_alt,
      steps: const [
        'From the Home screen, tap the “Crystal ID” card.',
        'Capture a clear photo of the crystal or upload one from your gallery.',
        'Review the AI results and save the crystal to your collection.',
      ],
      tips: const [
        'Ensure the crystal is well lit and fills most of the frame.',
        'Wipe the lens to avoid foggy captures.',
      ],
    ),
    _HelpTopic(
      title: 'Moon Rituals & Guidance',
      icon: Icons.nightlight_round,
      steps: const [
        'Open the Moon Rituals experience from the Home grid.',
        'Select your current intention or allow the app to recommend one.',
        'Follow the ritual steps and journal prompts offered by the AI guide.',
      ],
      tips: const [
        'Enable push notifications to receive phase reminders.',
        'Use the ritual summary to add notes to your collection afterwards.',
      ],
    ),
    _HelpTopic(
      title: 'Dream Journal Insights',
      icon: Icons.auto_stories,
      steps: const [
        'Tap “Dream Journal” from the Home grid.',
        'Record your dream and include emotions or crystals used.',
        'Submit to receive an AI-assisted interpretation with crystal suggestions.',
      ],
      tips: const [
        'Try to journal within minutes of waking for the clearest recall.',
        'Tag dreams with themes to surface patterns later.',
      ],
    ),
  ];

  static final List<_FaqItem> _faq = [
    const _FaqItem(
      question: 'How many crystals can I identify each day?',
      answer:
          'Free explorers receive three identifications daily. Upgrade in the Subscription portal for expanded limits and priority AI processing.',
    ),
    const _FaqItem(
      question: 'Can I use the app offline?',
      answer:
          'The Grimoire requires connectivity for crystal identification and guidance. You can view saved collection entries offline once they are cached.',
    ),
    const _FaqItem(
      question: 'How do I earn Seer Credits?',
      answer:
          'Complete onboarding, daily rituals, dream entries, and share guidance cards. Credits unlock extra identifications and premium rituals.',
    ),
    const _FaqItem(
      question: 'Where do I manage my subscription?',
      answer:
          'Visit Settings → Subscriptions. Purchases are handled securely via Stripe, and receipts are emailed instantly.',
    ),
  ];

  Future<void> _launchSupport(BuildContext context) async {
    final config = EnvironmentConfig.instance;
    final uri = config.supportUrl.isNotEmpty
        ? Uri.tryParse(config.supportUrl)
        : Uri(scheme: 'mailto', path: config.supportEmail, queryParameters: {
            'subject': 'Crystal Grimoire Support',
          });

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support channel not configured yet.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open support channel.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Support launch failed: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
            'Help & Ritual Guide',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
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
          const SimpleGradientParticles(particleCount: 7),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              children: [
                GlassmorphicContainer(
                  borderRadius: 28,
                  blur: 22,
                  opacity: 0.12,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: AppTheme.holographicShader,
                        child: const Text(
                          'Master the Grimoire',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Explore tutorials, FAQs, and support resources crafted to keep your crystal practice glowing.',
                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final topic in _topics) ...[
                  _HelpTopicCard(topic: topic),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                GlassmorphicContainer(
                  borderRadius: 26,
                  blur: 20,
                  opacity: 0.12,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline, color: AppTheme.crystalGlow),
                          const SizedBox(width: 12),
                          Text(
                            'Frequently Asked Questions',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._faq.map((faq) => _FaqTile(item: faq)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassmorphicContainer(
                  borderRadius: 26,
                  blur: 18,
                  opacity: 0.12,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: AppTheme.mysticalShader,
                        child: const Text(
                          'Need more assistance?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Reach our support coven for technical help, billing questions, or to share feedback.',
                        style: TextStyle(color: Colors.white.withOpacity(0.75)),
                      ),
                      const SizedBox(height: 16),
                      HolographicButton(
                        text: 'Contact Support',
                        icon: Icons.support_agent,
                        width: double.infinity,
                        onPressed: () => _launchSupport(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTopicCard extends StatelessWidget {
  final _HelpTopic topic;

  const _HelpTopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      borderRadius: 26,
      blur: 20,
      opacity: 0.12,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                child: Icon(topic.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: const TextStyle(
                        color: AppTheme.crystalGlow,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...topic.steps.map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.white70)),
                            Expanded(
                              child: Text(
                                step,
                                style: TextStyle(color: Colors.white.withOpacity(0.8)),
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
          ),
          if (topic.tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Crystalkeeper Tips',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...topic.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: AppTheme.crystalGlow),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(color: Colors.white.withOpacity(0.75)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;

  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      iconColor: AppTheme.crystalGlow,
      collapsedIconColor: Colors.white70,
      title: Text(
        item.question,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: Text(
              item.answer,
              style: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpTopic {
  final String title;
  final IconData icon;
  final List<String> steps;
  final List<String> tips;

  const _HelpTopic({
    required this.title,
    required this.icon,
    required this.steps,
    required this.tips,
  });
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
