import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/enhanced_payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _errorMessage;
  List<MockPackage> _packages = [];
  SubscriptionStatus? _status;
  String? _pendingSessionId;
  bool _awaitingWebConfirmation = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
    _handleCheckoutReturn();
  }

  Future<void> _loadOfferings() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await EnhancedPaymentService.initialize();
      final offerings = await EnhancedPaymentService.getOfferings();
      final status = await EnhancedPaymentService.getSubscriptionStatus();

      if (!mounted) return;
      setState(() {
        _packages = offerings;
        _status = status;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load subscriptions: $e';
        _isLoading = false;
      });
    }
  }

  void _handleCheckoutReturn() {
    final sessionId = _extractSessionIdFromUri();
    final cancelled = _uriIndicatesCancellation();

    if (cancelled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checkout was cancelled. No charges were made.'),
            backgroundColor: Colors.orange,
          ),
        );
      });
    }

    if (sessionId != null) {
      setState(() {
        _pendingSessionId = sessionId;
        _awaitingWebConfirmation = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _confirmPendingCheckout(sessionId);
      });
    }
  }

  String? _extractSessionIdFromUri() {
    final querySession = Uri.base.queryParameters['session_id'];
    if (querySession != null && querySession.isNotEmpty) {
      return querySession;
    }

    final fragmentParams = _fragmentParameters();
    final fragmentSession = fragmentParams['session_id'];
    if (fragmentSession != null && fragmentSession.isNotEmpty) {
      return fragmentSession;
    }

    return null;
  }

  bool _uriIndicatesCancellation() {
    if (Uri.base.queryParameters['cancelled'] == 'true') {
      return true;
    }

    final fragmentParams = _fragmentParameters();
    return fragmentParams['cancelled'] == 'true';
  }

  Map<String, String> _fragmentParameters() {
    final fragment = Uri.base.fragment;
    final queryIndex = fragment.indexOf('?');
    if (queryIndex == -1) {
      return const {};
    }

    final queryString = fragment.substring(queryIndex + 1);
    try {
      return Uri.splitQueryString(queryString);
    } catch (_) {
      return const {};
    }
  }

  Future<void> _purchase(MockPackage package) async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      PurchaseResult result;
      if (package.identifier == EnhancedPaymentService.premiumMonthlyId) {
        result = await EnhancedPaymentService.purchasePremium();
      } else if (package.identifier == EnhancedPaymentService.proMonthlyId) {
        result = await EnhancedPaymentService.purchasePro();
      } else {
        result = await EnhancedPaymentService.purchaseFounders();
      }

      if (!mounted) return;

      if (result.success) {
        if (result.isWebPlatform) {
          if (result.redirectUrl != null) {
            await _launchCheckout(result.redirectUrl!, result.webSessionId);
          } else {
            setState(() {
              _pendingSessionId = result.webSessionId;
              _awaitingWebConfirmation = true;
            });
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Secure checkout opened in a new tab. Complete payment, then return to this page to refresh your access.'),
              backgroundColor: Colors.lightBlue,
            ),
          );
        } else {
          final status = await EnhancedPaymentService.getSubscriptionStatus();
          if (!mounted) return;
          setState(() {
            _status = status;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subscription activated: ${package.title}'),
              backgroundColor: Colors.amber[700],
            ),
          );

          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Purchase failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Purchase failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _launchCheckout(String url, String? sessionId) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      setState(() {
        _errorMessage = 'Invalid checkout URL returned.';
      });
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );

      if (!mounted) return;

      if (!launched) {
        setState(() {
          _errorMessage = 'Unable to open checkout window.';
          _awaitingWebConfirmation = false;
          _pendingSessionId = null;
        });
      } else {
        setState(() {
          _pendingSessionId = sessionId;
          _awaitingWebConfirmation = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to open checkout: $e';
        _awaitingWebConfirmation = false;
        _pendingSessionId = null;
      });
    }
  }

  Future<void> _confirmPendingCheckout([String? sessionId]) async {
    final effectiveSession = sessionId ?? _pendingSessionId;
    if (effectiveSession == null || effectiveSession.isEmpty) {
      setState(() {
        _errorMessage = 'No pending checkout session to verify.';
      });
      return;
    }

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final status = await EnhancedPaymentService.confirmWebCheckout(effectiveSession);
      if (!mounted) return;

      setState(() {
        _status = status;
        _awaitingWebConfirmation = false;
        _pendingSessionId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription activated: ${status.tier.toUpperCase()}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not verify checkout: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final restored = await EnhancedPaymentService.restorePurchases();
      if (!mounted) return;

      if (restored) {
        final status = await EnhancedPaymentService.getSubscriptionStatus();
        if (!mounted) return;
        setState(() {
          _status = status;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchases restored'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'No purchases available to restore';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Restore failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  bool _isPackageActive(MockPackage package) {
    final tier = _status?.tier;
    if (tier == null) return false;

    switch (package.identifier) {
      case EnhancedPaymentService.premiumMonthlyId:
        return tier == 'premium' || tier == 'pro' || tier == 'founders';
      case EnhancedPaymentService.proMonthlyId:
        return tier == 'pro' || tier == 'founders';
      case EnhancedPaymentService.foundersLifetimeId:
        return tier == 'founders';
      default:
        return false;
    }
  }

  Widget _buildStatusCard() {
    if (_status == null) return const SizedBox.shrink();
    final status = _status!;

    final tierLabel = status.tier.replaceAll('_', ' ').toUpperCase();
    final subtitle = _statusSubtitle(status);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(0.4), Colors.deepPurple.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Plan',
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tierLabel,
            style: GoogleFonts.cinzel(
              color: Colors.amber,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.crimsonText(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _statusSubtitle(SubscriptionStatus status) {
    if (!status.isActive) {
      return 'No active subscription';
    }

    if (status.tier.toLowerCase() == 'founders' && status.expiresAt == null) {
      return 'Lifetime access unlocked';
    }

    final expiresAt = status.expiresAt;
    if (expiresAt == null || expiresAt.isEmpty) {
      return status.willRenew
          ? 'Renews automatically each period'
          : 'Access active until the current period ends';
    }

    final parsed = DateTime.tryParse(expiresAt);
    if (parsed == null) {
      return status.willRenew
          ? 'Renews on $expiresAt'
          : 'Access until $expiresAt';
    }

    final formatted = DateFormat.yMMMMd().add_jm().format(parsed.toLocal());
    return status.willRenew
        ? 'Renews on $formatted'
        : 'Access until $formatted';
  }

  Widget _buildCheckoutBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_checkout, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Complete your checkout',
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Finish the secure payment in the newly opened tab. Once complete, return here and refresh your status.',
            style: GoogleFonts.crimsonText(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _isPurchasing || _pendingSessionId == null
                  ? null
                  : () => _confirmPendingCheckout(),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('I\'ve completed payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(MockPackage package) {
    final isActive = _isPackageActive(package);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.greenAccent : Colors.purple.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                package.title,
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                package.price,
                style: GoogleFonts.cinzel(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            package.description,
            style: GoogleFonts.crimsonText(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isActive || _isPurchasing ? null : () => _purchase(package),
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.green : Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isActive ? 'Current Plan' : 'Choose Plan',
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: Text(
          'Unlock Ascension',
          style: GoogleFonts.cinzel(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            )
          : RefreshIndicator(
              onRefresh: _loadOfferings,
              color: Colors.amber,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStatusCard(),
                  if (_awaitingWebConfirmation) _buildCheckoutBanner(),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.crimsonText(color: Colors.white),
                      ),
                    ),
                  for (final package in _packages) _buildPackageCard(package),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isPurchasing ? null : _restorePurchases,
                    icon: const Icon(Icons.restore, color: Colors.amber),
                    label: Text(
                      'Restore Purchases',
                      style: GoogleFonts.cinzel(color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
