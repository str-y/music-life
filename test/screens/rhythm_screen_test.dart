import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/rhythm_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'golden_test_utils.dart';

Widget _wrap(
  Widget child, {
  required SharedPreferences prefs,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
    child: buildGoldenTestApp(
      home: child,
      locale: locale,
      themeMode: themeMode,
    ),
  );
}

Future<List<dynamic>> _settingsOverridesWithPrefs({
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return [sharedPreferencesProvider.overrideWithValue(prefs)];
}

/// Pumps a [Semantics] widget with [label] and returns the resolved label.
Future<String> _pumpSemanticLabel(
  WidgetTester tester,
  String Function(AppLocalizations) extract,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  late String label;
  await tester.pumpWidget(_wrap(
    Builder(builder: (context) {
      label = extract(AppLocalizations.of(context)!);
      return Semantics(
        label: label,
        button: true,
        child: const SizedBox(width: 50, height: 36),
      );
    }),
    prefs: prefs,
  ));
  await tester.pumpAndSettle();
  return label;
}

void main() {
  group('RhythmScreen – BPM button semantic labels', () {
    for (final entry in <String, String Function(AppLocalizations)>{
      'bpmDecrease10SemanticLabel': (l) => l.bpmDecrease10SemanticLabel,
      'bpmDecrease1SemanticLabel': (l) => l.bpmDecrease1SemanticLabel,
      'bpmIncrease1SemanticLabel': (l) => l.bpmIncrease1SemanticLabel,
      'bpmIncrease10SemanticLabel': (l) => l.bpmIncrease10SemanticLabel,
    }.entries) {
      testWidgets('${entry.key} is non-empty and appears as a Semantics node',
          (tester) async {
        final label = await _pumpSemanticLabel(tester, entry.value);

        expect(label, isNotEmpty);
        expect(find.bySemanticsLabel(label), findsOneWidget);
      });
    }
  });

  testWidgets('disposing RhythmScreen does not leak animation tickers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(const RhythmScreen(), prefs: prefs));
    await tester.pump();

    await tester.pumpWidget(_wrap(const SizedBox.shrink(), prefs: prefs));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('matches rhythm screen golden baseline', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(const RhythmScreen(), prefs: prefs));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(_wrap(const RhythmScreen(), prefs: prefs));
  });

  testWidgets('downloads and selects a metronome sound pack from the library',
      (tester) async {
    final overrides = await _settingsOverridesWithPrefs();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(const RhythmScreen(),
        overrides: overrides, prefs: prefs));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MaterialApp).first),
    )!;

    expect(
      find.text(
        l10n.metronomeSoundLibrarySelected(
          l10n.metronomeSoundPackElectronicName,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('metronome-sound-library-button')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.metronomeSoundPackAcousticName), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('metronome-sound-action-acoustic_kit')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.metronomeSoundPackAcousticName), findsWidgets);
    expect(find.text(l10n.metronomeSoundLibraryInUse), findsOneWidget);
  });

  testWidgets('premium sound pack prompts rewarded unlock when locked',
      (tester) async {
    final overrides = await _settingsOverridesWithPrefs();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_wrap(const RhythmScreen(),
        overrides: overrides, prefs: prefs));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MaterialApp).first),
    )!;

    await tester.tap(find.byKey(const ValueKey('metronome-sound-library-button')));
    await tester.pumpAndSettle();

    expect(find.text(l10n.metronomeSoundPackVoiceName), findsOneWidget);
    expect(find.text(l10n.watchAdAndUnlock), findsOneWidget);
  });
}
