import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'storage_service.dart';

class AdsService {
  // Test ad unit IDs (replace with real ones for production)
  static const String _androidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const String _androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  
  // Production ad unit IDs - TODO: Replace with your actual ad unit IDs
  // static const String _androidBannerId = 'ca-app-pub-XXXXX/XXXXX';
  // static const String _iosBannerId = 'ca-app-pub-XXXXX/XXXXX';
  // static const String _androidInterstitialId = 'ca-app-pub-XXXXX/XXXXX';
  // static const String _iosInterstitialId = 'ca-app-pub-XXXXX/XXXXX';
  // static const String _androidRewardedId = 'ca-app-pub-XXXXX/XXXXX';
  // static const String _iosRewardedId = 'ca-app-pub-XXXXX/XXXXX';
  
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  
  static bool _isInitialized = false;
  static int _interstitialLoadAttempts = 0;
  static int _rewardedLoadAttempts = 0;
  static const int _maxLoadAttempts = 3;
  
  // Initialize Mobile Ads SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      
      // Configure test devices
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: ['YOUR_TEST_DEVICE_ID']), // TODO: Add test device IDs
      );
    } catch (e) {
      print('Failed to initialize ads: $e');
    }
  }
  
  // Check if ads should be shown based on subscription
  static Future<bool> shouldShowAds() async {
    final tier = await StorageService.getSubscriptionTier();
    return tier == 'free';
  }
  
  // Create and load banner ad
  static Future<BannerAd?> createBannerAd() async {
    if (!await shouldShowAds()) return null;
    
    final String adUnitId = Platform.isAndroid ? _androidBannerId : _iosBannerId;
    
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner ad loaded');
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: $error');
          ad.dispose();
          _bannerAd = null;
        },
        onAdOpened: (ad) => print('Banner ad opened'),
        onAdClosed: (ad) => print('Banner ad closed'),
      ),
    );
    
    await _bannerAd!.load();
    return _bannerAd;
  }
  
  // Create and load interstitial ad
  static Future<void> loadInterstitialAd() async {
    if (!await shouldShowAds()) return;
    
    final String adUnitId = Platform.isAndroid ? _androidInterstitialId : _iosInterstitialId;
    
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('Interstitial ad loaded');
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
          
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _interstitialLoadAttempts++;
          _interstitialAd = null;
          
          if (_interstitialLoadAttempts < _maxLoadAttempts) {
            // Retry loading
            Future.delayed(const Duration(seconds: 2), loadInterstitialAd);
          }
        },
      ),
    );
  }
  
  // Show interstitial ad
  static Future<void> showInterstitialAd({Function? onAdDismissed}) async {
    if (_interstitialAd == null) {
      print('Interstitial ad not ready');
      onAdDismissed?.call();
      return;
    }
    
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        print('Interstitial ad dismissed');
        ad.dispose();
        onAdDismissed?.call();
        loadInterstitialAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('Interstitial ad failed to show: $error');
        ad.dispose();
        onAdDismissed?.call();
        loadInterstitialAd(); // Load next ad
      },
    );
    
    await _interstitialAd!.show();
    _interstitialAd = null;
  }
  
  // Create and load rewarded ad
  static Future<void> loadRewardedAd() async {
    final String adUnitId = Platform.isAndroid ? _androidRewardedId : _iosRewardedId;
    
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('Rewarded ad loaded');
          _rewardedAd = ad;
          _rewardedLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          print('Rewarded ad failed to load: $error');
          _rewardedLoadAttempts++;
          _rewardedAd = null;
          
          if (_rewardedLoadAttempts < _maxLoadAttempts) {
            // Retry loading
            Future.delayed(const Duration(seconds: 2), loadRewardedAd);
          }
        },
      ),
    );
  }
  
  // Show rewarded ad
  static Future<void> showRewardedAd({
    required Function(int amount) onUserEarnedReward,
    Function? onAdDismissed,
  }) async {
    if (_rewardedAd == null) {
      print('Rewarded ad not ready');
      onAdDismissed?.call();
      return;
    }
    
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        print('Rewarded ad dismissed');
        ad.dispose();
        onAdDismissed?.call();
        loadRewardedAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('Rewarded ad failed to show: $error');
        ad.dispose();
        onAdDismissed?.call();
        loadRewardedAd(); // Load next ad
      },
    );
    
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        print('User earned reward: ${reward.amount}');
        onUserEarnedReward(reward.amount.toInt());
      },
    );
    
    _rewardedAd = null;
  }
  
  // Dispose all ads
  static void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

// Banner ad widget wrapper
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    final ad = await AdsService.createBannerAd();
    if (ad != null && mounted) {
      setState(() {
        _bannerAd = ad;
        _isAdLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}