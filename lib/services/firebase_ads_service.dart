import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Simple Firebase Extensions-based ads service
/// Uses Firebase Remote Config + AdMob integration
class FirebaseAdsService {
  static FirebaseAdsService? _instance;
  static FirebaseAdsService get instance => _instance ??= FirebaseAdsService._();
  FirebaseAdsService._();

  BannerAd? _bannerAd;
  bool _isUserPremium = false;
  bool _adsEnabled = true;

  /// Initialize using Firebase Extensions
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    
    // Get ad settings from Firebase Remote Config
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.fetchAndActivate();
    
    _adsEnabled = remoteConfig.getBool('ads_enabled');
    
    if (_adsEnabled && !_isUserPremium) {
      _loadBannerAd();
    }
    
    print('🎯 Firebase Ads Service initialized - Enabled: $_adsEnabled');
  }

  /// Load banner ad using Firebase Remote Config for ad units
  Future<void> _loadBannerAd() async {
    if (_isUserPremium || !_adsEnabled) return;

    final remoteConfig = FirebaseRemoteConfig.instance;
    final adUnitId = kDebugMode 
      ? 'ca-app-pub-3940256099942544/6300978111' // Test
      : remoteConfig.getString('banner_ad_unit_id'); // Production from Firebase

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(
        keywords: ['crystals', 'spirituality', 'meditation', 'healing'],
      ),
      listener: BannerAdListener(
        onAdLoaded: (ad) => print('✅ Banner ad loaded'),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('❌ Banner ad failed: ${error.message}');
        },
      ),
    );

    await _bannerAd!.load();
  }

  /// Update user subscription status
  void updateUserSubscription(bool isPremium) {
    _isUserPremium = isPremium;
    
    if (_isUserPremium) {
      _bannerAd?.dispose();
      _bannerAd = null;
      print('👑 Premium user - ads disabled');
    } else if (_adsEnabled) {
      _loadBannerAd();
      print('🆓 Free user - ads enabled');
    }
  }

  /// Show rewarded ad for premium features
  Future<bool> showRewardedAdForPremiumAccess() async {
    if (_isUserPremium || !_adsEnabled) return false;

    final remoteConfig = FirebaseRemoteConfig.instance;
    final rewardedAdUnitId = kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917' // Test
      : remoteConfig.getString('rewarded_ad_unit_id'); // Production

    RewardedAd? rewardedAd;
    bool adCompleted = false;

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(
        keywords: ['crystals', 'premium', 'unlock'],
      ),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          print('✅ Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          print('❌ Rewarded ad failed: ${error.message}');
        },
      ),
    );

    if (rewardedAd != null) {
      rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        adCompleted = true;
        print('🎁 User earned reward: ${reward.amount} ${reward.type}');
        // Grant 1 hour of premium access via Firebase Extensions
        _grantTemporaryPremiumAccess();
      });
      
      rewardedAd!.dispose();
      return adCompleted;
    }

    return false;
  }

  /// Grant temporary premium using Firebase Extensions
  void _grantTemporaryPremiumAccess() {
    // This would integrate with Firebase Extensions for user management
    // For now, just log it
    print('🎁 Granted 1 hour premium access via Firebase Extensions');
  }

  /// Get banner ad for display
  BannerAd? get bannerAd {
    if (_isUserPremium || !_adsEnabled) return null;
    return _bannerAd;
  }

  /// Check if ads should be shown
  bool get shouldShowAds => !_isUserPremium && _adsEnabled;

  void dispose() {
    _bannerAd?.dispose();
  }
}

/// Simple banner ad widget
class SimpleBannerAd extends StatelessWidget {
  const SimpleBannerAd({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ad = FirebaseAdsService.instance.bannerAd;
    
    if (ad == null || !FirebaseAdsService.instance.shouldShowAds) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      child: AdWidget(ad: ad),
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
    );
  }
}