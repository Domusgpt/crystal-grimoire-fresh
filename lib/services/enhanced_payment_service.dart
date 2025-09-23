import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../config/plan_entitlements.dart';
import 'environment_config.dart';
import 'storage_service.dart';

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
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

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
    await _hydrateCachedStatus(forceRefresh: true);
    _isInitialized = true;
  }

  static Future<SubscriptionStatus> getSubscriptionStatus({
    bool forceRefresh = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _hydrateCachedStatus(forceRefresh: forceRefresh);
    return _cachedStatus ?? SubscriptionStatus.free();
  }

  static Future<List<MockPackage>> getOfferings() async {
    // In lieu of RevenueCat offerings we surface mocked metadata so the UI can
    // render a pricing table while relying on Stripe Checkout for fulfillment.
    return [
      MockPackage(
        identifier: premiumMonthlyId,
        title: 'Crystal Premium',
        description: '5 IDs/day · Collection sync · Ad-free rituals',
        price: '\$8.99',
        isLifetime: false,
      ),
      MockPackage(
        identifier: proMonthlyId,
        title: 'Crystal Pro',
        description: '20 IDs/day · AI guidance · Pro rituals',
        price: '\$19.99',
        isLifetime: false,
      ),
      MockPackage(
        identifier: foundersLifetimeId,
        title: 'Founders Lifetime',
        description: 'Unlimited access · Beta features · Founders badge',
        price: '\$499.00',
        isLifetime: true,
      ),
    ];
  }

  static Future<PurchaseResult> purchasePremium() async {
    return _startCheckout(premiumMonthlyId, 'premium');
  }

  static Future<PurchaseResult> purchasePro() async {
    return _startCheckout(proMonthlyId, 'pro');
  }

  static Future<PurchaseResult> purchaseFounders() async {
    return _startCheckout(foundersLifetimeId, 'founders');
  }

  static Future<SubscriptionStatus> confirmWebCheckout(String sessionId) async {
    if (sessionId.isEmpty) {
      throw Exception('Missing checkout session identifier.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to verify subscriptions.');
    }

    try {
      final callable =
          _functions.httpsCallable('finalizeStripeCheckoutSession');
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
    final user = _auth.currentUser;
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
    final user = _auth.currentUser;
    if (user == null) {
      return const PurchaseResult(
        success: false,
        error: 'You must be signed in to start a subscription.',
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
      final callable = _functions.httpsCallable('createStripeCheckoutSession');
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

    final user = _auth.currentUser;
    if (user == null) {
      _cachedStatus = SubscriptionStatus.free();
      return;
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      if (!snapshot.exists) {
        _cachedStatus = SubscriptionStatus.free();
        return;
      }

      final data = snapshot.data();
      final profile = data != null && data['profile'] is Map
          ? Map<String, dynamic>.from(data['profile'] as Map)
          : <String, dynamic>{};
      final status = SubscriptionStatus.fromProfile(profile);
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
    final user = _auth.currentUser;
    if (user == null) return;

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

    await _firestore.collection('users').doc(user.uid).set({
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

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plan')
        .doc('active')
        .set(planPayload, SetOptions(merge: true));
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
  final String title;
  final String description;
  final String price;
  final bool isLifetime;

  const MockPackage({
    required this.identifier,
    required this.title,
    required this.description,
    required this.price,
    required this.isLifetime,
  });
}
