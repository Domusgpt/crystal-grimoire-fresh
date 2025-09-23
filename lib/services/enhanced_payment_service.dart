import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/plan_entitlements.dart';
import 'environment_config.dart';
import 'storage_service.dart';

class EnhancedPaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final EnvironmentConfig _config = EnvironmentConfig.instance;

  static bool _initialized = false;
  static SubscriptionStatus? _cachedStatus;

  static String get premiumMonthlyId =>
      _config.stripePremiumPriceId.isNotEmpty ? _config.stripePremiumPriceId : 'price_premium_monthly';
  static String get proMonthlyId =>
      _config.stripeProPriceId.isNotEmpty ? _config.stripeProPriceId : 'price_pro_monthly';
  static String get foundersLifetimeId =>
      _config.stripeFoundersPriceId.isNotEmpty ? _config.stripeFoundersPriceId : 'price_founders_lifetime';

  static Future<void> initialize() async {
    if (_initialized) return;
    // Reserved for future platform specific initialisation.
    _initialized = true;
  }

  static Future<List<MockPackage>> getOfferings() async {
    await initialize();

    return [
      MockPackage(
        identifier: premiumMonthlyId,
        title: 'Premium',
        description: 'Unlock extended identifications, dream analysis, and moon ritual guidance each month.',
        price: 'Stripe checkout',
        isLifetime: false,
      ),
      MockPackage(
        identifier: proMonthlyId,
        title: 'Pro',
        description: 'Priority AI sessions, deeper library access, and enhanced healing layouts.',
        price: 'Stripe checkout',
        isLifetime: false,
      ),
      MockPackage(
        identifier: foundersLifetimeId,
        title: 'Founders',
        description: 'Lifetime access to every feature, plus future expansion packs.',
        price: 'One-time',
        isLifetime: true,
      ),
    ];
  }

  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    await initialize();

    final user = _auth.currentUser;
    if (user == null) {
      final tier = await StorageService.getSubscriptionTier();
      return SubscriptionStatus(
        tier: tier,
        isActive: tier != 'free',
        expiresAt: null,
        willRenew: false,
      );
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('plan')
          .doc('active')
          .get();

      final planData = snapshot.data();
      if (planData != null) {
        await StorageService.savePlanSnapshot(planData);
      }

      final status = _statusFromPlan(planData);
      _cachedStatus = status;
      await StorageService.saveSubscriptionTier(status.tier);
      return status;
    } catch (error) {
      final fallbackTier = await StorageService.getSubscriptionTier();
      return _cachedStatus ??
          SubscriptionStatus(
            tier: fallbackTier,
            isActive: fallbackTier != 'free',
            expiresAt: null,
            willRenew: false,
          );
    }
  }

  static Future<PurchaseResult> purchasePremium() async {
    return _startStripeCheckout(premiumMonthlyId, 'premium');
  }

  static Future<PurchaseResult> purchasePro() async {
    return _startStripeCheckout(proMonthlyId, 'pro');
  }

  static Future<PurchaseResult> purchaseFounders() async {
    return _startStripeCheckout(foundersLifetimeId, 'founders');
  }

  static Future<SubscriptionStatus> confirmWebCheckout(String sessionId) async {
    if (sessionId.isEmpty) {
      throw Exception('Missing checkout session identifier.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to verify a subscription.');
    }

    final callable = _functions.httpsCallable('finalizeStripeCheckoutSession');
    final response = await callable.call({'sessionId': sessionId});
    final data = Map<String, dynamic>.from(response.data as Map);

    final status = SubscriptionStatus(
      tier: (data['plan'] as String? ?? data['tier'] as String? ?? 'free').toLowerCase(),
      isActive: data['isActive'] == true,
      expiresAt: data['expiresAt']?.toString(),
      willRenew: data['willRenew'] == true,
    );

    _cachedStatus = status;
    await StorageService.saveSubscriptionTier(status.tier);
    await _refreshPlanSnapshot();
    return status;
  }

  static Future<bool> restorePurchases() async {
    final status = await getSubscriptionStatus();
    return status.tier != 'free';
  }

  static Future<void> cancelSubscription() async {
    throw Exception('Manage cancellations from the Stripe customer portal or admin panel.');
  }

  static Future<void> enableFoundersAccountForTesting() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final limits = PlanEntitlements.effectiveLimits('founders');
    final payload = {
      'plan': 'founders',
      'billingTier': 'founders',
      'provider': 'manual',
      'effectiveLimits': limits,
      'flags': PlanEntitlements.flags('founders'),
      'willRenew': false,
      'lifetime': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(user.uid).set({
      'profile': {
        'subscriptionTier': 'founders',
        'subscriptionStatus': 'active',
        'subscriptionProvider': 'manual',
        'subscriptionWillRenew': false,
        'subscriptionExpiresAt': null,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
        'subscriptionBillingTier': 'founders',
        'effectiveLimits': limits,
      }
    }, SetOptions(merge: true));

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plan')
        .doc('active')
        .set(payload, SetOptions(merge: true));

    await StorageService.saveSubscriptionTier('founders');
    await StorageService.savePlanSnapshot(payload);

    _cachedStatus = SubscriptionStatus(
      tier: 'founders',
      isActive: true,
      expiresAt: null,
      willRenew: false,
    );
  }

  static Future<PurchaseResult> _startStripeCheckout(String priceId, String tier) async {
    final user = _auth.currentUser;
    if (user == null) {
      return PurchaseResult(
        success: false,
        error: 'Sign in to start a subscription checkout.',
        isWebPlatform: true,
      );
    }

    if (_config.stripePublishableKey.isEmpty) {
      return PurchaseResult(
        success: false,
        error: 'Stripe is not configured. Set STRIPE_PUBLISHABLE_KEY and price IDs.',
        isWebPlatform: true,
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
        return PurchaseResult(
          success: false,
          error: 'Checkout session could not be created.',
          isWebPlatform: true,
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
        isWebPlatform: true,
      );
    }
  }

  static Map<String, String> _buildWebCheckoutUrls() {
    final baseUri = Uri.base;
    final origin = baseUri.hasAuthority ? baseUri.origin : _config.websiteUrl;
    final successUrl = '$origin/#/subscription?session_id={CHECKOUT_SESSION_ID}';
    final cancelUrl = '$origin/#/subscription?cancelled=true';
    return {'success': successUrl, 'cancel': cancelUrl};
  }

  static SubscriptionStatus _statusFromPlan(Map<String, dynamic>? plan) {
    if (plan == null || plan.isEmpty) {
      return SubscriptionStatus(tier: 'free', isActive: false, expiresAt: null, willRenew: false);
    }

    final tier = (plan['plan'] ?? plan['billingTier'] ?? 'free').toString();
    final lifetime = plan['lifetime'] == true;
    final expiresAt = _timestampToIso(plan['expiresAt']);
    final willRenew = lifetime ? false : plan['willRenew'] == true;

    return SubscriptionStatus(
      tier: tier,
      isActive: tier != 'free',
      expiresAt: expiresAt,
      willRenew: willRenew,
    );
  }

  static Future<void> _refreshPlanSnapshot() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plan')
        .doc('active')
        .get();

    if (snapshot.exists) {
      final data = snapshot.data();
      if (data != null) {
        await StorageService.savePlanSnapshot(data);
        _cachedStatus = _statusFromPlan(data);
      }
    }
  }

  static String? _timestampToIso(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
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

  SubscriptionStatus({
    required this.tier,
    required this.isActive,
    this.expiresAt,
    required this.willRenew,
  });
}

class PurchaseResult {
  final bool success;
  final String? error;
  final bool isWebPlatform;
  final String? redirectUrl;
  final String? webSessionId;

  PurchaseResult({
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

  MockPackage({
    required this.identifier,
    required this.title,
    required this.description,
    required this.price,
    required this.isLifetime,
  });
}
