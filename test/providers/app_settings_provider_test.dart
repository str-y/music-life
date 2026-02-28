import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('initial state is loaded from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'darkMode': true,
      'referencePitch': 442.0,
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
    expect(prefs.getBool('darkMode'), isTrue);
    expect(prefs.getDouble('referencePitch'), 444.0);
  });
}
