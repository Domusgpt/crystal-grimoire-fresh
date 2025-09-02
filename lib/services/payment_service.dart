import 'dart:async';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

class PaymentService {
  static const String _revenueCatApiKey = 'YOUR_REVENUECAT_API_KEY'; // TODO: Replace with actual key
  static const String _entitlementIdPremium = 'premium';
  static const String _entitlementIdPro = 'pro';
  static const String _entitlementIdFounders = 'founders';
  
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Subscription products
  static const String premiumMonthlyId = 'crystal_premium_monthly';
  static const String proMonthlyId = 'crystal_pro_monthly';
  static const String foundersLifetimeId = 'crystal_founders_lifetime';
  
  // Initialize RevenueCat
  static Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug);
    
    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_revenueCatApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_revenueCatApiKey);
    } else {
      // Web platform - skip initialization
      return;
    }
    
    await Purchases.configure(configuration);
    
    // Set user ID if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await Purchases.logIn(user.uid);
    }
    
    // Listen to customer info updates
    Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
  }
  
  // Get current subscription status
  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
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
  static Future<List<Package>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current == null) {
        return [];
      }
      
      return offerings.current!.availablePackages;
    } catch (e) {
      print('Error fetching offerings: $e');
      return [];
    }
  }
  
  // Purchase premium subscription
  static Future<PurchaseResult> purchasePremium() async {
    return await _purchaseProduct(premiumMonthlyId);
  }
  
  // Purchase pro subscription
  static Future<PurchaseResult> purchasePro() async {
    return await _purchaseProduct(proMonthlyId);
  }
  
  // Purchase founders lifetime
  static Future<PurchaseResult> purchaseFounders() async {
    return await _purchaseProduct(foundersLifetimeId);
  }
  
  // Restore purchases
  static Future<bool> restorePurchases() async {
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
  
  // Cancel subscription
  static Future<void> cancelSubscription() async {
    // RevenueCat doesn't handle cancellation directly
    // Users need to manage subscriptions through platform stores
    throw Exception('Please manage your subscription through the App Store or Google Play Store');
  }
  
  // Private helper methods
  static Future<PurchaseResult> _purchaseProduct(String productId) async {
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
      String errorMessage;
      switch (e) {
        case PurchasesErrorCode.purchaseCancelledError:
          errorMessage = 'Purchase cancelled';
          break;
        case PurchasesErrorCode.purchaseNotAllowedError:
          errorMessage = 'Purchase not allowed';
          break;
        case PurchasesErrorCode.purchaseInvalidError:
          errorMessage = 'Invalid purchase';
          break;
        case PurchasesErrorCode.productNotAvailableForPurchaseError:
          errorMessage = 'Product not available';
          break;
        case PurchasesErrorCode.productAlreadyPurchasedError:
          errorMessage = 'Already purchased';
          break;
        case PurchasesErrorCode.networkError:
          errorMessage = 'Network error';
          break;
        default:
          errorMessage = 'Purchase failed';
      }
      
      return PurchaseResult(
        success: false,
        error: errorMessage,
      );
    } catch (e) {
      return PurchaseResult(
        success: false,
        error: 'Unexpected error: $e',
      );
    }
  }
  
  static Future<void> _handleCustomerInfoUpdate(CustomerInfo customerInfo) async {
    // Determine subscription tier
    String tier = 'free';
    if (customerInfo.entitlements.all[_entitlementIdFounders]?.isActive == true) {
      tier = 'founders';
    } else if (customerInfo.entitlements.all[_entitlementIdPro]?.isActive == true) {
      tier = 'pro';
    } else if (customerInfo.entitlements.all[_entitlementIdPremium]?.isActive == true) {
      tier = 'premium';
    }
    
    // Update local storage
    await StorageService.saveSubscriptionTier(tier);
    
    // Update Firebase
    await _updateFirebaseSubscription(customerInfo);
  }
  
  static Future<void> _updateFirebaseSubscription(CustomerInfo customerInfo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    String tier = 'free';
    String? expiresAt;
    bool willRenew = false;
    
    if (customerInfo.entitlements.all[_entitlementIdFounders]?.isActive == true) {
      tier = 'founders';
    } else if (customerInfo.entitlements.all[_entitlementIdPro]?.isActive == true) {
      tier = 'pro';
      final entitlement = customerInfo.entitlements.all[_entitlementIdPro]!;
      expiresAt = entitlement.expirationDate;
      willRenew = !entitlement.willRenew;
    } else if (customerInfo.entitlements.all[_entitlementIdPremium]?.isActive == true) {
      tier = 'premium';
      final entitlement = customerInfo.entitlements.all[_entitlementIdPremium]!;
      expiresAt = entitlement.expirationDate;
      willRenew = !entitlement.willRenew;
    }
    
    // Update user document
    await _firestore.collection('users').doc(user.uid).update({
      'subscriptionTier': tier,
      'subscriptionStatus': tier == 'free' ? 'inactive' : 'active',
      'subscriptionExpiresAt': expiresAt,
      'subscriptionWillRenew': willRenew,
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
}

class PurchaseResult {
  final bool success;
  final String? error;
  final CustomerInfo? customerInfo;
  
  PurchaseResult({
    required this.success,
    this.error,
    this.customerInfo,
  });
}