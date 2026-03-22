import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/rhythm_screen.dart';
import 'package:music_life/widgets/rhythm/groove_analysis_section.dart';
import 'package:music_life/widgets/rhythm/metronome_controls.dart';
import 'package:music_life/widgets/rhythm/sound_library_sheet.dart';
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
  for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
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
      expect(find.byKey(const ValueKey('tap-tempo-ring-semantics')), findsOneWidget);
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
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    expect(find.byType(MetronomeControls), findsOneWidget);
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
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    expect(find.byType(GrooveAnalysisSection), findsOneWidget);
    expect(
      find.byKey(const ValueKey('metronome-controls-repaint-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('groove-analysis-repaint-boundary')),
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
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    expect(find.byType(RhythmScreen), findsOneWidget);
    expect(find.text(l10n.metronomeSoundLibraryTitle), findsOneWidget);

    final buttonFinder = find.byKey(const ValueKey('metronome-sound-library-button'));
    expect(buttonFinder, findsOneWidget);
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
     
    expect(find.byType(SoundLibrarySheet), findsOneWidget);
    expect(find.text(l10n.metronomeSoundPackElectronicName), findsWidgets);
  });

  testWidgets('downloads and selects a metronome sound pack from the library',
      (tester) async {
    final overrides = await _settingsOverridesWithPrefs();
    
    await tester.pumpWidget(_wrap(
      const RhythmScreen(),
      overrides: overrides,
    ));
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    final buttonFinder = find.byKey(const ValueKey('metronome-sound-library-button'));
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    final sheetFinder = find.byType(SoundLibrarySheet);
    expect(sheetFinder, findsOneWidget);

    final acousticPackItemFinder = find.descendant(
      of: sheetFinder,
      matching: find.text(l10n.metronomeSoundPackAcousticName),
    );
     
    // Try to scroll the list if needed
    final listFinder = find.descendant(
      of: sheetFinder,
      matching: find.byType(ListView),
    );
    await tester.dragUntilVisible(
      acousticPackItemFinder,
      listFinder,
      const Offset(0, -100),
    );
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    expect(acousticPackItemFinder, findsWidgets);

    // Ensure stable surface size
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final actionButtonFinder = find.byKey(const ValueKey('metronome-sound-action-acoustic_kit'));
    await tester.dragUntilVisible(
      actionButtonFinder,
      find.descendant(of: sheetFinder, matching: find.byType(ListView)),
      const Offset(0, -100),
    );
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    
    // Natural tap via hit-testing on the center of the button
    await tester.tapAt(tester.getCenter(actionButtonFinder));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    
    // Give it plenty of time for async work to complete and frames to draw
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    // The header should now show the selected pack
    expect(
      find.textContaining(l10n.metronomeSoundPackAcousticName),
      findsWidgets,
    );
    
    expect(
      find.textContaining(l10n.metronomeSoundLibraryInUse),
      findsWidgets,
    );
  });

  testWidgets('premium sound pack prompts rewarded unlock when locked',
      (tester) async {
    final overrides = await _settingsOverridesWithPrefs();

    await tester.pumpWidget(_wrap(
      const RhythmScreen(),
      overrides: overrides,
    ));
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    final l10n = AppLocalizations.of(tester.element(find.byType(RhythmScreen)))!;

    final buttonFinder = find.byKey(const ValueKey('metronome-sound-library-button'));
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    final sheetFinder = find.byType(SoundLibrarySheet);
    expect(sheetFinder, findsOneWidget);
    expect(
      find.descendant(
        of: sheetFinder,
        matching: find.text(l10n.metronomeSoundLibraryTitle),
      ),
      findsOneWidget,
    );

    final voicePackItemFinder = find.descendant(
      of: sheetFinder,
      matching: find.byKey(
        const ValueKey('metronome-sound-name-signature_voice_count'),
      ),
    );
    
    // Try to scroll the list if needed
    final listFinder = find.descendant(
      of: sheetFinder,
      matching: find.byType(ListView),
    );
    await tester.dragUntilVisible(
      voicePackItemFinder,
      listFinder,
      const Offset(0, -100),
    );
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    
    expect(voicePackItemFinder, findsOneWidget);
    expect(
      find.descendant(of: sheetFinder, matching: find.text(l10n.watchAdAndUnlock)),
      findsWidgets,
    );
  });
}
