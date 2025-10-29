import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../config/plan_entitlements.dart';
import 'environment_config.dart';
import 'storage_service.dart';
import 'firebase_guard.dart';
import 'plan_status_service.dart';

/// Handles subscription management for Crystal Grimoire.
///
/// The original implementation expected the RevenueCat SDK (`purchases_flutter`)
/// which is not included in the project dependencies. This rewrite removes the
/// RevenueCat requirement and leans on Stripe Checkout for every platform. The
/// UI opens the returned hosted checkout link (web or mobile browser), and the
/// Cloud Function `finalizeStripeCheckoutSession` updates Firestore once the
/// payment completes. Local state is hydrated from Firestore and cached via
/// `StorageService` for offline access.
class EnhancedPaymentService {
  static FirebaseFunctions? get _functions => FirebaseGuard.functions();
  static FirebaseFirestore? get _firestore => FirebaseGuard.firestore;
  static FirebaseAuth? get _auth => FirebaseGuard.auth;
  static bool get _hasFirebaseApp => FirebaseGuard.isConfigured;
  static bool get _stripeBackendEnabled =>
      _config.enableStripeCheckout &&
      _config.stripePublishableKey.isNotEmpty &&
      _hasFirebaseApp &&
      _functions != null &&
      _firestore != null &&
      _auth != null;

  static EnvironmentConfig get _config => EnvironmentConfig.instance;

  static bool _isInitialized = false;
  static SubscriptionStatus? _cachedStatus;

