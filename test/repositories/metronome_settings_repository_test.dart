import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/metronome_sound_library.dart';
import 'package:music_life/repositories/metronome_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MetronomeSettingsRepository', () {
    test('load returns defaults when values are absent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = MetronomeSettingsRepository(prefs);

      final settings = repository.load();

      expect(settings, const MetronomeSettings());
    });

    test('load returns persisted metronome values', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.defaultMetronomeBpmStorageKey: 96,
        AppConfig.defaultMetronomeTimeSignatureNumeratorStorageKey: 3,
        AppConfig.defaultMetronomeTimeSignatureDenominatorStorageKey: 4,
        AppConfig.defaultMetronomePresetsStorageKey:
            '[{"name":"Practice 6/8","bpm":132,"timeSignatureNumerator":6,"timeSignatureDenominator":8}]',
        AppConfig.defaultMetronomeSoundPacksStorageKey: <String>[
          defaultMetronomeSoundPackId,
          'acoustic_kit',
        ],
        AppConfig.defaultSelectedMetronomeSoundPackStorageKey: 'acoustic_kit',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = MetronomeSettingsRepository(prefs);

      final settings = repository.load();

      expect(settings.bpm, 96);
      expect(settings.timeSignatureNumerator, 3);
      expect(settings.timeSignatureDenominator, 4);
      expect(
        settings.presets,
        const [
          MetronomePreset(
            name: 'Practice 6/8',
            bpm: 132,
            timeSignatureNumerator: 6,
            timeSignatureDenominator: 8,
          ),
        ],
      );
      expect(
        settings.installedSoundPackIds,
        <String>[defaultMetronomeSoundPackId, 'acoustic_kit'],
      );
      expect(settings.selectedSoundPackId, 'acoustic_kit');
    });

    test('save persists metronome values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = MetronomeSettingsRepository(prefs);
      const updated = MetronomeSettings(
        bpm: 84,
        timeSignatureNumerator: 6,
        timeSignatureDenominator: 8,
        presets: [
          MetronomePreset(
            name: 'Gig',
            bpm: 148,
            timeSignatureNumerator: 4,
            timeSignatureDenominator: 4,
          ),
        ],
        installedSoundPackIds: <String>[
          defaultMetronomeSoundPackId,
          'percussion_clave',
        ],
        selectedSoundPackId: 'percussion_clave',
      );

      await repository.save(updated);

      expect(prefs.getInt(AppConfig.defaultMetronomeBpmStorageKey), 84);
      expect(
        prefs.getInt(AppConfig.defaultMetronomeTimeSignatureNumeratorStorageKey),
        6,
      );
      expect(
        prefs.getInt(
          AppConfig.defaultMetronomeTimeSignatureDenominatorStorageKey,
        ),
        8,
      );
      expect(
        prefs.getString(AppConfig.defaultMetronomePresetsStorageKey),
        '[{"name":"Gig","bpm":148,"timeSignatureNumerator":4,"timeSignatureDenominator":4}]',
      );
      expect(
        prefs.getStringList(AppConfig.defaultMetronomeSoundPacksStorageKey),
        <String>[defaultMetronomeSoundPackId, 'percussion_clave'],
      );
      expect(
        prefs.getString(AppConfig.defaultSelectedMetronomeSoundPackStorageKey),
        'percussion_clave',
      );
    });

    test(
        'load falls back to defaults for invalid metronome values and invalid sound pack selection',
        () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.defaultMetronomeBpmStorageKey: 999,
        AppConfig.defaultMetronomeTimeSignatureNumeratorStorageKey: 1,
        AppConfig.defaultMetronomeTimeSignatureDenominatorStorageKey: 16,
        AppConfig.defaultMetronomePresetsStorageKey:
            '[{"name":"","bpm":20,"timeSignatureNumerator":1,"timeSignatureDenominator":16}]',
        AppConfig.defaultMetronomeSoundPacksStorageKey: <String>['acoustic_kit'],
        AppConfig.defaultSelectedMetronomeSoundPackStorageKey: 'missing_pack',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = MetronomeSettingsRepository(prefs);

      final settings = repository.load();

      expect(settings.bpm, 240);
      expect(settings.timeSignatureNumerator, 2);
      expect(settings.timeSignatureDenominator, 4);
      expect(settings.presets, isEmpty);
      expect(
        settings.installedSoundPackIds,
        <String>[defaultMetronomeSoundPackId, 'acoustic_kit'],
      );
      expect(settings.selectedSoundPackId, defaultMetronomeSoundPackId);
    });
  });
}
