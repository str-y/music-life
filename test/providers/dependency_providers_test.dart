import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/composition_repository.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sharedPreferencesProvider throws when not overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(sharedPreferencesProvider),
      throwsUnimplementedError,
    );
  });

  test('repository providers resolve with sharedPreferences override',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(sharedPreferencesProvider), same(prefs));
    expect(container.read(appConfigProvider), isA<AppConfig>());
    expect(
      container.read(recordingRepositoryProvider),
      isA<RecordingRepository>(),
    );
    expect(
      container.read(compositionRepositoryProvider),
      isA<CompositionRepository>(),
    );
    expect(
      container.read(settingsRepositoryProvider),
      isA<SettingsRepository>(),
    );
  });
}
