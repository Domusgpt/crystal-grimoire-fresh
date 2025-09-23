import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> 
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  late TabController _tabController;

  String searchQuery = '';
  String selectedCategory = 'All';

  final NumberFormat _currency = NumberFormat.simpleCurrency();
  final List<String> categories = [
    'All',
    'Raw',
    'Tumbled',
    'Clusters',
    'Jewelry',
    'Rare',
  ];

  List<MarketplaceListing> _listings = [];
  List<MarketplaceListing> _myListings = [];
  List<MarketplaceListing> _pendingListings = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _marketplaceSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _isLoading = true;
  String? _loadError;
  bool _isAdmin = false;
  final Set<String> _moderatingListingIds = <String>{};

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    _tabController = TabController(length: 3, vsync: this);

    _authSubscription =
        FirebaseAuth.instance.userChanges().listen((user) {
      _resolveAdminStatus(user: user);
    });
    unawaited(_resolveAdminStatus(user: FirebaseAuth.instance.currentUser));

    _listenToListings();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _tabController.dispose();
    _authSubscription?.cancel();
    _marketplaceSubscription?.cancel();
    _moderatingListingIds.clear();
    super.dispose();
  }

  void _listenToListings() {
    _marketplaceSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    _marketplaceSubscription = FirebaseFirestore.instance
        .collection('marketplace')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs
          .map((doc) => MarketplaceListing.fromDocument(doc))
          .toList();
      final activeListings =
          docs.where((listing) => listing.status == 'active').toList();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      setState(() {
        _listings = activeListings;
        _myListings = currentUserId == null
            ? []
            : docs
                .where((listing) => listing.sellerId == currentUserId)
                .toList();
        _pendingListings =
            docs.where((listing) => listing.status == 'pending_review').toList();
        _isLoading = false;
        _loadError = null;
      });
    }, onError: (error) {
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load marketplace: $error';
      });
    });
  }

  Future<void> _resolveAdminStatus({User? user}) async {
    final currentUser = user ?? FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (_isAdmin) {
        _updateAdminTabs(false);
      }
      return;
    }

    try {
      final token = await currentUser.getIdTokenResult(true);
      final claims = token.claims ?? {};
      final roles = claims['roles'];
      final hasAdminRole =
          claims['role'] == 'admin' ||
          claims['admin'] == true ||
          (roles is List && roles.contains('admin'));
      _updateAdminTabs(hasAdminRole);
    } catch (error) {
      debugPrint('Failed to resolve admin status: $error');
      _updateAdminTabs(false);
    }
  }

  void _updateAdminTabs(bool nextIsAdmin) {
    if (_isAdmin == nextIsAdmin) {
      return;
    }

    final previousIndex = _tabController.index;
    final newLength = nextIsAdmin ? 4 : 3;
    final clampedIndex = previousIndex.clamp(0, newLength - 1).toInt();

    _tabController.dispose();
    _tabController = TabController(
      length: newLength,
      vsync: this,
      initialIndex: clampedIndex,
    );

    if (mounted) {
      setState(() {
        _isAdmin = nextIsAdmin;
      });
    } else {
      _isAdmin = nextIsAdmin;
    }
  }

  List<MarketplaceListing> _filteredMarketplaceListings() {
    final query = searchQuery.trim().toLowerCase();
    return _listings.where((listing) {
      final matchesSearch = query.isEmpty ||
          listing.title.toLowerCase().contains(query) ||
          listing.description.toLowerCase().contains(query);
      final matchesCategory = selectedCategory == 'All' ||
          (listing.category?.toLowerCase() ==
              selectedCategory.toLowerCase());
      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _slugify(String value) {
    final sanitized =
        value.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
    return sanitized
        .replaceAll(RegExp('^-+'), '')
        .replaceAll(RegExp('-+$'), '');
  }

  Future<bool> _createListing({
    required String title,
    required double price,
    required String description,
    required String category,
    String? crystalId,
    String? imageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please sign in to create a listing.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    final pendingOrActive = _myListings
        .where((listing) =>
            listing.status == 'active' ||
            listing.status == 'pending_review')
        .toList();
    if (pendingOrActive.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already have five active or pending listings. Archive one before submitting another.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return false;
    }

    final latestSubmission = pendingOrActive
        .map((listing) => listing.createdAt?.toDate())
        .whereType<DateTime>()
        .fold<DateTime?>(null, (previous, element) {
      if (previous == null) return element;
      return element.isAfter(previous) ? element : previous;
    });

    if (latestSubmission != null) {
      final minutesSince = DateTime.now().difference(latestSubmission).inMinutes;
      const cooldownMinutes = 12 * 60;
      if (minutesSince < cooldownMinutes) {
        final remaining = cooldownMinutes - minutesSince;
        final remainingHours = (remaining / 60).ceil();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can submit a new listing in about $remainingHours hour(s).',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return false;
      }
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createListing');
      await callable.call({
        'title': title,
        'description': description,
        'priceCents': (price * 100).round(),
        'category': category,
        'crystalId':
            (crystalId?.isNotEmpty == true ? crystalId : _slugify(title)),
        if (imageUrl?.isNotEmpty == true) 'imageUrl': imageUrl,
        'currency': 'usd',
        'quantity': 1,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Listing submitted for review. You will be notified after approval.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF4F46E5),
        ),
      );
      return true;
    } on FirebaseFunctionsException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Failed to create listing.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create listing: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
  }

  void _promptSignIn() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Please sign in to access selling features.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.redAccent,
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
        title: Text(
          'Crystal Marketplace',
          style: GoogleFonts.cinzel(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          tabs: [
            Tab(text: 'Buy'),
            Tab(text: 'Sell'),
            Tab(text: 'My Listings'),
            if (_isAdmin) Tab(text: 'Review Queue'),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Mystical background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0015),
                  Color(0xFF1A0B2E),
                  Color(0xFF2D1B69),
                ],
              ),
            ),
          ),
          
          // Floating gems background
          ...List.generate(20, (index) {
            return Positioned(
              top: (index * 137.0) % MediaQuery.of(context).size.height,
              left: (index * 89.0) % MediaQuery.of(context).size.width,
              child: Transform.rotate(
                angle: index * 0.5,
                child: Icon(
                  Icons.diamond,
                  color: Colors.white.withOpacity(0.05),
                  size: 30 + (index % 3) * 10.0,
                ),
              ),
            );
          }),
          
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBuyTab(),
                _buildSellTab(),
                _buildMyListingsTab(),
                if (_isAdmin) _buildReviewTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyTab() {
    final listings = _filteredMarketplaceListings();

    return Column(
      children: [
        const SizedBox(height: 20),

        // Search bar
        _buildSearchBar(),

        const SizedBox(height: 20),

        // Categories
        _buildCategories(),

        const SizedBox(height: 20),

        // Featured banner
        _buildFeaturedBanner(),

        const SizedBox(height: 20),

        // Listings grid
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                )
              : _loadError != null
                  ? _buildMarketplaceError()
                  : listings.isEmpty
                      ? _buildEmptyMarketplaceState()
                      : _buildListingsGrid(listings),
        ),
      ],
    );
  }

  Widget _buildMarketplaceError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(
            _loadError ?? 'Unable to load marketplace listings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _listenToListings,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMarketplaceState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.diamond_outlined, color: Colors.white38, size: 48),
          const SizedBox(height: 16),
          Text(
            'No listings match your filters yet',
            style: GoogleFonts.cinzel(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the category or keywords to discover more crystals.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search crystals...',
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Container(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFFFD700).withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFFFFD700)
                      : Colors.white.withOpacity(0.2),
                ),
              ),
              child: Text(
                category,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          height: 150,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFFA500),
                      Color(0xFFFF6347),
                    ],
                  ),
                ),
              ),
              // Shimmer effect
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(
                    painter: ShimmerPainter(
                      shimmerValue: _shimmerAnimation.value,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Featured Collections',
                      style: GoogleFonts.cinzel(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover rare and powerful crystals',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Explore',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFD700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListingsGrid(
    List<MarketplaceListing> listings, {
    bool showStatus = false,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return _buildListingCard(listing, showStatus: showStatus);
      },
    );
  }

  Widget _buildListingImage(MarketplaceListing listing) {
    final borderRadius = BorderRadius.circular(16);
    final accent = listing.displayColor;
    final gradient = LinearGradient(
      colors: [
        accent.withOpacity(0.35),
        accent.withOpacity(0.15),
      ],
    );

    final imageUrl = listing.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: gradient,
        ),
        alignment: Alignment.center,
        child: Text(
          listing.titleEmoji,
          style: const TextStyle(fontSize: 44),
        ),
      );
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: gradient,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
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
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: value,
                      color: Colors.white70,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    listing.titleEmoji,
                    style: const TextStyle(fontSize: 44),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(
    MarketplaceListing listing, {
    bool showStatus = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildListingImage(listing),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (listing.isVerifiedSeller)
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF3B82F6),
                                size: 14,
                              ),
                            if (listing.isVerifiedSeller)
                              const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                listing.sellerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFFD700),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              listing.ratingLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          listing.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _currency.format(listing.price),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFD700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.shopping_cart,
                                color: Color(0xFFFFD700),
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        if (showStatus && listing.isPending) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Submitted ${_formatRelativeTime(listing.submittedAt)}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                        if (showStatus && listing.reviewNotes != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            listing.isRejected
                                ? 'Moderator notes: ${listing.reviewNotes}'
                                : 'Notes: ${listing.reviewNotes}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: listing.isRejected
                                  ? Colors.redAccent
                                  : Colors.white60,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showStatus && !listing.isActive)
            Positioned(
              top: 12,
              left: 12,
              child: _buildStatusChip(listing),
            ),
        ],
      );
  }

  Widget _buildStatusChip(MarketplaceListing listing) {
    final color = listing.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(listing.statusIcon, color: color, size: 12),
          const SizedBox(width: 6),
          Text(
            listing.statusLabel,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellTab() {
    final user = FirebaseAuth.instance.currentUser;
    final hasListings = _myListings.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
            ),
            child: const Icon(
              Icons.store,
              color: Colors.black,
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start Selling Your Crystals',
            style: GoogleFonts.cinzel(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'List authentic crystals, set your price, and reach seekers worldwide.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Listings enter a moderation queue before they appear in the marketplace. Expect a review within a few hours.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: user == null ? _promptSignIn : _showCreateListingDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              user == null ? 'Sign in to start selling' : 'Create Listing',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (user == null)
            Text(
              'Sign in to publish listings and manage your crystal storefront.',
              style: GoogleFonts.poppins(color: Colors.white60),
              textAlign: TextAlign.center,
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your active listings',
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            hasListings
                ? SizedBox(
                    height: 420,
                    child: _buildListingsGrid(_myListings, showStatus: true),
                  )
                : _buildEmptyMyListingsMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyMyListingsMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 36),
          const SizedBox(height: 12),
          Text(
            'You have not listed any crystals yet',
            style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Create Listing" to showcase your collection to the community.',
            style: GoogleFonts.poppins(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMyListingsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sign in to manage your listings and track sales.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    if (_myListings.isEmpty) {
      return Center(child: _buildEmptyMyListingsMessage());
    }

    return _buildListingsGrid(_myListings, showStatus: true);
  }

  Widget _buildReviewTab() {
    if (!_isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Moderator access required to review listings.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isLoading && _pendingListings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    if (_pendingListings.isEmpty) {
      return _buildEmptyReviewState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _pendingListings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final listing = _pendingListings[index];
        final isProcessing = _moderatingListingIds.contains(listing.id);
        return _buildReviewCard(listing, isProcessing);
      },
    );
  }

  Widget _buildEmptyReviewState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              'No listings waiting for review',
              style: GoogleFonts.cinzel(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'New submissions will appear here instantly for moderation.',
              style: GoogleFonts.poppins(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(MarketplaceListing listing, bool isProcessing) {
    final submittedLabel = _formatRelativeTime(listing.submittedAt);
    final reviewNotes = listing.reviewNotes;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        color: Colors.white.withOpacity(0.06),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: GoogleFonts.cinzel(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currency.format(listing.price),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFFD700),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(listing),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            listing.description.isNotEmpty
                ? listing.description
                : 'No description provided.',
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildReviewMetaChip(Icons.person, listing.sellerName),
              _buildReviewMetaChip(Icons.schedule, 'Submitted $submittedLabel'),
              if (listing.category != null)
                _buildReviewMetaChip(Icons.category, listing.category!),
              if (listing.crystalId != null)
                _buildReviewMetaChip(Icons.diamond, listing.crystalId!),
            ],
          ),
          if (reviewNotes != null && reviewNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reviewNotes,
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _moderateListing(listing, 'approve'),
                  icon: isProcessing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    'Approve',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final notes = await _promptRejectionReason(listing);
                          if (notes == null) return;
                          await _moderateListing(listing, 'reject', notes: notes);
                        },
                  icon: const Icon(Icons.block),
                  label: Text(
                    'Reject',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: Colors.redAccent.withOpacity(isProcessing ? 0.4 : 0.8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _moderateListing(MarketplaceListing listing, String action,
      {String? notes}) async {
    if (!_isAdmin) {
      _promptSignIn();
      return;
    }

    if (_moderatingListingIds.contains(listing.id)) {
      return;
    }

    if (mounted) {
      setState(() {
        _moderatingListingIds.add(listing.id);
      });
    } else {
      _moderatingListingIds.add(listing.id);
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('reviewListing');
      await callable.call({
        'listingId': listing.id,
        'action': action,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? 'Listing approved and published.'
                : 'Listing rejected. The seller will receive the notes.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor:
              action == 'approve' ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Failed to update listing moderation.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update listing: $error',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _moderatingListingIds.remove(listing.id);
        });
      } else {
        _moderatingListingIds.remove(listing.id);
      }
    }
  }

  Future<String?> _promptRejectionReason(MarketplaceListing listing) async {
    final controller = TextEditingController();
    String? submittedNotes;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A0B2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          title: Text(
            'Reject listing?',
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share optional notes that will be sent to the seller.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Provide a short reason (optional)',
                  hintStyle: GoogleFonts.poppins(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF20103F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                submittedNotes = controller.text.trim();
                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Reject listing',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return submittedNotes;
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return 'recently';
    final now = DateTime.now();
    if (date.isAfter(now)) {
      return DateFormat.yMMMd().format(date);
    }
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return DateFormat.yMMMd().format(date);
  }

  Future<void> _showCreateListingDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _promptSignIn();
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    final crystalIdController = TextEditingController();
    final imageUrlController = TextEditingController();

    final categoryOptions =
        categories.where((category) => category != 'All').toList();
    if (categoryOptions.isEmpty) {
      categoryOptions.add('General');
    }

    String selected = categoryOptions.first;
    String? errorText;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              if (isSubmitting) {
                return;
              }

              FocusScope.of(dialogContext).unfocus();

              if (!formKey.currentState!.validate()) {
                return;
              }

              final title = titleController.text.trim();
              final priceInput = priceController.text.trim();
              final description = descriptionController.text.trim();
              final crystalId = crystalIdController.text.trim();
              final imageUrl = imageUrlController.text.trim();

              final normalizedPrice =
                  priceInput.replaceAll(RegExp(r'[^0-9.]'), '');
              final parsedPrice = double.tryParse(normalizedPrice);

              if (parsedPrice == null) {
                setDialogState(() {
                  errorText = 'Please enter a valid numeric price.';
                });
                return;
              }

              if (imageUrl.isNotEmpty) {
                final uri = Uri.tryParse(imageUrl);
                if (uri == null || !uri.isAbsolute) {
                  setDialogState(() {
                    errorText =
                        'Please provide a valid image URL (https://...) or leave this field blank.';
                  });
                  return;
                }
              }

              setDialogState(() {
                isSubmitting = true;
                errorText = null;
              });

              final success = await _createListing(
                title: title,
                price: parsedPrice,
                description: description.isEmpty
                    ? 'No description provided'
                    : description,
                category: selected,
                crystalId: crystalId.isEmpty ? null : crystalId,
                imageUrl: imageUrl.isEmpty ? null : imageUrl,
              );

              if (!mounted) {
                return;
              }

              if (success) {
                Navigator.of(dialogContext).pop();
              } else {
                setDialogState(() {
                  isSubmitting = false;
                  errorText ??=
                      'Unable to save the listing. Please try again.';
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1A0B2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              title: Text(
                'Create Listing',
                style: GoogleFonts.cinzel(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (errorText != null) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorText!,
                            style: GoogleFonts.poppins(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: titleController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: _dialogFieldDecoration(
                          'Listing title',
                          hintText: 'Amethyst cathedral geode',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: priceController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.]'),
                          ),
                        ],
                        decoration: _dialogFieldDecoration(
                          'Price (USD)',
                          hintText: 'e.g. 45.00',
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final normalized = (value ?? '')
                              .trim()
                              .replaceAll(RegExp(r'[^0-9.]'), '');
                          if (normalized.isEmpty) {
                            return 'Price is required.';
                          }
                          final parsed = double.tryParse(normalized);
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid price.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        maxLines: 3,
                        decoration: _dialogFieldDecoration(
                          'Description',
                          hintText: 'Share crystal origin, size, and care tips.',
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selected,
                        dropdownColor: const Color(0xFF1A0B2E),
                        iconEnabledColor: Colors.white70,
                        items: categoryOptions
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(
                                  category,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selected = value);
                          }
                        },
                        decoration: _dialogFieldDecoration('Category'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: crystalIdController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: _dialogFieldDecoration(
                          'Crystal reference (optional)',
                          hintText: 'Link to a library slug or identifier',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: imageUrlController,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: _dialogFieldDecoration(
                          'Image URL (optional)',
                          hintText: 'https://your-crystal-image.jpg',
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Create',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    crystalIdController.dispose();
    imageUrlController.dispose();
  }

  InputDecoration _dialogFieldDecoration(
    String label, {
    String? hintText,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixText: prefixText,
      labelStyle: GoogleFonts.poppins(color: Colors.white70),
      hintStyle: GoogleFonts.poppins(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF1F0F3D),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFFD700)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class MarketplaceListing {
  MarketplaceListing({
    required this.id,
    required this.title,
    required this.description,
    required this.priceCents,
    required this.sellerId,
    required this.sellerName,
    required this.status,
    required this.category,
    required this.crystalId,
    required this.imageUrl,
    required this.isVerifiedSeller,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.moderationStatus,
    this.moderationNotes,
    this.moderationSubmittedAt,
    this.moderationReviewedAt,
    this.moderationReviewerId,
    this.activatedAt,
    this.rejectionReason,
  });

  final String id;
  final String title;
  final String description;
  final int priceCents;
  final String sellerId;
  final String sellerName;
  final String status;
  final String? category;
  final String? crystalId;
  final String? imageUrl;
  final bool isVerifiedSeller;
  final double rating;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String? moderationStatus;
  final String? moderationNotes;
  final Timestamp? moderationSubmittedAt;
  final Timestamp? moderationReviewedAt;
  final String? moderationReviewerId;
  final Timestamp? activatedAt;
  final String? rejectionReason;

  factory MarketplaceListing.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MarketplaceListing.fromMap(doc.id, data);
  }

  factory MarketplaceListing.fromMap(String id, Map<String, dynamic> data) {
    final rawTitle = (data['title'] as String?)?.trim();
    final rawDescription = (data['description'] as String?)?.trim();
    final rawImage = ((data['imageUrl'] ?? data['imageURL']) as String?)?.trim();
    final moderation = data['moderation'] is Map
        ? Map<String, dynamic>.from(data['moderation'] as Map)
        : null;

    final moderationStatus = (moderation?['status'] as String?)?.trim();
    final moderationNotes = (moderation?['notes'] as String?)?.trim();
    final moderationSubmittedAt = moderation?['submittedAt'] is Timestamp
        ? moderation?['submittedAt'] as Timestamp
        : null;
    final moderationReviewedAt = moderation?['reviewedAt'] is Timestamp
        ? moderation?['reviewedAt'] as Timestamp
        : null;
    final moderationReviewerId = (moderation?['reviewerId'] as String?)?.trim();
    final rejectionReason = (data['rejectionReason'] as String?)?.trim();

    final priceCents = (() {
      if (data['priceCents'] is num) {
        return (data['priceCents'] as num).round();
      }
      if (data['price_cents'] is num) {
        return (data['price_cents'] as num).round();
      }
      if (data['price'] is num) {
        return ((data['price'] as num) * 100).round();
      }
      return 0;
    })();

    return MarketplaceListing(
      id: id,
      title: rawTitle?.isNotEmpty == true ? rawTitle! : 'Untitled listing',
      description: rawDescription?.isNotEmpty == true ? rawDescription! : '',
      priceCents: priceCents,
      sellerId: (data['sellerId'] as String?) ?? '',
      sellerName: (() {
        final rawName = (data['sellerName'] ?? data['sellerDisplayName']) as String?;
        if (rawName != null && rawName.trim().isNotEmpty) {
          return rawName.trim();
        }
        return 'Crystal Seller';
      })(),
      status: ((data['status'] as String?) ?? 'inactive').trim(),
      category: (data['category'] as String?)?.trim().isNotEmpty == true
          ? (data['category'] as String).trim()
          : null,
      crystalId: (data['crystalId'] as String?)?.trim().isNotEmpty == true
          ? (data['crystalId'] as String).trim()
          : null,
      imageUrl: rawImage?.isNotEmpty == true ? rawImage : null,
      isVerifiedSeller: (data['isVerifiedSeller'] as bool?) ?? false,
      rating: (data['rating'] is num)
          ? (data['rating'] as num).toDouble()
          : 0,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      moderationStatus: moderationStatus,
      moderationNotes:
          moderationNotes != null && moderationNotes.isNotEmpty ? moderationNotes : null,
      moderationSubmittedAt: moderationSubmittedAt,
      moderationReviewedAt: moderationReviewedAt,
      moderationReviewerId: moderationReviewerId,
      activatedAt: data['activatedAt'] as Timestamp?,
      rejectionReason:
          rejectionReason != null && rejectionReason.isNotEmpty ? rejectionReason : null,
    );
  }

  double get price => priceCents / 100.0;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  String get ratingLabel => rating > 0 ? rating.toStringAsFixed(1) : 'New';

  Color get displayColor {
    const palette = <Color>[
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFFF97316),
      Color(0xFF0EA5E9),
    ];
    final index = id.hashCode.abs() % palette.length;
    return palette[index];
  }

  String get titleEmoji {
    final key = category?.toLowerCase();
    switch (key) {
      case 'raw':
        return '⛰️';
      case 'tumbled':
        return '🔮';
      case 'clusters':
        return '💎';
      case 'jewelry':
        return '📿';
      case 'rare':
        return '✨';
      default:
        return '💠';
    }
  }

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending_review';
  bool get isRejected => status == 'rejected';
  bool get isArchived => status == 'archived';

  DateTime? get submittedAt =>
      moderationSubmittedAt?.toDate() ?? createdAt?.toDate();
  DateTime? get reviewedAt => moderationReviewedAt?.toDate();

  String? get reviewNotes {
    if (rejectionReason != null && rejectionReason!.isNotEmpty) {
      return rejectionReason;
    }
    return moderationNotes;
  }

  String get statusLabel {
    if (isPending) return 'Pending review';
    if (isRejected) return 'Rejected';
    if (isArchived) return 'Archived';
    return 'Active';
  }

  Color get statusColor {
    if (isPending) {
      return const Color(0xFF6366F1);
    }
    if (isRejected) {
      return const Color(0xFFEF4444);
    }
    if (isArchived) {
      return Colors.white70;
    }
    return const Color(0xFF10B981);
  }

  IconData get statusIcon {
    if (isPending) return Icons.hourglass_top;
    if (isRejected) return Icons.block;
    if (isArchived) return Icons.inventory_2_outlined;
    return Icons.check_circle;
  }
}

class ShimmerPainter extends CustomPainter {
  final double shimmerValue;

  ShimmerPainter({required this.shimmerValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0),
        ],
        stops: [
          shimmerValue - 0.3,
          shimmerValue,
          shimmerValue + 0.3,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}