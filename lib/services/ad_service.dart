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

  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

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
}
