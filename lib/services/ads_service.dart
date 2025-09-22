import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'environment_config.dart';
import 'storage_service.dart';

class AdsService {
  static const String _testAndroidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testAndroidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testAndroidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosRewardedId = 'ca-app-pub-3940256099942544/1712485313';

  static final EnvironmentConfig _config = EnvironmentConfig.instance;

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

      final testDevices = _config.adTestDeviceIds;
      if (testDevices.isNotEmpty) {
        MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: testDevices),
        );
      }
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
    if (!Platform.isAndroid && !Platform.isIOS) {
      print('Banner ads are only supported on Android/iOS');
      return null;
    }

    final adUnitId = _resolveBannerAdUnitId();

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
    if (!Platform.isAndroid && !Platform.isIOS) {
      print('Interstitial ads are only supported on Android/iOS');
      return;
    }

    final adUnitId = _resolveInterstitialAdUnitId();

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
    if (!Platform.isAndroid && !Platform.isIOS) {
      print('Rewarded ads are only supported on Android/iOS');
      return;
    }

    final adUnitId = _resolveRewardedAdUnitId();

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

  static String _resolveBannerAdUnitId() {
    if (Platform.isAndroid) {
      final id = _config.admobAndroidBannerId;
      if (id.isEmpty) {
        print('AdMob Android banner ID missing - using Google test unit');
        return _testAndroidBannerId;
      }
      return id;
    } else if (Platform.isIOS) {
      final id = _config.admobIosBannerId;
      if (id.isEmpty) {
        print('AdMob iOS banner ID missing - using Google test unit');
        return _testIosBannerId;
      }
      return id;
    }

    return _testAndroidBannerId;
  }

  static String _resolveInterstitialAdUnitId() {
    if (Platform.isAndroid) {
      final id = _config.admobAndroidInterstitialId;
      if (id.isEmpty) {
        print('AdMob Android interstitial ID missing - using Google test unit');
        return _testAndroidInterstitialId;
      }
      return id;
    } else if (Platform.isIOS) {
      final id = _config.admobIosInterstitialId;
      if (id.isEmpty) {
        print('AdMob iOS interstitial ID missing - using Google test unit');
        return _testIosInterstitialId;
      }
      return id;
    }

    return _testAndroidInterstitialId;
  }

  static String _resolveRewardedAdUnitId() {
    if (Platform.isAndroid) {
      final id = _config.admobAndroidRewardedId;
      if (id.isEmpty) {
        print('AdMob Android rewarded ID missing - using Google test unit');
        return _testAndroidRewardedId;
      }
      return id;
    } else if (Platform.isIOS) {
      final id = _config.admobIosRewardedId;
      if (id.isEmpty) {
        print('AdMob iOS rewarded ID missing - using Google test unit');
        return _testIosRewardedId;
      }
      return id;
    }

    return _testAndroidRewardedId;
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