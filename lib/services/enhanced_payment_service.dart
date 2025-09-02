import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

class EnhancedPaymentService {
  static const String _revenueCatApiKey = 'YOUR_REVENUECAT_API_KEY'; // TODO: Replace with actual key
  static const String _entitlementIdPremium = 'premium';
  static const String _entitlementIdPro = 'pro';
  static const String _entitlementIdFounders = 'founders';
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _isInitialized = false;
  static bool _isWebPlatform = kIsWeb;
  
  // Subscription products
  static const String premiumMonthlyId = 'crystal_premium_monthly';
  static const String proMonthlyId = 'crystal_pro_monthly';
  static const String foundersLifetimeId = 'crystal_founders_lifetime';
  
  // Mock subscription status for web
  static SubscriptionStatus? _webMockStatus;
  
  // Initialize payment service (with web platform support)
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      if (_isWebPlatform) {
        print('Web platform detected - using mock payment system');
        await _initializeWebMock();
      } else {
        await _initializeRevenueCat();
      }
      _isInitialized = true;
    } catch (e) {
      print('Payment service initialization failed: $e');
      // Fallback to mock mode
      await _initializeWebMock();
      _isInitialized = true;
    }
  }
  
  static Future<void> _initializeRevenueCat() async {
    await Purchases.setLogLevel(LogLevel.debug);
    
    PurchasesConfiguration configuration = PurchasesConfiguration(_revenueCatApiKey);
    await Purchases.configure(configuration);
    
    // Set user ID if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await Purchases.logIn(user.uid);
    }
    
    // Listen to customer info updates
    Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
  }
  
  static Future<void> _initializeWebMock() async {
    // Initialize with free tier for web
    _webMockStatus = SubscriptionStatus(
      tier: 'free',
      isActive: false,
      expiresAt: null,
      willRenew: false,
    );
    
    // Check if user has a stored subscription (for testing)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _webMockStatus = SubscriptionStatus(
            tier: data['subscriptionTier'] ?? 'free',
            isActive: data['subscriptionStatus'] == 'active',
            expiresAt: data['subscriptionExpiresAt'],
            willRenew: data['subscriptionWillRenew'] ?? false,
          );
        }
      } catch (e) {
        print('Failed to load web subscription status: $e');
      }
    }
  }
  
  // Get current subscription status
  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isWebPlatform) {
      return _webMockStatus ?? SubscriptionStatus(
        tier: 'free',
        isActive: false,
        expiresAt: null,
        willRenew: false,
      );
    }
    
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _parseCustomerInfo(customerInfo);
    } catch (e) {
      // Fallback to stored value if RevenueCat fails
      final storedTier = await StorageService.getSubscriptionTier();
      return SubscriptionStatus(
        tier: storedTier,
        isActive: storedTier != 'free',
        expiresAt: null,
        willRenew: false,
      );
    }
  }
  
  // Get available packages
  static Future<List<MockPackage>> getOfferings() async {
    if (_isWebPlatform) {
      return _getWebMockOfferings();
    }
    
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        return _getWebMockOfferings();
      }
      
      return offerings.current!.availablePackages.map((package) => 
        MockPackage(
          identifier: package.storeProduct.identifier,
          title: package.storeProduct.title,
          description: package.storeProduct.description,
          price: package.storeProduct.priceString,
          isLifetime: package.packageType == PackageType.lifetime,
        )
      ).toList();
    } catch (e) {
      print('Error fetching offerings: $e');
      return _getWebMockOfferings();
    }
  }
  
  static List<MockPackage> _getWebMockOfferings() {
    return [
      MockPackage(
        identifier: premiumMonthlyId,
        title: 'Crystal Premium',
        description: '5 IDs/day + Collection + Ad-free',
        price: '\$8.99',
        isLifetime: false,
      ),
      MockPackage(
        identifier: proMonthlyId,
        title: 'Crystal Pro',
        description: '20 IDs/day + AI Guidance + Premium features',
        price: '\$19.99',
        isLifetime: false,
      ),
      MockPackage(
        identifier: foundersLifetimeId,
        title: 'Founders Lifetime',
        description: 'Unlimited everything + Beta access',
        price: '\$499.00',
        isLifetime: true,
      ),
    ];
  }
  
  // Purchase premium subscription
  static Future<PurchaseResult> purchasePremium() async {
    return await _purchaseProduct(premiumMonthlyId, 'premium');
  }
  
  // Purchase pro subscription
  static Future<PurchaseResult> purchasePro() async {
    return await _purchaseProduct(proMonthlyId, 'pro');
  }
  
  // Purchase founders lifetime
  static Future<PurchaseResult> purchaseFounders() async {
    return await _purchaseProduct(foundersLifetimeId, 'founders');
  }
  
  // Restore purchases
  static Future<bool> restorePurchases() async {
    if (_isWebPlatform) {
      // For web, try to restore from Firebase
      return await _restoreWebPurchases();
    }
    
    try {
      final customerInfo = await Purchases.restorePurchases();
      
      // Check if any entitlements are active
      final hasActiveSubscription = customerInfo.entitlements.all.values
          .any((entitlement) => entitlement.isActive);
      
      if (hasActiveSubscription) {
        await _handleCustomerInfoUpdate(customerInfo);
      }
      
      return hasActiveSubscription;
    } catch (e) {
      print('Error restoring purchases: $e');
      return false;
    }
  }
  
  static Future<bool> _restoreWebPurchases() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final tier = data['subscriptionTier'] ?? 'free';
        
        if (tier != 'free') {
          _webMockStatus = SubscriptionStatus(
            tier: tier,
            isActive: data['subscriptionStatus'] == 'active',
            expiresAt: data['subscriptionExpiresAt'],
            willRenew: data['subscriptionWillRenew'] ?? false,
          );
          
          await StorageService.saveSubscriptionTier(tier);
          return true;
        }
      }
    } catch (e) {
      print('Error restoring web purchases: $e');
    }
    
    return false;
  }
  
  // Cancel subscription
  static Future<void> cancelSubscription() async {
    if (_isWebPlatform) {
      throw Exception('Web subscriptions are managed through the admin panel');
    }
    
    // RevenueCat doesn't handle cancellation directly
    // Users need to manage subscriptions through platform stores
    throw Exception('Please manage your subscription through the App Store or Google Play Store');
  }
  
  // Enable founders account (for development/testing)
  static Future<void> enableFoundersAccountForTesting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    _webMockStatus = SubscriptionStatus(
      tier: 'founders',
      isActive: true,
      expiresAt: null,
      willRenew: false,
    );
    
    await StorageService.saveSubscriptionTier('founders');
    
    // Update Firebase
    await _firestore.collection('users').doc(user.uid).set({
      'subscriptionTier': 'founders',
      'subscriptionStatus': 'active',
      'subscriptionExpiresAt': null,
      'subscriptionWillRenew': false,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      'isDevelopmentAccount': true,
    }, SetOptions(merge: true));
  }
  
  // Private helper methods
  static Future<PurchaseResult> _purchaseProduct(String productId, String tier) async {
    if (_isWebPlatform) {
      return await _handleWebPurchase(productId, tier);
    }
    
    try {
      // Get offerings
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        return PurchaseResult(
          success: false,
          error: 'No offerings available',
        );
      }
      
      // Find the package
      Package? package;
      for (final p in offerings.current!.availablePackages) {
        if (p.storeProduct.identifier == productId) {
          package = p;
          break;
        }
      }
      
      if (package == null) {
        return PurchaseResult(
          success: false,
          error: 'Product not found',
        );
      }
      
      // Make the purchase
      final purchaseResult = await Purchases.purchasePackage(package);
      
      // Update Firebase
      await _updateFirebaseSubscription(purchaseResult);
      
      return PurchaseResult(
        success: true,
        customerInfo: purchaseResult,
      );
    } on PurchasesErrorCode catch (e) {
      return PurchaseResult(
        success: false,
        error: _mapPurchaseError(e),
      );
    } catch (e) {
      return PurchaseResult(
        success: false,
        error: 'Unexpected error: $e',
      );
    }
  }
  
  static Future<PurchaseResult> _handleWebPurchase(String productId, String tier) async {
    // For web platform, show a modal directing to external payment
    // This is a simplified implementation - in production you'd integrate with Stripe or similar
    
    return PurchaseResult(
      success: false,
      error: 'Web purchases coming soon! Please download the mobile app to subscribe.',
      isWebPlatform: true,
      redirectUrl: 'https://your-stripe-checkout-url.com',
    );
  }
  
  static String _mapPurchaseError(PurchasesErrorCode error) {
    switch (error) {
      case PurchasesErrorCode.purchaseCancelledError:
        return 'Purchase cancelled';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchase not allowed';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'Invalid purchase';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'Product not available';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'Already purchased';
      case PurchasesErrorCode.networkError:
        return 'Network error';
      default:
        return 'Purchase failed';
    }
  }
  
  static SubscriptionStatus _parseCustomerInfo(CustomerInfo customerInfo) {
    if (customerInfo.entitlements.all[_entitlementIdFounders]?.isActive == true) {
      return SubscriptionStatus(
        tier: 'founders',
        isActive: true,
        expiresAt: null, // Lifetime
        willRenew: false,
      );
    } else if (customerInfo.entitlements.all[_entitlementIdPro]?.isActive == true) {
      final entitlement = customerInfo.entitlements.all[_entitlementIdPro]!;
      return SubscriptionStatus(
        tier: 'pro',
        isActive: true,
        expiresAt: entitlement.expirationDate,
        willRenew: !entitlement.willRenew,
      );
    } else if (customerInfo.entitlements.all[_entitlementIdPremium]?.isActive == true) {
      final entitlement = customerInfo.entitlements.all[_entitlementIdPremium]!;
      return SubscriptionStatus(
        tier: 'premium',
        isActive: true,
        expiresAt: entitlement.expirationDate,
        willRenew: !entitlement.willRenew,
      );
    } else {
      return SubscriptionStatus(
        tier: 'free',
        isActive: false,
        expiresAt: null,
        willRenew: false,
      );
    }
  }
  
  static Future<void> _handleCustomerInfoUpdate(CustomerInfo customerInfo) async {
    final status = _parseCustomerInfo(customerInfo);
    
    // Update local storage
    await StorageService.saveSubscriptionTier(status.tier);
    
    // Update Firebase
    await _updateFirebaseSubscription(customerInfo);
  }
  
  static Future<void> _updateFirebaseSubscription(CustomerInfo customerInfo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final status = _parseCustomerInfo(customerInfo);
    
    // Update user document
    await _firestore.collection('users').doc(user.uid).update({
      'subscriptionTier': status.tier,
      'subscriptionStatus': status.isActive ? 'active' : 'inactive',
      'subscriptionExpiresAt': status.expiresAt,
      'subscriptionWillRenew': status.willRenew,
      'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
    });
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
  
  @override
  String toString() {
    return 'SubscriptionStatus(tier: $tier, active: $isActive, expires: $expiresAt)';
  }
}

class PurchaseResult {
  final bool success;
  final String? error;
  final CustomerInfo? customerInfo;
  final bool isWebPlatform;
  final String? redirectUrl;
  
  PurchaseResult({
    required this.success,
    this.error,
    this.customerInfo,
    this.isWebPlatform = false,
    this.redirectUrl,
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