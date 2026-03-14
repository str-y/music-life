import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/metronome_sound_library.dart';
import 'package:music_life/models/premium_video_export.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/backup_repository.dart';
import 'package:music_life/repositories/settings_repository.dart';
import 'package:music_life/theme/dynamic_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('initial state is loaded from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      AppConfig.defaultDarkModeStorageKey: true,
      AppConfig.defaultUseSystemThemeStorageKey: false,
      AppConfig.defaultLocaleStorageKey: 'ja',
      AppConfig.defaultThemeColorNoteStorageKey: 'G',
      AppConfig.defaultReferencePitchStorageKey: 442.0,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final settings = container.read(appSettingsProvider);

    expect(
      settings,
      const AppSettings(
        darkMode: true,
        useSystemTheme: false,
        localeCode: 'ja',
        themeColorNote: 'G',
        dynamicThemeMode: DynamicThemeMode.chill,
        dynamicThemeIntensity: 0.7,
        referencePitch: 442.0,
        installedMetronomeSoundPackIds: <String>[defaultMetronomeSoundPackId],
        selectedMetronomeSoundPackId: defaultMetronomeSoundPackId,
      ),
    );
  });

  test('update changes state and persists values', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    const updated = AppSettings(
      darkMode: true,
      useSystemTheme: false,
      localeCode: 'ja',
      themeColorNote: 'A#',
      dynamicThemeMode: DynamicThemeMode.intense,
      dynamicThemeIntensity: 0.25,
      referencePitch: 444.0,
    );
    await container.read(appSettingsProvider.notifier).update(updated);

    expect(container.read(appSettingsProvider), updated);
    expect(prefs.getBool(AppConfig.defaultDarkModeStorageKey), isTrue);
    expect(prefs.getBool(AppConfig.defaultUseSystemThemeStorageKey), isFalse);
    expect(prefs.getString(AppConfig.defaultLocaleStorageKey), 'ja');
    expect(prefs.getString(AppConfig.defaultThemeColorNoteStorageKey), 'A#');
    expect(
      prefs.getString(AppConfig.defaultDynamicThemeModeStorageKey),
      'intense',
    );
    expect(
      prefs.getDouble(AppConfig.defaultDynamicThemeIntensityStorageKey),
      0.25,
    );
    expect(prefs.getDouble(AppConfig.defaultReferencePitchStorageKey), 444.0);
  });

  test('installMetronomeSoundPack persists a newly downloaded pack', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(appSettingsProvider.notifier)
        .installMetronomeSoundPack('acoustic_kit');

    expect(
      container.read(appSettingsProvider).installedMetronomeSoundPackIds,
      <String>[defaultMetronomeSoundPackId, 'acoustic_kit'],
    );
    expect(
      prefs.getStringList(AppConfig.defaultMetronomeSoundPacksStorageKey),
      <String>[defaultMetronomeSoundPackId, 'acoustic_kit'],
    );
  });

  test('selectMetronomeSoundPack ignores packs that are not installed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(appSettingsProvider.notifier)
        .selectMetronomeSoundPack('acoustic_kit');

    expect(
      container.read(appSettingsProvider).selectedMetronomeSoundPackId,
      defaultMetronomeSoundPackId,
    );
  });

  test('updateDynamicThemeFromPitch updates in-memory theme values only',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).updateDynamicThemeFromPitch(
          const PitchResult(
            noteName: 'A4',
            frequency: 440.0,
            centsOffset: 25.0,
            midiNote: 69,
          ),
        );

    final settings = container.read(appSettingsProvider);
    expect(settings.dynamicThemeNote, 'A4');
    expect(settings.dynamicThemeEnergy, 0.5);

    container.read(appSettingsProvider.notifier).updateDynamicThemeFromPitch(
          const PitchResult(
            noteName: 'C4',
            frequency: 261.63,
            centsOffset: 0.0,
            midiNote: 60,
          ),
        );
    expect(container.read(appSettingsProvider).dynamicThemeEnergy, 0.0);

    container.read(appSettingsProvider.notifier).updateDynamicThemeFromPitch(
          const PitchResult(
            noteName: 'B4',
            frequency: 493.88,
            centsOffset: 60.0,
            midiNote: 71,
          ),
        );
    expect(container.read(appSettingsProvider).dynamicThemeEnergy, 1.0);
    expect(prefs.getString('dynamicThemeNote'), isNull);
    expect(prefs.getDouble('dynamicThemeEnergy'), isNull);
  });

  test('updateDynamicThemeFromChord maps root note and chord complexity', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    container.read(appSettingsProvider.notifier).updateDynamicThemeFromChord('Gmaj7');

    final settings = container.read(appSettingsProvider);
    expect(settings.dynamicThemeNote, 'G');
    expect(settings.dynamicThemeEnergy, 0.64);

    container.read(appSettingsProvider.notifier).updateDynamicThemeFromChord('C');
    expect(container.read(appSettingsProvider).dynamicThemeEnergy, 0.28);
  });

  test('unlockRewardedPremiumFor sets and persists expiration', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final now = DateTime.utc(2026, 1, 1, 0, 0, 0);
    await container.read(appSettingsProvider.notifier).unlockRewardedPremiumFor(
          const Duration(hours: 24),
          now: now,
        );

    expect(
      container.read(appSettingsProvider).rewardedPremiumExpiresAt,
      DateTime.utc(2026, 1, 2, 0, 0, 0),
    );
    expect(
      prefs.getString(AppConfig.defaultRewardedPremiumExpiresAtStorageKey),
      '2026-01-02T00:00:00.000Z',
    );
  });

  test('updatePremiumVideoExportSettings persists premium export preferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appSettingsProvider.notifier).updatePremiumVideoExportSettings(
          skin: PremiumVideoExportSkin.neonPulse,
          waveformColorValue: 0xFFFF4081,
          effect: PremiumVideoExportEffect.prism,
          showLogo: false,
          quality: PremiumVideoExportQuality.ultra,
        );

    final settings = container.read(appSettingsProvider);
    expect(settings.premiumVideoExportSkin, PremiumVideoExportSkin.neonPulse);
    expect(settings.premiumVideoExportColor, 0xFFFF4081);
    expect(settings.premiumVideoExportEffect, PremiumVideoExportEffect.prism);
    expect(settings.premiumVideoExportShowLogo, isFalse);
    expect(settings.premiumVideoExportQuality, PremiumVideoExportQuality.ultra);
    expect(
      prefs.getString(AppConfig.defaultPremiumVideoExportSkinStorageKey),
      'neon_pulse',
    );
    expect(
      prefs.getInt(AppConfig.defaultPremiumVideoExportColorStorageKey),
      0xFFFF4081,
    );
    expect(
      prefs.getString(AppConfig.defaultPremiumVideoExportEffectStorageKey),
      'prism',
    );
    expect(
      prefs.getBool(AppConfig.defaultPremiumVideoExportShowLogoStorageKey),
      isFalse,
    );
    expect(
      prefs.getString(AppConfig.defaultPremiumVideoExportQualityStorageKey),
      'ultra',
    );
  });

  test('setCloudSyncEnabled syncs the current backup snapshot for premium users',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backupRepository = _FakeBackupRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backupRepositoryProvider.overrideWithValue(backupRepository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appSettingsProvider.notifier).unlockRewardedPremiumFor(
          const Duration(hours: 24),
          now: DateTime.utc(2030, 1, 1),
        );
    await container.read(appSettingsProvider.notifier).setCloudSyncEnabled(true);

    final settings = container.read(appSettingsProvider);
    expect(settings.cloudSyncEnabled, isTrue);
    expect(settings.lastCloudSyncAt, isNotNull);
    expect(
      prefs.getString(AppConfig.defaultCloudBackupBundleStorageKey),
      '{"version":1}',
    );
    expect(backupRepository.exportCallCount, greaterThanOrEqualTo(1));
  });
}

class _FakeBackupRepository extends BackupRepository {
  _FakeBackupRepository() : super();

  int exportCallCount = 0;

  @override
  Future<String> exportJsonBundle() async {
    exportCallCount += 1;
    return '{"version":1}';
  }
}
