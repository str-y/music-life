// Integration-level widget tests that exercise end-to-end app flows without
// requiring a physical device. They use Riverpod provider overrides
// and SharedPreferences.setMockInitialValues()
// to keep the tests hermetic.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/rhythm_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<Widget> _wrap(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

// ---------------------------------------------------------------------------
// RhythmScreen – metronome controls flow
// ---------------------------------------------------------------------------

void main() {
  group('RhythmScreen – metronome controls flow', () {
    testWidgets('shows default BPM of 120 on launch', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      expect(find.text('120'), findsOneWidget);
    });

    testWidgets('play button is visible and initially shows play icon',
        (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsNothing);
    });

    testWidgets('tapping play switches to stop icon', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('tapping stop after play restores play icon', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('+1 button increments BPM by 1', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+1'));
      await tester.pump();

      expect(find.text('121'), findsOneWidget);
    });

    testWidgets('−1 button decrements BPM by 1', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('−1'));
      await tester.pump();

      expect(find.text('119'), findsOneWidget);
    });

    testWidgets('+10 button increments BPM by 10', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+10'));
      await tester.pump();

      expect(find.text('130'), findsOneWidget);
    });

    testWidgets('−10 button decrements BPM by 10', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('−10'));
      await tester.pump();

      expect(find.text('110'), findsOneWidget);
    });

    testWidgets('BPM does not go below minimum (30)', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      // Tap −10 many times to drive BPM to the floor.
      for (var i = 0; i < 20; i++) {
        await tester.tap(find.text('−10'));
        await tester.pump();
      }

      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('BPM does not exceed maximum (240)', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      // Tap +10 many times to drive BPM to the ceiling.
      for (var i = 0; i < 20; i++) {
        await tester.tap(find.text('+10'));
        await tester.pump();
      }

      expect(find.text('240'), findsOneWidget);
    });

    testWidgets('groove analysis section is visible', (tester) async {
      await tester.pumpWidget(await _wrap(const RhythmScreen()));
      await tester.pumpAndSettle();

      // The groove section shows an initial score readout.
      expect(find.text('100.0'), findsOneWidget);
    });
  });
}
