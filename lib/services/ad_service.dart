import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService(ref.read(appConfigProvider));
});

class AdService {
  const AdService(this._config);

  final AppConfig _config;

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

  void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      loadInterstitialAd();
    }
  }

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
