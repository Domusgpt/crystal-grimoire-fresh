import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_container.dart';
import '../widgets/holographic_button.dart';
import '../widgets/no_particles.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _smsEnabled = false;
  bool _soundEnabled = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    final appState = context.read<AppState>();
    final user = _auth.currentUser;

    setState(() {
      _pushEnabled = appState.notificationsEnabled;
      _soundEnabled = appState.soundEnabled;
    });

    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final channels = Map<String, dynamic>.from(
        doc.data()?['settings']?['notificationChannels'] ?? {},
      );
      setState(() {
        _emailEnabled = channels['email'] ?? false;
        _smsEnabled = channels['sms'] ?? false;
      });
    } catch (error) {
      debugPrint('Failed to load notification channels: $error');
    }
  }

  Future<void> _updatePush(bool value) async {
    final appState = context.read<AppState>();
    setState(() => _pushEnabled = value);
    await appState.updateNotificationSettings(value);
  }

  Future<void> _updateSound(bool value) async {
    final appState = context.read<AppState>();
    setState(() => _soundEnabled = value);
    await appState.updateSoundSettings(value);
  }

  Future<void> _updateChannel(String channel, bool value) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to manage notification preferences.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'settings': {
          'notificationChannels': {
            channel: value,
          },
        },
      }, SetOptions(merge: true));

      setState(() {
        if (channel == 'email') {
          _emailEnabled = value;
        } else if (channel == 'sms') {
          _smsEnabled = value;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update $channel notifications: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final query = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All caught up!'),
            backgroundColor: AppTheme.amethystPurple,
          ),
        );
        return;
      }

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked ${query.size} notifications as read.'),
          backgroundColor: AppTheme.amethystPurple,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to mark notifications read: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: AppTheme.mysticalShader,
          child: const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            color: AppTheme.crystalGlow,
            tooltip: 'Mark all read',
            onPressed: _markAllRead,
          ),
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
                  AppTheme.deepMystical,
                  AppTheme.darkViolet,
                  AppTheme.midnightBlue,
                ],
              ),
            ),
          ),
          const SimpleGradientParticles(particleCount: 8),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  GlassmorphicContainer(
                    borderRadius: 28,
                    blur: 20,
                    opacity: 0.12,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_active, color: AppTheme.crystalGlow),
                            const SizedBox(width: 12),
                            Text(
                              'Channel Preferences',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const Spacer(),
                            if (_isSaving)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose how you want to receive ritual reminders, marketplace updates, and crystal insights.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                        const Divider(height: 24, color: Colors.white24),
                        _buildSwitchTile(
                          title: 'Push notifications',
                          subtitle: 'Real-time alerts on new rituals, moon phases, and seer credit activity.',
                          value: _pushEnabled,
                          onChanged: _updatePush,
                        ),
                        _buildSwitchTile(
                          title: 'Crystal chimes',
                          subtitle: 'Enable sound cues for meditations and reminders.',
                          value: _soundEnabled,
                          onChanged: _updateSound,
                        ),
                        _buildSwitchTile(
                          title: 'Email updates',
                          subtitle: 'Weekly digest with curated rituals and collection highlights.',
                          value: _emailEnabled,
                          onChanged: (value) => _updateChannel('email', value),
                        ),
                        _buildSwitchTile(
                          title: 'SMS reminders',
                          subtitle: 'Moon phase alerts and marketplace offers delivered via text.',
                          value: _smsEnabled,
                          onChanged: (value) => _updateChannel('sms', value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: user == null
                        ? _buildSignInPrompt()
                        : _buildNotificationFeed(user.uid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.crystalGlow,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return GlassmorphicContainer(
      borderRadius: 24,
      blur: 18,
      opacity: 0.12,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_open, color: AppTheme.crystalGlow, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Sign in to view your crystal alerts',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We’ll gather moon phase reminders, dream interpretations, and collection updates for you here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 16),
          HolographicButton(
            text: 'Sign in',
            width: 160,
            onPressed: () => Navigator.pushNamed(context, '/login'),
            icon: Icons.login,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationFeed(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load notifications: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return GlassmorphicContainer(
            borderRadius: 24,
            blur: 18,
            opacity: 0.12,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.nightlight_round, color: AppTheme.crystalGlow, size: 42),
                const SizedBox(height: 12),
                const Text(
                  'No alerts yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crystal rituals, moon phase reminders, and dream insights will appear here once they’re available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final isRead = data['read'] == true;
            final title = data['title']?.toString() ?? 'Crystal Update';
            final body = data['body']?.toString() ?? '';
            final category = data['category']?.toString() ?? 'general';
            final createdAt = data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.tryParse(data['createdAt']?.toString() ?? '');

            return GlassmorphicContainer(
              borderRadius: 22,
              blur: 16,
              opacity: 0.12,
              padding: const EdgeInsets.all(18),
              border: Border.all(
                color: isRead
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.crystalGlow.withOpacity(0.6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _categoryIcon(category),
                        color: isRead ? Colors.white54 : AppTheme.crystalGlow,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!isRead)
                        IconButton(
                          onPressed: () => docs[index].reference.update({
                            'read': true,
                            'readAt': FieldValue.serverTimestamp(),
                          }),
                          icon: const Icon(Icons.check_circle, color: AppTheme.crystalGlow),
                          tooltip: 'Mark as read',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      height: 1.35,
                    ),
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(createdAt),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'ritual':
        return Icons.nightlight_round;
      case 'dream':
        return Icons.auto_stories;
      case 'marketplace':
        return Icons.storefront;
      case 'collection':
        return Icons.diamond;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
