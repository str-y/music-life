import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

final adServiceProvider = Provider<IAdService>((ref) {
  return GoogleMobileAdsService(ref.read(appConfigProvider));
});

abstract class IAdService {
  String get bannerAdUnitId;
  String get interstitialAdUnitId;
  String get rewardedAdUnitId;

  Future<void> loadInterstitialAd();
  void showInterstitialAd();
  Future<void> loadRewardedAd();
  Future<bool> showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
  });
}

class GoogleMobileAdsService implements IAdService {
  const GoogleMobileAdsService(this._config);

  final AppConfig _config;

  @override
  String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? _config.testBannerIdAndroid
          : _config.testBannerIdIos;
    }
    // Replace with real IDs for production
    return Platform.isAndroid
        ? _config.testBannerIdAndroid
        : _config.testBannerIdIos;
  }

  @override
  String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? _config.testInterstitialIdAndroid
          : _config.testInterstitialIdIos;
    }
    // Replace with real IDs for production
    return Platform.isAndroid
        ? _config.testInterstitialIdAndroid
        : _config.testInterstitialIdIos;
  }

  @override
  String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? _config.testRewardedIdAndroid
          : _config.testRewardedIdIos;
    }
    // Replace with real IDs for production
    return Platform.isAndroid
        ? _config.testRewardedIdAndroid
        : _config.testRewardedIdIos;
  }

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  int _interstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;
  int _rewardedLoadAttempts = 0;
  static const int _maxRewardedLoadAttempts = 3;

  @override
  Future<void> loadInterstitialAd() async {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialLoadAttempts++;
          _interstitialAd = null;
          if (_interstitialLoadAttempts <= maxFailedLoadAttempts) {
            loadInterstitialAd();
          }
        },
      ),
    );
  }

  @override
  void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      loadInterstitialAd();
    }
  }

  @override
  Future<void> loadRewardedAd() async {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          _rewardedLoadAttempts++;
          _rewardedAd = null;
          if (_rewardedLoadAttempts <= _maxRewardedLoadAttempts) {
            loadRewardedAd();
          }
        },
      ),
    );
  }

  @override
  Future<bool> showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      loadRewardedAd();
      return false;
    }
    _rewardedAd = null;
    var rewarded = false;
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd();
        completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadRewardedAd();
        completer.complete(false);
      },
    );
    ad.show(
      onUserEarnedReward: (adWithoutView, reward) {
        rewarded = true;
        onUserEarnedReward(reward);
      },
    );
    return completer.future;
  }
}
