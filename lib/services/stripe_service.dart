import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import 'environment_config.dart';
import 'firebase_service.dart';

/// Production Stripe Payment Service - REAL PAYMENT PROCESSING
/// This handles actual payments, subscriptions, and revenue
class StripeService {
  final EnvironmentConfig _config;
  final FirebaseService _firebaseService;
  
  StripeService({
    EnvironmentConfig? config,
    required FirebaseService firebaseService,
  }) : _config = config ?? EnvironmentConfig(),
       _firebaseService = firebaseService;
  
  // Stripe API endpoints
  static const String _baseUrl = 'https://api.stripe.com/v1';
  
  // Real Product Price IDs from Stripe Dashboard
  static const Map<SubscriptionTier, String> _priceIds = {
    SubscriptionTier.premium: 'price_1RWLUuP7RjgzZkITg22yi41w',  // $9.99/month
    SubscriptionTier.pro: 'price_1RWLUvP7RjgzZkITm0kK5iJA',      // $19.99/month
    SubscriptionTier.founders: 'price_1RWLUvP7RjgzZkITCigXVDcH',  // $199 one-time
  };
  
  /// Check if Stripe is configured
  bool get isConfigured => _config.stripePublishableKey.isNotEmpty;
  
  /// Create payment intent for subscription
  Future<Map<String, dynamic>> createSubscriptionPaymentIntent({
    required SubscriptionTier tier,
    required String customerEmail,
  }) async {
    if (!isConfigured) {
      throw StripeException('Stripe not configured - missing API keys');
    }
    
    if (!_firebaseService.isAuthenticated) {
      throw StripeException('User must be authenticated to purchase subscription');
    }
    
    try {
      // Create or get customer
      final customer = await _createOrGetCustomer(customerEmail);
      
      // Create subscription or payment intent based on tier
      if (tier == SubscriptionTier.founders) {
        // One-time payment for founders
        return await _createOneTimePaymentIntent(
          amount: 19900, // $199.00
          currency: 'usd',
          customerId: customer['id'],
          description: 'Crystal Grimoire Founders Edition - Lifetime Access',
        );
      } else {
        // Recurring subscription
        return await _createSubscription(
          customerId: customer['id'],
          priceId: _priceIds[tier]!,
          tier: tier,
        );
      }
    } catch (e) {
      throw StripeException('Failed to create payment: $e');
    }
  }
  
