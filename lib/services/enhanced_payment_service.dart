import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../config/plan_entitlements.dart';
import 'environment_config.dart';
import 'storage_service.dart';

/// Stripe Checkout orchestrator used by the subscription screen.
///
/// The previous implementation relied on the `purchases_flutter` package and
/// native RevenueCat SDK calls. Those imports prevented the Flutter project
/// from compiling because the dependencies were never added to `pubspec.yaml`.
/// The rewritten service keeps the same public API but routes everything
/// through Firebase Authentication, Firestore, and callable Cloud Functions.
///
/// Key changes:
/// * No third-party in-app purchase plugins are required to compile.
/// * Web and desktop platforms use Stripe Checkout URLs returned by
///   `createStripeCheckoutSession`.
/// * Subscription status is resolved from Firestore (written by
///   `finalizeStripeCheckoutSession`) so the UI reflects the backend source of
///   truth.
class EnhancedPaymentService {
  EnhancedPaymentService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static bool _isInitialized = false;
  static SubscriptionStatus? _cachedStatus;

  static EnvironmentConfig get _config => EnvironmentConfig.instance;
  static bool get _isWeb => kIsWeb;

  static String get premiumMonthlyId => _config.stripePremiumPriceId.isNotEmpty
      ? _config.stripePremiumPriceId
      : 'crystal_premium_monthly';

  static String get proMonthlyId => _config.stripeProPriceId.isNotEmpty
      ? _config.stripeProPriceId
      : 'crystal_pro_monthly';

  static String get foundersLifetimeId =>
      _config.stripeFoundersPriceId.isNotEmpty
          ? _config.stripeFoundersPriceId
          : 'crystal_founders_lifetime';

  /// Initialize any cached state. The method is retained for API parity even
  /// though the web implementation has no heavy setup cost.
  static Future<void> initialize() async {
    if (_isInitialized) return;
    // Prime the cache with the stored subscription tier if available so the UI
    // can show the most recent known state before Firestore loads.
    final storedTier = await StorageService.getSubscriptionTier();
    if (storedTier.isNotEmpty) {
      _cachedStatus = SubscriptionStatus(
        tier: storedTier,
        isActive: storedTier != 'free',
        expiresAt: null,
        willRenew: storedTier == 'premium' || storedTier == 'pro',
      );
    }
    _isInitialized = true;
  }

  /// Retrieve the packages we surface on the paywall.
  static Future<List<MockPackage>> getOfferings() async {
    await initialize();
    final plans = <MockPackage>[
      MockPackage(
        identifier: premiumMonthlyId,
        title: 'Crystal Premium',
        description:
            'Unlock guided rituals, extended crystal IDs, and a larger collection.',
        price: '\$8.99',
        isLifetime: false,
      ),
      MockPackage(
        identifier: proMonthlyId,
        title: 'Crystal Pro',
        description:
            'Advanced AI guidance, 40 IDs/day, and professional healer tools.',
        price: '\$19.99',
        isLifetime: false,
      ),
      MockPackage(
        identifier: foundersLifetimeId,
        title: 'Founders Lifetime',
        description:
            'Lifetime access to every feature, future drops, and founders badge.',
        price: '\$499.00',
        isLifetime: true,
      ),
    ];
    return plans;
  }