  static String get premiumMonthlyId =>
      _config.stripePremiumPriceId.isNotEmpty
          ? _config.stripePremiumPriceId
          : 'crystal_premium_monthly';
  static String get proMonthlyId =>
      _config.stripeProPriceId.isNotEmpty
          ? _config.stripeProPriceId
          : 'crystal_pro_monthly';
  static String get foundersLifetimeId =>
      _config.stripeFoundersPriceId.isNotEmpty
          ? _config.stripeFoundersPriceId
          : 'crystal_founders_lifetime';

  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (!_stripeBackendEnabled) {
      _cachedStatus = SubscriptionStatus.free();
      _isInitialized = true;
      return;
    }
    await _hydrateCachedStatus(forceRefresh: true);
    _isInitialized = true;
  }

  static Future<SubscriptionStatus> getSubscriptionStatus({
    bool forceRefresh = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_stripeBackendEnabled) {
      _cachedStatus = SubscriptionStatus.free();
      return _cachedStatus!;
    }

    await _hydrateCachedStatus(forceRefresh: forceRefresh);
    return _cachedStatus ?? SubscriptionStatus.free();
  }

  static Future<List<MockPackage>> getOfferings() async {
    final defaults = _defaultOfferings();
    final store = _firestore;

    if (store == null || !_hasFirebaseApp) {
      return defaults;
    }

    try {
      final snapshot = await store
          .collection('plan_catalog')
          .orderBy('sortOrder')
          .get();

      if (snapshot.docs.isEmpty) {
        return defaults;
      }

      return snapshot.docs
          .map(_mapPlanCatalogDoc)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Plan catalog fetch failed, falling back to defaults: $error');
      return defaults;
    }
  }

  static Future<PurchaseResult> purchasePremium() async {
    return purchaseByPlan(priceId: premiumMonthlyId, planId: 'premium');
  }

  static Future<PurchaseResult> purchasePro() async {
    return purchaseByPlan(priceId: proMonthlyId, planId: 'pro');
  }

  static Future<PurchaseResult> purchaseFounders() async {
    return purchaseByPlan(priceId: foundersLifetimeId, planId: 'founders');
  }

  static Future<PurchaseResult> purchaseByPlan({
    required String priceId,
    required String planId,
  }) async {
    return _startCheckout(priceId, planId);
  }

  static Future<SubscriptionStatus> confirmWebCheckout(String sessionId) async {
    if (sessionId.isEmpty) {
      throw Exception('Missing checkout session identifier.');
    }

    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase authentication is not configured.');
    }

    final user = auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to verify subscriptions.');
    }

    if (!_stripeBackendEnabled) {
      throw Exception(
        'Stripe checkout is disabled. Provide ENABLE_STRIPE_CHECKOUT=true and configure Firebase Functions.',
      );
    }

    try {
      final callable =
          _functions?.httpsCallable('finalizeStripeCheckoutSession');
      if (callable == null) {
        throw Exception('Stripe Functions are not configured.');
      }
      final response = await callable.call({'sessionId': sessionId});
      final data = Map<String, dynamic>.from(response.data as Map);

      final resolvedTier =
          (data['plan'] as String? ?? data['tier'] as String? ?? 'free')
              .toLowerCase();
      final expiresAt = _coerceExpiresAt(data['expiresAt']);
      final willRenew = data['willRenew'] == true;
      final isActive = data['isActive'] == true;

      await StorageService.saveSubscriptionTier(resolvedTier);
      await _hydrateCachedStatus(forceRefresh: true);

      return _cachedStatus ?? SubscriptionStatus(
        tier: resolvedTier,
        isActive: isActive,
        expiresAt: expiresAt,
        willRenew: willRenew,
      );
    } catch (error) {
      throw Exception('Failed to verify checkout status: $error');
    }
  }

  static Future<bool> restorePurchases() async {
    await _hydrateCachedStatus(forceRefresh: true);
    final tier = _cachedStatus?.tier ?? 'free';
    return tier != 'free';
  }

  static Future<void> cancelSubscription() async {
    throw Exception(
      'Stripe subscriptions must be managed via the Stripe customer portal or support.',
    );
  }

  static Future<void> enableFoundersAccountForTesting() async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (user == null) return;

    await _applyPlanStatus(
      tier: 'founders',
      provider: 'manual',
      isActive: true,
      willRenew: false,
      expiresAtIso: null,
    );
    await StorageService.enableFoundersAccount();
    _cachedStatus = SubscriptionStatus(
      tier: 'founders',
      isActive: true,
      expiresAt: null,
      willRenew: false,
    );
  }

  static Future<PurchaseResult> _startCheckout(
    String priceId,
    String tier,
  ) async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (user == null) {
      return const PurchaseResult(
        success: false,
        error: 'You must be signed in to start a subscription.',
      );
    }

    if (!_stripeBackendEnabled) {
      return const PurchaseResult(
        success: false,
        error:
            'Stripe checkout is disabled. Enable ENABLE_STRIPE_CHECKOUT and Firebase Functions before purchasing.',
      );
    }

    if (_config.stripePublishableKey.isEmpty) {
      return const PurchaseResult(
        success: false,
        error:
            'Stripe is not configured. Provide STRIPE_PUBLISHABLE_KEY and price IDs before starting checkout.',
      );
    }

    if (priceId.isEmpty) {
      return PurchaseResult(
        success: false,
        error:
            'No Stripe price is configured for the $tier plan. Update EnvironmentConfig.',
      );
    }

    try {
      final urls = _buildWebCheckoutUrls();
      final callable = _functions?.httpsCallable('createStripeCheckoutSession');
      if (callable == null) {
        return const PurchaseResult(
          success: false,
          error: 'Stripe Functions are not configured.',
        );
      }
      final response = await callable.call({
        'priceId': priceId,
        'tier': tier,
        'successUrl': urls['success'],
        'cancelUrl': urls['cancel'],
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final checkoutUrl = data['checkoutUrl'] as String?;
      final sessionId = data['sessionId'] as String?;

      if (checkoutUrl == null || sessionId == null) {
        return const PurchaseResult(
          success: false,
          error: 'Checkout session could not be created. Please try again.',
        );
      }

      return PurchaseResult(
        success: true,
        isWebPlatform: true,
        redirectUrl: checkoutUrl,
        webSessionId: sessionId,
      );
    } catch (error) {
      return PurchaseResult(
        success: false,
        error: 'Failed to start checkout: $error',
      );
    }
  }

  static List<MockPackage> _defaultOfferings() {
    return [
      MockPackage(
        identifier: premiumMonthlyId,
        planId: 'premium',
        title: 'Crystal Premium',
        description: '15 IDs/day · Collection sync · Ad-free rituals',
        price: '\$8.99',
        isLifetime: false,
        features: const [
          '15 crystal identifications daily',
          'Priority AI guidance queue',
          'Moon ritual sync across devices',
        ],
        recommended: true,
      ),
      MockPackage(
        identifier: proMonthlyId,
        planId: 'pro',
        title: 'Crystal Pro',
        description: '40 IDs/day · Deep dream analysis · Advanced rituals',
        price: '\$19.99',
        isLifetime: false,
        features: const [
          '40 identifications per day',
          'Advanced healing layout generator',
          'Crystal compatibility matrix exports',
        ],
      ),
      MockPackage(
        identifier: foundersLifetimeId,
        planId: 'founders',
        title: 'Founders Lifetime',
        description: 'Lifetime access · Founders badge · Beta previews',
        price: '\$499.00',
        isLifetime: true,
        features: const [
          'Unlimited identifications and rituals',
          'Founders Discord role and concierge support',
          'Priority access to experimental ceremonies',
        ],
      ),
    ];
  }

  static MockPackage _mapPlanCatalogDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final features = List<String>.from(data['features'] as List? ?? const []);
    final displayName = (data['displayName'] as String?)?.trim();
    final tagline = (data['tagline'] as String?)?.trim();
    final displayPrice = (data['displayPrice'] as String?)?.trim();
    final stripePriceId = (data['stripePriceId'] as String?)?.trim() ?? '';
    final billingCycle = (data['billingCycle'] as String?)?.trim().toLowerCase();

    return MockPackage(
      identifier: stripePriceId,
      planId: doc.id,
      title: displayName != null && displayName.isNotEmpty ? displayName : doc.id,
      description: tagline != null && tagline.isNotEmpty
          ? tagline
          : 'Configure plan messaging in Firestore plan_catalog.',
      price: displayPrice != null && displayPrice.isNotEmpty
          ? displayPrice
          : 'Configure Stripe price',
      isLifetime: data['lifetime'] == true || billingCycle == 'lifetime',
      features: features,
      recommended: data['recommended'] == true,
    );
  }

  static String resolvePlanIdForPrice(String priceId) {
    return _inferPlanIdFromIdentifier(priceId);
  }

  static String _inferPlanIdFromIdentifier(String identifier) {
    if (identifier == premiumMonthlyId) {
      return 'premium';
    }
    if (identifier == proMonthlyId) {
      return 'pro';
    }
    if (identifier == foundersLifetimeId) {
      return 'founders';
    }
    return '';
  }

  static Map<String, String> _buildWebCheckoutUrls() {
    final baseUri = Uri.base;
    final origin = baseUri.hasAuthority ? baseUri.origin : _config.websiteUrl;
    final successUrl =
        '$origin/#/subscription?session_id={CHECKOUT_SESSION_ID}';
    final cancelUrl = '$origin/#/subscription?cancelled=true';
    return {'success': successUrl, 'cancel': cancelUrl};
  }

  static Future<void> _hydrateCachedStatus({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStatus != null) {
      return;
    }

    if (!_stripeBackendEnabled) {
      _cachedStatus = SubscriptionStatus.free();
      return;
    }

    final auth = _auth;
    final store = _firestore;
    final user = auth?.currentUser;
    if (user == null || store == null) {
      _cachedStatus = SubscriptionStatus.free();
      return;
    }

    try {
      final planStatus = await PlanStatusService.getPlanStatus(forceRefresh: true);

      final snapshot = await store.collection('users').doc(user.uid).get();
      final data = snapshot.data();
      final profile = data != null && data['profile'] is Map
          ? Map<String, dynamic>.from(data['profile'] as Map)
          : <String, dynamic>{};

      final status = SubscriptionStatus.fromProfile(profile).copyWith(
        tier: planStatus.tier,
      );

      _cachedStatus = status;
      await StorageService.saveSubscriptionTier(status.tier);
    } catch (error) {
      debugPrint('Failed to hydrate subscription status: $error');
      _cachedStatus ??= SubscriptionStatus.free();
    }
  }

  static Future<void> _applyPlanStatus({
    required String tier,
    required String provider,
    required bool isActive,
    required bool willRenew,
    String? expiresAtIso,
  }) async {
    if (!_stripeBackendEnabled) {
      return;
    }

    final auth = _auth;
    final store = _firestore;
    final user = auth?.currentUser;
    if (user == null || store == null) return;

    final entitlements = PlanEntitlements.effectiveLimits(tier);
    final flags = PlanEntitlements.flags(tier);
    final lifetime = PlanEntitlements.isLifetime(tier);
    final expiresAtTimestamp = _timestampFromIso(expiresAtIso);

    final profileUpdate = <String, dynamic>{
      'subscriptionTier': tier,
      'subscriptionStatus': isActive ? 'active' : 'inactive',
      'subscriptionProvider': provider,
      'subscriptionBillingTier': tier,
      'subscriptionWillRenew': willRenew,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      'effectiveLimits': entitlements,
    };

    if (expiresAtTimestamp != null) {
      profileUpdate['subscriptionExpiresAt'] = expiresAtTimestamp;
    } else {
      profileUpdate['subscriptionExpiresAt'] = null;
    }

    await store.collection('users').doc(user.uid).set({
      'profile': profileUpdate,
    }, SetOptions(merge: true));

    final planPayload = <String, dynamic>{
      'plan': tier,
      'billingTier': tier,
      'provider': provider,
      'effectiveLimits': entitlements,
      'flags': flags,
      'willRenew': willRenew,
      'lifetime': lifetime,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (expiresAtTimestamp != null) {
      planPayload['expiresAt'] = expiresAtTimestamp;
    } else if (lifetime) {
      planPayload['expiresAt'] = null;
    }

    await store
        .collection('users')
        .doc(user.uid)
        .collection('plan')
        .doc('active')
        .set(planPayload, SetOptions(merge: true));

    try {
      await PlanStatusService.clearCachedStatus();
      await PlanStatusService.refreshPlanStatus();
    } catch (error) {
      debugPrint('Plan status refresh failed after update: $error');
    }
  }

  static String? _coerceExpiresAt(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return DateTime.tryParse(value.toString())?.toIso8601String();
  }

  static Timestamp? _timestampFromIso(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return Timestamp.fromDate(parsed.toUtc());
  }
}

