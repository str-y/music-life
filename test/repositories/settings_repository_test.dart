import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/repositories/settings_repository.dart';
import 'package:music_life/theme/dynamic_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsRepository', () {
    test('load returns defaults when values are absent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      final settings = repository.load();

      expect(settings, const AppSettings());
    });

    test('load returns persisted settings values', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.defaultDarkModeStorageKey: true,
        AppConfig.defaultUseSystemThemeStorageKey: false,
        AppConfig.defaultLocaleStorageKey: 'ja',
        AppConfig.defaultThemeColorNoteStorageKey: 'F#',
        AppConfig.defaultDynamicThemeModeStorageKey: 'intense',
        AppConfig.defaultDynamicThemeIntensityStorageKey: 0.9,
        AppConfig.defaultReferencePitchStorageKey: 442.0,
        AppConfig.defaultTunerTranspositionStorageKey: 'Bb',
        AppConfig.defaultHapticFeedbackEnabledStorageKey: false,
        AppConfig.defaultCloudSyncEnabledStorageKey: true,
        AppConfig.defaultLastCloudSyncAtStorageKey: '2026-01-03T00:00:00.000Z',
        AppConfig.defaultRewardedPremiumExpiresAtStorageKey:
            '2026-01-01T00:00:00.000Z',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      final settings = repository.load();

      expect(settings.darkMode, isTrue);
      expect(settings.useSystemTheme, isFalse);
      expect(settings.localeCode, 'ja');
      expect(settings.themeColorNote, 'F#');
      expect(settings.dynamicThemeMode, DynamicThemeMode.intense);
      expect(settings.dynamicThemeIntensity, 0.9);
      expect(settings.referencePitch, 442.0);
      expect(settings.tunerTransposition, 'Bb');
      expect(settings.hapticFeedbackEnabled, isFalse);
      expect(settings.cloudSyncEnabled, isTrue);
      expect(
        settings.lastCloudSyncAt,
        DateTime.parse('2026-01-03T00:00:00.000Z'),
      );
      expect(
        settings.rewardedPremiumExpiresAt,
        DateTime.parse('2026-01-01T00:00:00.000Z'),
      );
    });

    test('save persists settings values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);
      final updated = AppSettings(
        darkMode: true,
        useSystemTheme: false,
        localeCode: 'ja',
        themeColorNote: 'A',
        dynamicThemeMode: DynamicThemeMode.classical,
        dynamicThemeIntensity: 0.4,
        referencePitch: 445,
        tunerTransposition: 'Eb',
        hapticFeedbackEnabled: false,
        cloudSyncEnabled: true,
        lastCloudSyncAt: DateTime.utc(2026, 1, 3, 4, 5, 6),
        rewardedPremiumExpiresAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );

      await repository.save(updated);

      expect(prefs.getBool(AppConfig.defaultDarkModeStorageKey), isTrue);
      expect(prefs.getBool(AppConfig.defaultUseSystemThemeStorageKey), isFalse);
      expect(prefs.getString(AppConfig.defaultLocaleStorageKey), 'ja');
      expect(prefs.getString(AppConfig.defaultThemeColorNoteStorageKey), 'A');
      expect(
        prefs.getString(AppConfig.defaultDynamicThemeModeStorageKey),
        'classical',
      );
      expect(
        prefs.getDouble(AppConfig.defaultDynamicThemeIntensityStorageKey),
        0.4,
      );
      expect(
        prefs.getDouble(AppConfig.defaultReferencePitchStorageKey),
        445.0,
      );
      expect(
        prefs.getString(AppConfig.defaultTunerTranspositionStorageKey),
        'Eb',
      );
      expect(
        prefs.getBool(AppConfig.defaultHapticFeedbackEnabledStorageKey),
        isFalse,
      );
      expect(prefs.getBool(AppConfig.defaultCloudSyncEnabledStorageKey), isTrue);
      expect(
        prefs.getString(AppConfig.defaultLastCloudSyncAtStorageKey),
        '2026-01-03T04:05:06.000Z',
      );
      expect(
        prefs.getString(AppConfig.defaultRewardedPremiumExpiresAtStorageKey),
        '2026-01-02T03:04:05.000Z',
      );
    });

    test('load ignores unsupported persisted locale values', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.defaultLocaleStorageKey: 'fr',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      final settings = repository.load();

      expect(settings.localeCode, isNull);
    });

    test('load clamps persisted dynamic theme intensity values', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.defaultDynamicThemeIntensityStorageKey: 10.0,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      final settings = repository.load();

      expect(settings.dynamicThemeIntensity, 1.0);
    });

  });
}