  /// Create or get existing Stripe customer
  Future<Map<String, dynamic>> _createOrGetCustomer(String email) async {
    // First, try to find existing customer
    final searchResponse = await http.get(
      Uri.parse('$_baseUrl/customers?email=$email'),
      headers: {
        'Authorization': 'Bearer ${_config.stripeSecretKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );
    
    if (searchResponse.statusCode == 200) {
      final searchData = jsonDecode(searchResponse.body);
      if (searchData['data'].isNotEmpty) {
        return searchData['data'][0]; // Return existing customer
      }
    }
    
    // Create new customer
    final createResponse = await http.post(
      Uri.parse('$_baseUrl/customers'),
      headers: {
        'Authorization': 'Bearer ${_config.stripeSecretKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'email': email,
        'description': 'Crystal Grimoire User',
        'metadata[firebase_user_id]': _firebaseService.currentUserId ?? '',
      },
    );
    
    if (createResponse.statusCode == 200) {
      return jsonDecode(createResponse.body);
    } else {
      throw StripeException('Failed to create customer: ${createResponse.body}');
    }
  }
  
  /// Create one-time payment intent (for Founders tier)
  Future<Map<String, dynamic>> _createOneTimePaymentIntent({
    required int amount,
    required String currency,
    required String customerId,
    required String description,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payment_intents'),
      headers: {
        'Authorization': 'Bearer ${_config.stripeSecretKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'amount': amount.toString(),
        'currency': currency,
        'customer': customerId,
        'description': description,
        'metadata[subscription_tier]': 'founders',
        'metadata[firebase_user_id]': _firebaseService.currentUserId ?? '',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw StripeException('Failed to create payment intent: ${response.body}');
    }
  }
  
  /// Create recurring subscription
  Future<Map<String, dynamic>> _createSubscription({
    required String customerId,
    required String priceId,
    required SubscriptionTier tier,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/subscriptions'),
      headers: {
        'Authorization': 'Bearer ${_config.stripeSecretKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'customer': customerId,
        'items[0][price]': priceId,
        'payment_behavior': 'default_incomplete',
        'payment_settings[save_default_payment_method]': 'on_subscription',
        'expand[]': 'latest_invoice.payment_intent',
        'metadata[subscription_tier]': tier.name,
        'metadata[firebase_user_id]': _firebaseService.currentUserId ?? '',
      },
    );
    
    if (response.statusCode == 200) {
      final subscription = jsonDecode(response.body);
      return {
        'subscription_id': subscription['id'],
        'client_secret': subscription['latest_invoice']['payment_intent']['client_secret'],
        'status': subscription['status'],
      };
    } else {
      throw StripeException('Failed to create subscription: ${response.body}');
    }
  }
  
  /// Confirm payment and upgrade user
  Future<void> confirmPaymentAndUpgrade({
    required String paymentIntentId,
    required SubscriptionTier tier,
  }) async {
    try {
      // Verify payment with Stripe
      final paymentIntent = await _getPaymentIntent(paymentIntentId);
      
      if (paymentIntent['status'] == 'succeeded') {
        // Update user's subscription tier in Firebase
        await _firebaseService.updateSubscriptionTier(tier);
        
        // Log successful payment
        print('Payment successful: User upgraded to ${tier.name}');
      } else {
        throw StripeException('Payment not completed: ${paymentIntent['status']}');
      }
    } catch (e) {
      throw StripeException('Failed to confirm payment: $e');
    }
  }
  
  /// Get payment intent status
  Future<Map<String, dynamic>> _getPaymentIntent(String paymentIntentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/payment_intents/$paymentIntentId'),
      headers: {
        'Authorization': 'Bearer ${_config.stripeSecretKey}',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw StripeException('Failed to get payment intent: ${response.body}');
    }
  }
  
  /// Cancel subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/subscriptions/$subscriptionId'),
      headers: {
        'Authorization': 'Bearer ${_config.stripeSecretKey}',
      },
    );
    
    if (response.statusCode == 200) {
      // Downgrade user to free tier
      await _firebaseService.updateSubscriptionTier(SubscriptionTier.free);
    } else {
      throw StripeException('Failed to cancel subscription: ${response.body}');
    }
  }
  
  /// Get customer's active subscriptions
  Future<List<Map<String, dynamic>>> getActiveSubscriptions(String customerEmail) async {
    final customer = await _createOrGetCustomer(customerEmail);
    
    final response = await http.get(
      Uri.parse('$_baseUrl/subscriptions?customer=${customer['id']}&status=active'),
      headers: {
        'Authorization': 'Bearer ${_config.stripeSecretKey}',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } else {
      throw StripeException('Failed to get subscriptions: ${response.body}');
    }
  }
  
  /// Handle webhook events (for subscription updates)
  Future<void> handleWebhookEvent(Map<String, dynamic> event) async {
    final eventType = event['type'];
    final data = event['data']['object'];
    
    switch (eventType) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
        await _handleSubscriptionChange(data);
        break;
        
      case 'customer.subscription.deleted':
        await _handleSubscriptionCancellation(data);
        break;
        
      case 'invoice.payment_succeeded':
        await _handlePaymentSuccess(data);
        break;
        
      case 'invoice.payment_failed':
        await _handlePaymentFailure(data);
        break;
    }
  }
  
  /// Handle subscription changes from webhooks
  Future<void> _handleSubscriptionChange(Map<String, dynamic> subscription) async {
    final firebaseUserId = subscription['metadata']['firebase_user_id'];
    final tierName = subscription['metadata']['subscription_tier'];
    
    if (firebaseUserId != null && tierName != null) {
      final tier = SubscriptionTier.values.firstWhere(
        (t) => t.name == tierName,
        orElse: () => SubscriptionTier.free,
      );
      
      // Update user's tier in Firebase
      // Note: This would require admin access to update any user
      print('Subscription updated: User $firebaseUserId -> ${tier.name}');
    }
  }
  
  /// Handle subscription cancellation
  Future<void> _handleSubscriptionCancellation(Map<String, dynamic> subscription) async {
    final firebaseUserId = subscription['metadata']['firebase_user_id'];
    
    if (firebaseUserId != null) {
      print('Subscription cancelled: User $firebaseUserId -> free');
    }
  }
  
  /// Handle successful payment
  Future<void> _handlePaymentSuccess(Map<String, dynamic> invoice) async {
    print('Payment succeeded: ${invoice['id']}');
  }
  
  /// Handle failed payment
  Future<void> _handlePaymentFailure(Map<String, dynamic> invoice) async {
    print('Payment failed: ${invoice['id']}');
  }
  
  /// Get subscription pricing information
  Map<SubscriptionTier, Map<String, dynamic>> getSubscriptionPricing() {
    return {
      SubscriptionTier.free: {
        'name': 'Free',
        'price': 0,
        'currency': 'USD',
        'interval': null,
        'features': [
          '5 Crystal IDs per day',
          'Basic Gemini AI responses',
          'Personal crystal collection',
          'Basic journal features',
        ],
      },
      SubscriptionTier.premium: {
        'name': 'Premium',
        'price': 999, // $9.99
        'currency': 'USD',
        'interval': 'month',
        'features': [
          '30 Crystal IDs per day',
          'Advanced AI with GPT-4',
          'Unlimited crystal collection',
          'Marketplace selling access',
          'Advanced journal features',
          'Moon ritual planning',
        ],
      },
      SubscriptionTier.pro: {
        'name': 'Pro',
        'price': 1999, // $19.99
        'currency': 'USD',
        'interval': 'month',
        'features': [
          'Unlimited Crystal IDs',
          'Premium AI with Claude Opus',
          'Priority marketplace placement',
          'Advanced analytics',
          'Birth chart integration',
          'Personalized daily guidance',
          'Priority customer support',
        ],
      },
      SubscriptionTier.founders: {
        'name': 'Founders Edition',
        'price': 19900, // $199.00
        'currency': 'USD',
        'interval': 'lifetime',
        'features': [
          'Lifetime access to all features',
          'Multi-model AI consensus',
          'Exclusive founder features',
          'Beta access to new features',
          'Direct founder support',
          'Founder badge and recognition',
          'Revenue sharing opportunities',
        ],
      },
    };
  }
  
  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'configured': isConfigured,
      'publishable_key_set': _config.stripePublishableKey.isNotEmpty,
      'secret_key_set': _config.stripeSecretKey.isNotEmpty,
      'firebase_connected': _firebaseService.isAuthenticated,
      'pricing_tiers': getSubscriptionPricing().length,
    };
  }
}

/// Exception for Stripe service errors
class StripeException implements Exception {
  final String message;
  StripeException(this.message);
  
  @override
  String toString() => 'StripeException: $message';
}