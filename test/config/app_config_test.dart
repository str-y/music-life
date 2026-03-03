import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';

void main() {
  test('exposes default audio notification channel settings', () {
    const config = AppConfig();
    expect(
      config.audioNotificationChannelId,
      AppConfig.defaultAudioNotificationChannelId,
    );
    expect(
      config.audioNotificationChannelName,
      AppConfig.defaultAudioNotificationChannelName,
    );
  });
}
