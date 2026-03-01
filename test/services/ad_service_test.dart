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
    );
    final service = AdService(config);

    final expectedBannerId =
        Platform.isAndroid ? 'banner_android' : 'banner_ios';
    final expectedInterstitialId =
        Platform.isAndroid ? 'interstitial_android' : 'interstitial_ios';

    expect(service.bannerAdUnitId, expectedBannerId);
    expect(service.interstitialAdUnitId, expectedInterstitialId);
  });
}
