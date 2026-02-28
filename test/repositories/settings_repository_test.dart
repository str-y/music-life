import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/repositories/settings_repository.dart';
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
        'darkMode': true,
        'referencePitch': 442.0,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);

      final settings = repository.load();

      expect(settings.darkMode, isTrue);
      expect(settings.referencePitch, 442.0);
    });

    test('save persists settings values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SettingsRepository(prefs);
      const updated = AppSettings(darkMode: true, referencePitch: 445.0);

      await repository.save(updated);

      expect(prefs.getBool('darkMode'), isTrue);
      expect(prefs.getDouble('referencePitch'), 445.0);
    });
  });
}
