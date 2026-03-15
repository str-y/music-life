import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/metronome_sound_library.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/providers/metronome_settings_provider.dart';
import 'package:music_life/repositories/metronome_settings_repository.dart';
import 'package:music_life/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('initial state is loaded from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      AppConfig.defaultMetronomeBpmStorageKey: 98,
      AppConfig.defaultMetronomeTimeSignatureNumeratorStorageKey: 7,
      AppConfig.defaultMetronomeTimeSignatureDenominatorStorageKey: 8,
      AppConfig.defaultMetronomeSoundPacksStorageKey: <String>[
        defaultMetronomeSoundPackId,
        'acoustic_kit',
      ],
      AppConfig.defaultSelectedMetronomeSoundPackStorageKey: 'acoustic_kit',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final settings = container.read(metronomeSettingsProvider);

    expect(
      settings,
      const MetronomeSettings(
        bpm: 98,
        timeSignatureNumerator: 7,
        timeSignatureDenominator: 8,
        installedSoundPackIds: <String>[
          defaultMetronomeSoundPackId,
          'acoustic_kit',
        ],
        selectedSoundPackId: 'acoustic_kit',
      ),
    );
  });

  test('updateMetronomeSettings changes state and persists values', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(metronomeSettingsControllerProvider).updateMetronomeSettings(
          bpm: 132,
          timeSignatureNumerator: 5,
          timeSignatureDenominator: 8,
        );

    expect(
      container.read(metronomeSettingsProvider),
      const MetronomeSettings(
        bpm: 132,
        timeSignatureNumerator: 5,
        timeSignatureDenominator: 8,
      ),
    );
    expect(prefs.getInt(AppConfig.defaultMetronomeBpmStorageKey), 132);
    expect(
      prefs.getInt(AppConfig.defaultMetronomeTimeSignatureNumeratorStorageKey),
      5,
    );
    expect(
      prefs.getInt(AppConfig.defaultMetronomeTimeSignatureDenominatorStorageKey),
      8,
    );
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
        .read(metronomeSettingsControllerProvider)
        .installSoundPack('acoustic_kit');

    expect(
      container.read(metronomeSettingsProvider).installedSoundPackIds,
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
        .read(metronomeSettingsControllerProvider)
        .selectSoundPack('acoustic_kit');

    expect(
      container.read(metronomeSettingsProvider).selectedSoundPackId,
      defaultMetronomeSoundPackId,
    );
  });

  test('premium sound packs require rewarded premium access', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(metronomeSettingsControllerProvider)
        .installSoundPack('signature_voice_count');
    expect(
      container.read(metronomeSettingsProvider).installedSoundPackIds,
      <String>[defaultMetronomeSoundPackId],
    );

    await container.read(appSettingsProvider.notifier).save(
          AppSettings(
            rewardedPremiumExpiresAt: DateTime.utc(2030, 1, 2),
          ),
        );

    await container
        .read(metronomeSettingsControllerProvider)
        .installSoundPack('signature_voice_count');

    expect(
      container.read(metronomeSettingsProvider).installedSoundPackIds,
      <String>[defaultMetronomeSoundPackId, 'signature_voice_count'],
    );
  });
}
