import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_container.dart';
import '../services/collection_service_v2.dart';
import '../models/crystal_collection.dart';
import '../widgets/holographic_button.dart';
import 'crystal_compatibility_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  bool _requestedInitialSync = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = context.read<CollectionServiceV2>();
      if (!service.isLoaded) {
        await service.initialize();
      }
      if (!_requestedInitialSync) {
        _requestedInitialSync = true;
        unawaited(service.syncWithBackend());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final collectionService = context.watch<CollectionServiceV2>();
    final entries = collectionService.collection;
    final hasEntries = entries.isNotEmpty;
    final isLoading = (!collectionService.isLoaded && !hasEntries) ||
        (collectionService.isSyncing && !hasEntries);
    final error = collectionService.lastError;

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
              // App Bar
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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HolographicButton(
                  text: '✨ Crystal Compatibility',
                  icon: Icons.auto_awesome,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CrystalCompatibilityScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Collection Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildCollectionContent(
                    context,
                    collectionService,
                    entries,
                    isLoading,
                    error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionContent(
    BuildContext context,
    CollectionServiceV2 service,
    List<CollectionEntry> entries,
    bool isLoading,
    String? error,
  ) {
    if (isLoading) {
      return const GlassmorphicContainer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.crystalGlow),
              SizedBox(height: 20),
              Text(
                'Loading your crystal collection...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null && entries.isEmpty) {
      return GlassmorphicContainer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 20),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  unawaited(service.syncWithBackend());
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.crystalGlow,
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ),
      );
    }

    if (entries.isEmpty) {
      return GlassmorphicContainer(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.diamond_outlined,
                color: AppTheme.crystalGlow,
                size: 48,
              ),
              const SizedBox(height: 20),
              const Text(
                'Your crystal collection is empty',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Start by identifying crystals to add them to your collection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.crystalGlow,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                child: const Text(
                  'Go Identify Crystals',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassmorphicContainer(
      child: RefreshIndicator(
        color: AppTheme.crystalGlow,
        backgroundColor: Colors.black87,
        onRefresh: () async {
          await service.syncWithBackend();
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _buildCrystalCard(entry);
          },
        ),
      ),
    );
  }

  String? _resolvePreviewImage(CollectionEntry entry) {
    final candidates = <String?>[
      ...entry.images,
      ...entry.crystal.imageUrls,
      entry.crystal.imageUrl,
    ];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  Widget _buildCrystalThumbnail(CollectionEntry entry) {
    final imageUrl = _resolvePreviewImage(entry);
    final borderRadius = BorderRadius.circular(10);

    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          colors: [
            AppTheme.crystalGlow.withOpacity(0.28),
            AppTheme.amethystPurple.withOpacity(0.18),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: imageUrl != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }
                      final expected = progress.expectedTotalBytes;
                      final value = expected != null
                          ? progress.cumulativeBytesLoaded / expected
                          : null;
                      return Center(
                        child: SizedBox(
                          height: 26,
                          width: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: value,
                            color: AppTheme.crystalGlow,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, _, __) => const Center(
                      child: Icon(
                        Icons.diamond,
                        size: 40,
                        color: AppTheme.crystalGlow,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.25),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : const Center(
                child: Icon(
                  Icons.diamond,
                  size: 40,
                  color: AppTheme.crystalGlow,
                ),
              ),
      ),
    );
  }

  Widget _buildCrystalCard(CollectionEntry entry) {
    final crystal = entry.crystal;
    final intents = crystal.metaphysicalProperties.isNotEmpty
        ? crystal.metaphysicalProperties
        : entry.primaryUses;
    final formattedDate = DateFormat.yMMMd().format(entry.dateAdded.toLocal());

    return GlassmorphicContainer(
      borderRadius: 15,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCrystalThumbnail(entry),
            const SizedBox(height: 10),
            Text(
              crystal.name.isNotEmpty ? crystal.name : 'Unknown Crystal',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            // Crystal intents
            if (intents.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: intents.take(3).map((intent) {
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppTheme.crystalGlow.withOpacity(0.15),
                    label: Text(
                      intent,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
            Text(
              'Added $formattedDate',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
            const Spacer(),
            // Personal notes indicator
            if (entry.notes != null && entry.notes!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.crystalGlow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Has Notes',
                  style: TextStyle(
                    color: AppTheme.crystalGlow,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (entry.primaryUses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: entry.primaryUses.take(2).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}