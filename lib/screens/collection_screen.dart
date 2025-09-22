import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/crystal_collection.dart';
import '../screens/crystal_identification_screen.dart';
import '../services/auth_service.dart';
import '../services/collection_service_v2.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_container.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  CollectionServiceV2? _collectionService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<CollectionServiceV2>();
    if (_collectionService != service) {
      _collectionService = service;
      service.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CollectionServiceV2>();
    final isAuthenticated = AuthService.currentUser != null;

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
              _buildHeader(context, service.collection.length),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (service.lastError != null)
                        _ErrorBanner(
                          message: service.lastError!,
                          onRetry: service.isSyncing ? null : () => service.syncWithBackend(),
                        ),
                      if (service.isSyncing)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.crystalGlow),
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      Expanded(
                        child: GlassmorphicContainer(
                          padding: const EdgeInsets.all(16),
                          child: _buildCollectionBody(
                            service: service,
                            isAuthenticated: isAuthenticated,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount) {
    final subtitle = totalCount == 0
        ? 'Start your archive with a fresh identification'
        : '$totalCount ${totalCount == 1 ? 'crystal catalogued' : 'crystals catalogued'}';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔮 My Crystal Collection',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.crystalGlow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CrystalIdentificationScreen()),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text(
              'Identify',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionBody({
    required CollectionServiceV2 service,
    required bool isAuthenticated,
  }) {
    final entries = service.collection;

    if (!service.isLoaded && entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.crystalGlow),
            SizedBox(height: 16),
            Text(
              'Summoning your crystals...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.crystalGlow,
      onRefresh: service.syncWithBackend,
      child: entries.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                const Icon(
                  Icons.diamond_outlined,
                  color: AppTheme.crystalGlow,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  isAuthenticated
                      ? 'Your collection is waiting for its first crystal.'
                      : 'Sign in or create an account to start your crystal grimoire.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.crystalGlow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CrystalIdentificationScreen()),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text(
                      'Identify a Crystal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            )
          : GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _CollectionEntryCard(
                  entry: entry,
                  onToggleFavorite: () => _toggleFavorite(service, entry),
                );
              },
            ),
    );
  }

  Future<void> _toggleFavorite(CollectionServiceV2 service, CollectionEntry entry) async {
    try {
      await service.updateCrystal(entry.id, isFavorite: !entry.isFavorite);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update favorite: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class _CollectionEntryCard extends StatelessWidget {
  const _CollectionEntryCard({
    required this.entry,
    this.onToggleFavorite,
  });

  final CollectionEntry entry;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final crystal = entry.crystal;
    final imageUrl = _resolveImageUrl(entry);
    final accentColor = AppTheme.crystalGlow;
    final subtitle = crystal.scientificName.isNotEmpty
        ? crystal.scientificName
        : (crystal.aliases.isNotEmpty ? crystal.aliases.first : null);
    final tags = entry.primaryUses.isNotEmpty
        ? entry.primaryUses.take(3).toList()
        : crystal.metaphysicalProperties.take(3).toList();
    final dateText = DateFormat.yMMMd().format(entry.dateAdded.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1.4,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ImageFallback(name: crystal.name, accentColor: accentColor),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(color: AppTheme.crystalGlow),
                          ),
                        );
                      },
                    )
                  : _ImageFallback(name: crystal.name, accentColor: accentColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            crystal.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: -6,
              children: [
                for (final tag in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
              ],
            ),
          if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.notes!,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.calendar_month,
                size: 16,
                color: Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                dateText,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: onToggleFavorite,
                icon: Icon(entry.isFavorite ? Icons.favorite : Icons.favorite_border),
                color: entry.isFavorite ? Colors.pinkAccent : Colors.white70,
                tooltip: entry.isFavorite ? 'Remove from favorites' : 'Mark as favorite',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _resolveImageUrl(CollectionEntry entry) {
    if (entry.images.isNotEmpty) {
      final candidate = entry.images.first;
      if (_isNetworkImage(candidate)) {
        return candidate;
      }
    }

    if (entry.crystal.imageUrls.isNotEmpty) {
      final candidate = entry.crystal.imageUrls.first;
      if (_isNetworkImage(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  bool _isNetworkImage(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.name, required this.accentColor});

  final String name;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty
        ? trimmed.characters.first.toUpperCase()
        : '✶';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.35),
            accentColor.withOpacity(0.15),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () => onRetry!(),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
