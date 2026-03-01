import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_life/main.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/screens/library_screen.dart';
import 'package:music_life/screens/main_screen.dart';
import 'package:music_life/screens/practice_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester, {String? initialLocation}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MusicLifeApp(initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('App router', () {
    testWidgets('default route opens main screen', (tester) async {
      await _pumpApp(tester);

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('deep link /recordings opens the recording view',
        (tester) async {
      await _pumpApp(tester, initialLocation: '/recordings');

      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('deep link /practice-log opens the practice log view',
        (tester) async {
      await _pumpApp(tester, initialLocation: '/practice-log');

      expect(find.byType(PracticeLogScreen), findsOneWidget);
    });
  });
}
