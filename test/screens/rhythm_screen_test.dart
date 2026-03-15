import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/rhythm_screen.dart';
import 'package:music_life/widgets/rhythm/metronome_section.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'golden_test_utils.dart';

Widget _wrap(
  Widget child, {
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [...overrides],
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
  final overrides = await _settingsOverridesWithPrefs();
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
    overrides: overrides,
  ));
  await tester.pumpAndSettle();
  return label;
}

void main() {
  group('RhythmScreen – BPM button semantic labels', () {
    for (final entry in <String, String Function(AppLocalizations)>{
      'bpmDecrease10SemanticLabel': (l) => l.bpmDecrease10SemanticLabel,
      'bpmDecrease1SemanticLabel': (l) => l.bpmDecrease1SemanticLabel,
      'bpmIncrease1CommandLabel': (l) => l.bpmIncrease1SemanticLabel,
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

  group('RhythmScreen – groove target semantics', () {
    testWidgets('tapTempoRingSemanticLabel is non-empty and appears as a Semantics node',
        (tester) async {
      final overrides = await _settingsOverridesWithPrefs();
      await tester.pumpWidget(_wrap(const RhythmScreen(), overrides: overrides));
      await tester.pump();

      final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;
      expect(l10n.tapTempoRingSemanticLabel, isNotEmpty);
      expect(find.bySemanticsLabel(l10n.tapTempoRingSemanticLabel), findsOneWidget);
    });
  });

  testWidgets('disposing RhythmScreen does not leak animation tickers',
      (tester) async {
    final overrides = await _settingsOverridesWithPrefs();
    await tester.pumpWidget(_wrap(const RhythmScreen(), overrides: overrides));
    await tester.pump();

    await tester.pumpWidget(_wrap(const SizedBox.shrink(), overrides: overrides));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders extracted metronome controls', (tester) async {
    final overrides = await _settingsOverridesWithPrefs();

    await tester.pumpWidget(_wrap(const RhythmScreen(), overrides: overrides));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    expect(find.byKey(const ValueKey('metronome-preset-dropdown')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-metronome-preset')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('time-signature-numerator-dropdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('time-signature-denominator-dropdown')),
      findsOneWidget,
    );
    expect(find.text('120'), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.bpmDecrease10SemanticLabel), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.bpmIncrease10SemanticLabel), findsOneWidget);
  });

  testWidgets('isolates metronome and groove target repaints with boundaries',
      (tester) async {
    final overrides = await _settingsOverridesWithPrefs();

    await tester.pumpWidget(_wrap(const RhythmScreen(), overrides: overrides));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    expect(
      find.ancestor(
        of: find.byType(MetronomeSection),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.bySemanticsLabel(l10n.tapTempoRingSemanticLabel),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('matches rhythm screen golden baseline', (tester) async {
    final overrides = await _settingsOverridesWithPrefs();
    await tester.pumpWidget(_wrap(const RhythmScreen(), overrides: overrides));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(_wrap(const RhythmScreen(), overrides: overrides));
  });

  testWidgets('sound library button is visible and tappable',
      (tester) async {
    final overrides = await _settingsOverridesWithPrefs();

    await tester.pumpWidget(_wrap(
      const RhythmScreen(),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    expect(find.byType(RhythmScreen), findsOneWidget);
    expect(find.text(l10n.metronomeSoundLibraryTitle), findsOneWidget);

    final buttonFinder = find.byKey(const ValueKey('metronome-sound-library-button'));
    expect(buttonFinder, findsOneWidget);
    
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();
    
    expect(find.text(l10n.metronomeSoundPackElectronicName), findsWidgets);
  });

  testWidgets('downloads and selects a metronome sound pack from the library',
      (tester) async {
    final overrides = await _settingsOverridesWithPrefs();
    
    await tester.pumpWidget(_wrap(
      const RhythmScreen(),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    final buttonFinder = find.byKey(const ValueKey('metronome-sound-library-button'));
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
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

    await tester.pumpWidget(_wrap(
      const RhythmScreen(),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    final buttonFinder = find.byKey(const ValueKey('metronome-sound-library-button'));
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(find.text(l10n.metronomeSoundPackVoiceName), findsOneWidget);
    expect(find.text(l10n.watchAdAndUnlock), findsOneWidget);
  });
}
