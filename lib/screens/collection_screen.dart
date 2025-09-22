import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/crystal_collection.dart';
import '../services/collection_service_v2.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_container.dart';
import 'crystal_identification_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  bool _requestedInitialSync = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialSync) return;

    _requestedInitialSync = true;
    final service = context.read<CollectionServiceV2>();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && service.collection.isEmpty && !service.isSyncing) {
      service.syncWithBackend();
    }
  }

  Future<void> _refresh(CollectionServiceV2 service) async {
    await service.syncWithBackend();
    if (!mounted) return;

    if (service.lastError != null) {
      _showSnack(service.lastError!, color: Colors.redAccent);
    }
  }

  Future<void> _toggleFavorite(CollectionServiceV2 service, CollectionEntry entry) async {
    try {
      await service.updateCrystal(entry.id, isFavorite: !entry.isFavorite);
      if (!mounted) return;
      final message = entry.isFavorite
          ? 'Removed ${entry.crystal.name} from favorites.'
          : 'Marked ${entry.crystal.name} as a favorite.';
      _showSnack(message, color: AppTheme.crystalGlow);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to update favorite: $e', color: Colors.redAccent);
    }
  }

  Future<void> _removeEntry(CollectionServiceV2 service, CollectionEntry entry) async {
    try {
      await service.removeCrystal(entry.id);
      if (!mounted) return;
      _showSnack('${entry.crystal.name} removed from your collection.', color: Colors.pinkAccent);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to remove crystal: $e', color: Colors.redAccent);
    }
  }

  void _showSnack(String message, {Color color = Colors.purple}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.deepMystical,
              AppTheme.mysticalPurple,
              AppTheme.deepMystical,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '🔮 My Crystal Collection',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Consumer<CollectionServiceV2>(
                    builder: (context, service, _) {
                      return RefreshIndicator(
                        color: AppTheme.crystalGlow,
                        onRefresh: () => _refresh(service),
                        child: _buildCollectionContent(service),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionContent(CollectionServiceV2 service) {
    final stats = service.getStats();
    final entries = service.collection;
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;

    final children = <Widget>[];

    children.add(_buildOverviewCard(service, stats, isAuthenticated));

    if (service.lastError != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: GlassmorphicContainer(
            padding: const EdgeInsets.all(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    service.lastError!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!service.isLoaded && entries.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 32.0),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.crystalGlow),
          ),
        ),
      );
    } else if (entries.isEmpty) {
      children.add(_buildEmptyState(isAuthenticated));
    } else {
      for (final entry in entries) {
        children.add(_buildEntryCard(service, entry));
      }
    }

    children.add(const SizedBox(height: 60));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }

  Widget _buildOverviewCard(CollectionServiceV2 service, CollectionStats stats, bool isAuthenticated) {
    final favoriteCount = stats.favoriteCrystals.length;
    final mostUsed = stats.mostUsedCrystals.take(3).toList();
    final chakraCoverage = stats.crystalsByChakra.keys.take(3).join(', ');

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.crystalGlow),
              const SizedBox(width: 8),
              Text(
                'Collection Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (service.isSyncing)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.crystalGlow),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatChip(Icons.collections_bookmark, '${stats.totalCrystals} crystals'),
              _buildStatChip(Icons.favorite, '$favoriteCount favorites'),
              if (mostUsed.isNotEmpty)
                _buildStatChip(Icons.star, 'Most used: ${mostUsed.join(', ')}'),
              if (chakraCoverage.isNotEmpty)
                _buildStatChip(Icons.self_improvement, 'Chakras: $chakraCoverage'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            isAuthenticated
                ? 'Your collection stays in sync across devices. Pull down to refresh if you recently updated it elsewhere.'
                : 'Sign in to keep this collection synced across devices and unlock usage tracking.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Chip(
      backgroundColor: Colors.white.withOpacity(0.12),
      avatar: Icon(icon, size: 18, color: AppTheme.crystalGlow),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildEmptyState(bool isAuthenticated) {
    return GlassmorphicContainer(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_fix_high, color: AppTheme.crystalGlow, size: 48),
          const SizedBox(height: 16),
          Text(
            'No crystals yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isAuthenticated
                ? 'Use the Crystal ID scanner or add entries from the library to start curating your personal collection.'
                : 'Sign in to save crystals you identify and build a synced collection across your devices.',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CrystalIdentificationScreen()),
              );
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Identify a crystal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crystalGlow,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(CollectionServiceV2 service, CollectionEntry entry) {
    final crystal = entry.crystal;
    final imageUrl = crystal.imageUrls.isNotEmpty
        ? crystal.imageUrls.first
        : (crystal.imageUrl.isNotEmpty ? crystal.imageUrl : null);
    final formatter = DateFormat('MMM d, yyyy');

    return GlassmorphicContainer(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CrystalAvatar(imageUrl: imageUrl, fallbackLetter: crystal.name.isNotEmpty ? crystal.name[0] : '?'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crystal.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (crystal.scientificName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        crystal.scientificName,
                        style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      crystal.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      entry.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: entry.isFavorite ? Colors.pinkAccent : Colors.white54,
                    ),
                    onPressed: () => _toggleFavorite(service, entry),
                    tooltip: entry.isFavorite ? 'Remove from favorites' : 'Mark as favorite',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                    onPressed: () => _removeEntry(service, entry),
                    tooltip: 'Remove from collection',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in entry.primaryUses)
                _buildTagChip(tag),
              if (entry.crystal.chakras.isNotEmpty)
                _buildTagChip('Chakras: ${entry.crystal.chakras.join(', ')}'),
            ],
          ),
          if ((entry.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Personal Notes',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              entry.notes!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Added ${formatter.format(entry.dateAdded)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                entry.libraryRef,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label) {
    return Chip(
      backgroundColor: Colors.white.withOpacity(0.12),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _CrystalAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackLetter;

  const _CrystalAvatar({
    required this.imageUrl,
    required this.fallbackLetter,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Colors.white.withOpacity(0.5);

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        gradient: const LinearGradient(
          colors: [AppTheme.crystalGlow, AppTheme.mysticPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(imageUrl!, fit: BoxFit.cover)
            : Center(
                child: Text(
                  fallbackLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}
