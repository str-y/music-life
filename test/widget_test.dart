// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_life/main.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test: MusicLifeApp builds without exceptions',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.dev()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MusicLifeApp(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
