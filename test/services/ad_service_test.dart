import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/services/ad_service.dart';

void main() {
  test('reads ad unit IDs from AppConfig', () {
    const config = AppConfig(
      testBannerIdAndroid: 'banner_android',
      testBannerIdIos: 'banner_ios',
      testInterstitialIdAndroid: 'interstitial_android',
      testInterstitialIdIos: 'interstitial_ios',
      testRewardedIdAndroid: 'rewarded_android',
      testRewardedIdIos: 'rewarded_ios',
    );
    final service = AdService(config);

    final expectedBannerId =
        Platform.isAndroid ? 'banner_android' : 'banner_ios';
    final expectedInterstitialId =
        Platform.isAndroid ? 'interstitial_android' : 'interstitial_ios';
    final expectedRewardedId =
        Platform.isAndroid ? 'rewarded_android' : 'rewarded_ios';

    expect(service.bannerAdUnitId, expectedBannerId);
    expect(service.interstitialAdUnitId, expectedInterstitialId);
    expect(service.rewardedAdUnitId, expectedRewardedId);
  });

  test('adStateProvider starts with idle statuses and no errors', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(adStateProvider);
    expect(state.interstitialStatus, AdLoadStatus.idle);
    expect(state.interstitialError, isNull);
    expect(state.rewardedStatus, AdLoadStatus.idle);
    expect(state.rewardedError, isNull);
  });

  test('AdStateNotifier updates load statuses and errors', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(adStateProvider.notifier);

    notifier.setInterstitialLoading();
    expect(
      container.read(adStateProvider).interstitialStatus,
      AdLoadStatus.loading,
    );

    notifier.setInterstitialError('interstitial-error');
    expect(
      container.read(adStateProvider).interstitialStatus,
      AdLoadStatus.error,
    );
    expect(
      container.read(adStateProvider).interstitialError,
      'interstitial-error',
    );

    notifier.setInterstitialLoaded();
    expect(
      container.read(adStateProvider).interstitialStatus,
      AdLoadStatus.loaded,
    );
    expect(container.read(adStateProvider).interstitialError, isNull);

    notifier.setRewardedLoading();
    expect(container.read(adStateProvider).rewardedStatus, AdLoadStatus.loading);

    notifier.setRewardedError('rewarded-error');
    expect(container.read(adStateProvider).rewardedStatus, AdLoadStatus.error);
    expect(container.read(adStateProvider).rewardedError, 'rewarded-error');

    notifier.setRewardedLoaded();
    expect(container.read(adStateProvider).rewardedStatus, AdLoadStatus.loaded);
    expect(container.read(adStateProvider).rewardedError, isNull);
  });
}
