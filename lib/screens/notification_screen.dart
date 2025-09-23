import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../widgets/no_particles.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  User? _currentUser;
  CollectionReference<Map<String, dynamic>>? _notificationCollection;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _notificationCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: _markingAll
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
              onPressed: _markingAll ? null : _markAllAsRead,
            ),
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
                  AppTheme.darkViolet,
                  AppTheme.midnightBlue,
                  AppTheme.deepMystical,
                ],
              ),
            ),
          ),
          const SimpleGradientParticles(particleCount: 5),
          _currentUser == null
              ? _buildAuthRequired()
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _notificationCollection!
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.crystalGlow),
                      );
                    }

                    if (snapshot.hasError) {
                      return _buildError(snapshot.error);
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        return _NotificationCard(
                          document: doc,
                          onToggleRead: (read) => _toggleRead(doc.reference, read),
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildAuthRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              'Sign in to receive moon alerts, ritual reminders, and marketplace updates.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'We could not load your notifications. Please try again shortly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 72, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              'You are all caught up! We will notify you when new crystal insights or moon events arrive.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    if (_notificationCollection == null) return;

    setState(() => _markingAll = true);

    try {
      final snapshot = await _notificationCollection!
          .where('read', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked all notifications as read'),
          backgroundColor: AppTheme.cosmicPurple,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update notifications: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _markingAll = false);
      }
    }
  }

  Future<void> _toggleRead(DocumentReference<Map<String, dynamic>> ref, bool read) async {
    try {
      await ref.set({
        'read': read,
        'readAt': read ? FieldValue.serverTimestamp() : null,
      }, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update notification: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final ValueChanged<bool> onToggleRead;

  const _NotificationCard({required this.document, required this.onToggleRead});

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final title = (data['title'] as String?) ?? 'Crystal Update';
    final body = (data['body'] as String?) ?? 'Tap to learn more about this mystical event.';
    final type = (data['type'] as String?) ?? 'general';
    final read = data['read'] == true;
    final createdAt = _coerceToDateTime(data['createdAt']);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: read ? 0.65 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.white.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: read ? Colors.white12 : AppTheme.crystalGlow.withOpacity(0.4),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onToggleRead(!read),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTypeChip(type),
                    const Spacer(),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM d, h:mm a').format(createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(read ? Icons.mark_email_read : Icons.mark_email_unread,
                          color: AppTheme.crystalGlow),
                      tooltip: read ? 'Mark as unread' : 'Mark as read',
                      onPressed: () => onToggleRead(!read),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                if (data['cta'] != null && data['cta'] is String && (data['cta'] as String).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    data['cta'] as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.mysticPink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final normalized = type.toLowerCase();
    Color background;
    IconData icon;
    switch (normalized) {
      case 'ritual':
        background = AppTheme.mysticPink.withOpacity(0.25);
        icon = Icons.auto_fix_high;
        break;
      case 'marketplace':
        background = AppTheme.holoBlue.withOpacity(0.25);
        icon = Icons.store_mall_directory;
        break;
      case 'dream':
        background = AppTheme.cosmicPurple.withOpacity(0.25);
        icon = Icons.bedtime;
        break;
      default:
        background = Colors.white.withOpacity(0.12);
        icon = Icons.notifications;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            normalized.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }

  static DateTime? _coerceToDateTime(dynamic input) {
    if (input == null) return null;
    if (input is Timestamp) return input.toDate();
    if (input is DateTime) return input;
    if (input is String) {
      try {
        return DateTime.parse(input);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