class SubscriptionStatus {
  final String tier;
  final bool isActive;
  final String? expiresAt;
  final bool willRenew;

  const SubscriptionStatus({
    required this.tier,
    required this.isActive,
    this.expiresAt,
    required this.willRenew,
  });

  factory SubscriptionStatus.free() {
    return const SubscriptionStatus(
      tier: 'free',
      isActive: false,
      expiresAt: null,
      willRenew: false,
    );
  }

  factory SubscriptionStatus.fromProfile(Map<String, dynamic> profile) {
    final tier = (profile['subscriptionTier'] ?? 'free').toString();
    final status = (profile['subscriptionStatus'] ?? 'inactive')
        .toString()
        .toLowerCase();
    final willRenew = profile['subscriptionWillRenew'] == true;
    final expiresAt = EnhancedPaymentService._coerceExpiresAt(
      profile['subscriptionExpiresAt'],
    );

    return SubscriptionStatus(
      tier: tier,
      isActive: status == 'active',
      expiresAt: expiresAt,
      willRenew: willRenew,
    );
  }

  SubscriptionStatus copyWith({
    String? tier,
    bool? isActive,
    String? expiresAt,
    bool? willRenew,
  }) {
    return SubscriptionStatus(
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      willRenew: willRenew ?? this.willRenew,
    );
  }

  @override
  String toString() {
    return 'SubscriptionStatus(tier: $tier, active: $isActive, expires: $expiresAt)';
  }
}

class PurchaseResult {
  final bool success;
  final String? error;
  final bool isWebPlatform;
  final String? redirectUrl;
  final String? webSessionId;

  const PurchaseResult({
    required this.success,
    this.error,
    this.isWebPlatform = false,
    this.redirectUrl,
    this.webSessionId,
  });
}

class MockPackage {
  final String identifier;
  final String planId;
  final String title;
  final String description;
  final String price;
  final bool isLifetime;
  final List<String> features;
  final bool recommended;

  const MockPackage({
    required this.identifier,
    required this.planId,
    required this.title,
    required this.description,
    required this.price,
    required this.isLifetime,
    this.features = const [],
    this.recommended = false,
  });

  bool get hasStripePrice => identifier.isNotEmpty;
}
