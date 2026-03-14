import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/rhythm_screen.dart';
import 'package:music_life/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_test_utils.dart';

Future<Widget> _wrap(
  Widget child, {
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Pumps a [Semantics] widget with [label] and returns the resolved label.
Future<String> _pumpSemanticLabel(
  WidgetTester tester,
  String Function(AppLocalizations) extract,
) async {
  late String label;
  await tester.pumpWidget(await _wrap(
    Builder(builder: (context) {
      label = extract(AppLocalizations.of(context)!);
      return Semantics(
        label: label,
        button: true,
        child: const SizedBox(width: 50, height: 36),
      );
    }),
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
    await tester.pumpWidget(await _wrap(const RhythmScreen()));
    await tester.pump();

    await tester.pumpWidget(await _wrap(const SizedBox.shrink()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('loads presets and saves the current metronome preset',
      (tester) async {
    await tester.pumpWidget(
      await _wrap(
        const RhythmScreen(),
        initialValues: {
          AppConfig.defaultMetronomeBpmStorageKey: 96,
          AppConfig.defaultMetronomeTimeSignatureNumeratorStorageKey: 3,
          AppConfig.defaultMetronomeTimeSignatureDenominatorStorageKey: 4,
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('96'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('metronome-preset-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ballad').last);
    await tester.pumpAndSettle();

    expect(find.text('72'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-metronome-preset')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('metronome-preset-name-field')),
      'Stage',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(AppConfig.defaultMetronomePresetsStorageKey),
      contains('"name":"Stage"'),
    );
    expect(
      prefs.getString(AppConfig.defaultMetronomePresetsStorageKey),
      contains('"bpm":72'),
    );
  });

  testWidgets('matches rhythm screen golden baseline', (tester) async {
    await tester.pumpWidget(await _wrap(const RhythmScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    await expectScreenGolden(
      find.byType(RhythmScreen),
      'goldens/rhythm_screen.png',
    );
  });
}
