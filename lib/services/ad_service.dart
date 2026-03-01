import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import 'service_error_handler.dart';

enum AdLoadStatus { idle, loading, loaded, error }

class AdState {
  const AdState({
    this.interstitialStatus = AdLoadStatus.idle,
    this.interstitialError,
    this.rewardedStatus = AdLoadStatus.idle,
    this.rewardedError,
  });

  final AdLoadStatus interstitialStatus;
  final String? interstitialError;
  final AdLoadStatus rewardedStatus;
  final String? rewardedError;

  AdState copyWith({
    AdLoadStatus? interstitialStatus,
    String? interstitialError,
    bool clearInterstitialError = false,
    AdLoadStatus? rewardedStatus,
    String? rewardedError,
    bool clearRewardedError = false,
  }) {
    return AdState(
      interstitialStatus: interstitialStatus ?? this.interstitialStatus,
      interstitialError: clearInterstitialError
          ? null
          : (interstitialError ?? this.interstitialError),
      rewardedStatus: rewardedStatus ?? this.rewardedStatus,
      rewardedError:
          clearRewardedError ? null : (rewardedError ?? this.rewardedError),
    );
  }
}

class AdStateNotifier extends Notifier<AdState> {
  @override
  AdState build() => const AdState();

  void setInterstitialLoading() {
    state = state.copyWith(
      interstitialStatus: AdLoadStatus.loading,
      clearInterstitialError: true,
    );
  }

  void setInterstitialLoaded() {
    state = state.copyWith(
      interstitialStatus: AdLoadStatus.loaded,
      clearInterstitialError: true,
    );
  }

  void setInterstitialError(String error) {
    state = state.copyWith(
      interstitialStatus: AdLoadStatus.error,
      interstitialError: error,
    );
  }

  void setRewardedLoading() {
    state = state.copyWith(
      rewardedStatus: AdLoadStatus.loading,
      clearRewardedError: true,
    );
  }

  void setRewardedLoaded() {
    state = state.copyWith(
      rewardedStatus: AdLoadStatus.loaded,
      clearRewardedError: true,
    );
  }

  void setRewardedError(String error) {
    state = state.copyWith(
      rewardedStatus: AdLoadStatus.error,
      rewardedError: error,
    );
  }
}

final adStateProvider = NotifierProvider<AdStateNotifier, AdState>(
  AdStateNotifier.new,
);

final adServiceProvider = Provider<IAdService>((ref) {
  return GoogleMobileAdsService(
    ref.read(appConfigProvider),
    adStateNotifier: ref.read(adStateProvider.notifier),
  );
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
  GoogleMobileAdsService(
    this._config, {
    AdStateNotifier? adStateNotifier,
  }) : _stateNotifier = adStateNotifier;

  final AppConfig _config;
  final AdStateNotifier? _stateNotifier;

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
    _stateNotifier?.setInterstitialLoading();
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
          _stateNotifier?.setInterstitialLoaded();
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ServiceErrorHandler.report(
                'AdService: failed to show interstitial ad',
                error: error,
                stackTrace: StackTrace.current,
              );
              ad.dispose();
              _stateNotifier?.setInterstitialError(error.message);
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          ServiceErrorHandler.report(
            'AdService: failed to load interstitial ad',
            error: error,
            stackTrace: StackTrace.current,
          );
          _interstitialLoadAttempts++;
          _interstitialAd = null;
          _stateNotifier?.setInterstitialError(error.message);
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
      _stateNotifier?.setInterstitialError(
        'Interstitial ad is not ready yet. Please try again.',
      );
      loadInterstitialAd();
    }
  }

  @override
  Future<void> loadRewardedAd() async {
    _stateNotifier?.setRewardedLoading();
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoadAttempts = 0;
          _stateNotifier?.setRewardedLoaded();
        },
        onAdFailedToLoad: (error) {
          ServiceErrorHandler.report(
            'AdService: failed to load rewarded ad',
            error: error,
            stackTrace: StackTrace.current,
          );
          _rewardedLoadAttempts++;
          _rewardedAd = null;
          _stateNotifier?.setRewardedError(error.message);
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
      _stateNotifier?.setRewardedError(
        'Rewarded ad is not ready yet. Please try again.',
      );
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
        ServiceErrorHandler.report(
          'AdService: failed to show rewarded ad',
          error: error,
          stackTrace: StackTrace.current,
        );
        ad.dispose();
        _stateNotifier?.setRewardedError(error.message);
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