  /// Resolve the user's subscription status from Firestore (written by backend
  /// Functions). Falls back to the cached tier for quick UI feedback.
  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    await initialize();
    final firestoreStatus = await _loadStatusFromFirestore();
    if (firestoreStatus != null) {
      await _cacheStatus(firestoreStatus);
      return firestoreStatus;
    }
    return _cachedStatus ?? SubscriptionStatus.free();
  }

  static Future<SubscriptionStatus?> _loadStatusFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      return SubscriptionStatus.free();
    }

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      if (!snapshot.exists) {
        return SubscriptionStatus.free();
      }

      final data = snapshot.data() ?? const <String, dynamic>{};
      final profile = data['profile'];
      if (profile is! Map) {
        return SubscriptionStatus.free();
      }

      final tier = (profile['subscriptionTier'] ?? 'free').toString();
      final status = (profile['subscriptionStatus'] ?? 'inactive').toString();
      final expiresAt = _coerceExpiresAt(profile['subscriptionExpiresAt']);
      final willRenew = profile['subscriptionWillRenew'] == true;

      return SubscriptionStatus(
        tier: tier,
        isActive: status.toLowerCase() == 'active',
        expiresAt: expiresAt,
        willRenew: willRenew,
      );
    } catch (error) {
      debugPrint('Failed to load subscription from Firestore: $error');
      return null;
    }
  }

  /// Start Stripe Checkout for the requested tier.
  static Future<PurchaseResult> purchasePremium() async {
    return _startCheckout(premiumMonthlyId, 'premium');
  }

  static Future<PurchaseResult> purchasePro() async {
    return _startCheckout(proMonthlyId, 'pro');
  }

  static Future<PurchaseResult> purchaseFounders() async {
    return _startCheckout(foundersLifetimeId, 'founders');
  }

  static Future<PurchaseResult> _startCheckout(
    String priceId,
    String tier,
  ) async {
    await initialize();

    final user = _auth.currentUser;
    if (user == null) {
      return PurchaseResult(
        success: false,
        error: 'You must be signed in to purchase a subscription.',
        isWebPlatform: _isWeb,
      );
    }

    if (priceId.isEmpty) {
      return PurchaseResult(
        success: false,
        error:
            'Stripe price ID for the $tier plan is not configured. Set STRIPE_${tier.toUpperCase()}_PRICE_ID.',
        isWebPlatform: _isWeb,
      );
    }

    try {
      final urls = _buildWebCheckoutUrls();
      final callable =
          _functions.httpsCallable('createStripeCheckoutSession');
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
        return PurchaseResult(
          success: false,
          error: 'Unable to start checkout. Please try again shortly.',
          isWebPlatform: _isWeb,
        );
      }

      return PurchaseResult(
        success: true,
        isWebPlatform: true,
        redirectUrl: checkoutUrl,
        webSessionId: sessionId,
      );
    } on FirebaseFunctionsException catch (error) {
      return PurchaseResult(
        success: false,
        error: error.message ?? error.code,
        isWebPlatform: _isWeb,
      );
    } catch (error) {
      return PurchaseResult(
        success: false,
        error: 'Checkout failed: $error',
        isWebPlatform: _isWeb,
      );
    }
  }

  static Map<String, String> _buildWebCheckoutUrls() {
    final base = Uri.base;
    final origin = base.hasAuthority ? base.origin : _config.websiteUrl;
    final successUrl =
        '$origin/#/subscription?session_id={CHECKOUT_SESSION_ID}';
    final cancelUrl = '$origin/#/subscription?cancelled=true';
    return {'success': successUrl, 'cancel': cancelUrl};
  }

  /// After the user returns from Stripe we need to confirm the session so the
  /// backend can finalise entitlements.
  static Future<SubscriptionStatus> confirmWebCheckout(String sessionId) async {
    if (sessionId.isEmpty) {
      throw Exception('Missing checkout session identifier.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in again to verify your subscription.');
    }

    try {
      final callable =
          _functions.httpsCallable('finalizeStripeCheckoutSession');
      final response = await callable.call({'sessionId': sessionId});
      final data = Map<String, dynamic>.from(response.data as Map);
      final tier = (data['plan'] ?? data['tier'] ?? 'free').toString();

      final status = SubscriptionStatus(
        tier: tier,
        isActive: data['isActive'] == true,
        expiresAt: _coerceExpiresAt(data['expiresAt']),
        willRenew: data['willRenew'] == true,
      );

      await _cacheStatus(status);
      return status;
    } on FirebaseFunctionsException catch (error) {
      throw Exception(error.message ?? error.code);
    } catch (error) {
      throw Exception('Failed to verify checkout: $error');
    }
  }

  /// Restore subscriptions by reloading the Firestore profile state.
  static Future<bool> restorePurchases() async {
    final status = await _loadStatusFromFirestore();
    if (status == null) {
      return false;
    }

    await _cacheStatus(status);
    return status.isActive && status.tier != 'free';
  }

  /// Grant founders tier without Stripe for development smoke tests.
  static Future<void> enableFoundersAccountForTesting() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final details = PlanEntitlements.resolve('founders');
    final payload = {
      'subscriptionTier': 'founders',
      'subscriptionStatus': 'active',
      'subscriptionProvider': 'manual',
      'subscriptionWillRenew': false,
      'subscriptionBillingTier': 'founders',
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      'effectiveLimits': details.effectiveLimits,
    };

    await _firestore.collection('users').doc(user.uid).set({
      'profile': payload,
    }, SetOptions(merge: true));

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plan')
        .doc('active')
        .set({
      'plan': 'founders',
      'billingTier': 'founders',
      'provider': 'manual',
      'effectiveLimits': details.effectiveLimits,
      'flags': details.flags,
      'willRenew': false,
      'lifetime': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final status = SubscriptionStatus(
      tier: 'founders',
      isActive: true,
      expiresAt: null,
      willRenew: false,
    );
    await _cacheStatus(status);
  }

  static Future<void> _cacheStatus(SubscriptionStatus status) async {
    _cachedStatus = status;
    await StorageService.saveSubscriptionTier(status.tier);
  }

  static String? _coerceExpiresAt(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000,
              isUtc: true)
          .toIso8601String();
    }
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toIso8601String() ?? value.toString();
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

  factory SubscriptionStatus.free() => const SubscriptionStatus(
        tier: 'free',
        isActive: false,
        expiresAt: null,
        willRenew: false,
      );

  @override
  String toString() =>
      'SubscriptionStatus(tier: $tier, active: $isActive, expires: $expiresAt)';
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
