import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _marketplaceSubscription;
  bool _isLoading = true;
  String? _loadError;

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

    _listenToListings();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _tabController.dispose();
    _marketplaceSubscription?.cancel();
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
      final allListings = snapshot.docs
          .map((doc) => MarketplaceListing.fromDocument(doc))
          .where((listing) => listing.status == 'active')
          .toList();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      setState(() {
        _listings = allListings;
        _myListings = currentUserId == null
            ? []
            : allListings
                .where((listing) => listing.sellerId == currentUserId)
                .toList();
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

    try {
      await FirebaseFirestore.instance.collection('marketplace').add({
        'title': title,
        'description': description,
        'priceCents': (price * 100).round(),
        'sellerId': user.uid,
        'sellerName': user.displayName ?? user.email ?? 'Crystal Seller',
        'status': 'active',
        'category': category,
        'crystalId': (crystalId?.isNotEmpty == true ? crystalId : _slugify(title)),
        'imageUrl': imageUrl?.isNotEmpty == true ? imageUrl : null,
        'isVerifiedSeller': false,
        'rating': 5.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Listing created successfully!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create listing: ' + e.toString(),
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

  Widget _buildListingsGrid(List<MarketplaceListing> listings) {
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
        return _buildListingCard(listing);
      },
    );
  }

  Widget _buildListingCard(MarketplaceListing listing) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
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
              // Listing image / emblem
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      listing.displayColor.withOpacity(0.3),
                      listing.displayColor.withOpacity(0.15),
                    ],
                  ),
                ),
                child: Center(
                  child: listing.hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            listing.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                listing.titleEmoji,
                                style: const TextStyle(fontSize: 44),
                              );
                            },
                          ),
                        )
                      : Text(
                          listing.titleEmoji,
                          style: const TextStyle(fontSize: 44),
                        ),
                ),
              ),

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
                        Text(
                          listing.sellerName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
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
                  ],
                ),
              ),
            ],
          ),
        ),
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
                    child: _buildListingsGrid(_myListings),
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

    return _buildListingsGrid(_myListings);
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

  factory MarketplaceListing.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawTitle = (data['title'] as String?)?.trim();
    final rawDescription = (data['description'] as String?)?.trim();
    final rawImage = (data['imageUrl'] as String?)?.trim();

    return MarketplaceListing(
      id: doc.id,
      title: rawTitle?.isNotEmpty == true ? rawTitle! : 'Untitled listing',
      description:
          rawDescription?.isNotEmpty == true ? rawDescription! : '',
      priceCents: (data['priceCents'] is num)
          ? (data['priceCents'] as num).round()
          : 0,
      sellerId: (data['sellerId'] as String?) ?? '',
      sellerName: (data['sellerName'] as String?)?.trim().isNotEmpty == true
          ? (data['sellerName'] as String).trim()
          : 'Crystal Seller',
      status: (data['status'] as String?) ?? 'inactive',
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