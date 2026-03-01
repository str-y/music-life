import 'dart:io';

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
    final service = GoogleMobileAdsService(config);

    final expectedBannerId =
        Platform.isAndroid ? 'banner_android' : 'banner_ios';
    final expectedInterstitialId =
        Platform.isAndroid ? 'interstitial_android' : 'interstitial_ios';
    final expectedRewardedId =
        Platform.isAndroid ? 'rewarded_android' : 'rewarded_ios';

    expect(service.bannerAdUnitId, expectedBannerId);
    expect(service.interstitialAdUnitId, expectedInterstitialId);
    expect(service.rewardedAdUnitId, expectedRewardedId);
    expect(service, isA<IAdService>());
  });
}
