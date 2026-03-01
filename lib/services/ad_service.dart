import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

class AdService {
  static const String testBannerIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerIdIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String testInterstitialIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String testInterstitialIdIos = 'ca-app-pub-3940256099942544/4411468910';

  String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? testBannerIdAndroid : testBannerIdIos;
    }
    // Replace with real IDs for production
    return Platform.isAndroid ? testBannerIdAndroid : testBannerIdIos;
  }

  String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? testInterstitialIdAndroid : testInterstitialIdIos;
    }
    // Replace with real IDs for production
    return Platform.isAndroid ? testInterstitialIdAndroid : testInterstitialIdIos;
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
