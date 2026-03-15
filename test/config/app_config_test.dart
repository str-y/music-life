import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/utils/app_logger.dart';

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

  test('uses an explicitly configured log level override', () {
    const config = AppConfig(logLevel: AppLogLevel.warning);

    expect(config.effectiveLogLevel, AppLogLevel.warning);
  });

  test('resolves non-production flavors from environment values', () {
    final devConfig = AppConfig.fromEnvironment(flavor: 'dev');
    final stagingConfig = AppConfig.fromEnvironment(flavor: 'staging');

    expect(devConfig.flavor, AppFlavor.dev);
    expect(devConfig.apiBaseUrl, AppConfig.defaultDevApiBaseUrl);
    expect(stagingConfig.flavor, AppFlavor.staging);
    expect(stagingConfig.apiBaseUrl, AppConfig.defaultStagingApiBaseUrl);
  });

  test('falls back to production for unknown flavor values', () {
    final config = AppConfig.fromEnvironment(flavor: 'unexpected');

    expect(config.flavor, AppFlavor.prod);
    expect(config.apiBaseUrl, AppConfig.defaultApiBaseUrl);
    expect(config.isProduction, isTrue);
  });

  test('separates development data from production defaults', () {
    final config = AppConfig.dev();

    expect(config.recordingsStorageKey, 'dev_${AppConfig.defaultRecordingsStorageKey}');
    expect(
      config.audioNotificationChannelId,
      '${AppConfig.defaultAudioNotificationChannelId}.dev',
    );
    expect(config.isProduction, isFalse);
  });
}
