import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('initial state is loaded from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      AppConfig.defaultDarkModeStorageKey: true,
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

    expect(settings, const AppSettings(darkMode: true, referencePitch: 442.0));
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

    const updated = AppSettings(darkMode: true, referencePitch: 444.0);
    await container.read(appSettingsProvider.notifier).update(updated);

    expect(container.read(appSettingsProvider), updated);
    expect(prefs.getBool(AppConfig.defaultDarkModeStorageKey), isTrue);
    expect(prefs.getDouble(AppConfig.defaultReferencePitchStorageKey), 444.0);
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
}
