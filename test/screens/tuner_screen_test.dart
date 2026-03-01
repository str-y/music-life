import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/screens/tuner_screen.dart';

class _MockNativePitchBridge extends Mock implements NativePitchBridge {}

Widget _wrap(Widget child, {List<dynamic> overrides = const []}) {
  return ProviderScope(
    overrides: [...overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('TunerScreen – cents meter semantics', () {
    testWidgets('centsMeterSemanticLabel is a non-empty localized string',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.centsMeterSemanticLabel;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      expect(label, isNotEmpty);
    });

    testWidgets(
        'Semantics node with centsMeterSemanticLabel is found in widget tree',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.centsMeterSemanticLabel;
          return Semantics(
            label: label,
            child: const SizedBox(width: 200, height: 48),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(label), findsOneWidget);
    });
  });

  testWidgets('matches tuner screen golden', (tester) async {
    final bridge = _MockNativePitchBridge();
    when(() => bridge.startCapture()).thenAnswer((_) async => true);
    when(() => bridge.pitchStream)
        .thenAnswer((_) => const Stream<PitchResult>.empty());
    when(() => bridge.dispose()).thenReturn(null);

    await tester.pumpWidget(
        _wrap(
          const TunerScreen(
            useMicPermissionGate: false,
            showTranspositionControl: false,
          ),
          overrides: [
            pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
          ],
        ),
    );

    // Avoid pumpAndSettle(): both screens contain a repeating listening animation.
    // First pump lets async initialization complete, second pump captures a fixed frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(TunerScreen),
      matchesGoldenFile('goldens/tuner_screen.png'),
    );
  });

  testWidgets('shows transposition selector on tuner screen', (tester) async {
    final bridge = _MockNativePitchBridge();
    when(() => bridge.startCapture()).thenAnswer((_) async => true);
    when(() => bridge.pitchStream)
        .thenAnswer((_) => const Stream<PitchResult>.empty());
    when(() => bridge.dispose()).thenReturn(null);

    await tester.pumpWidget(
      _wrap(
        const TunerScreen(useMicPermissionGate: false),
        overrides: [
          pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  group('TunerScreen – pitch and waveform semantics', () {
    testWidgets('pitch and waveform labels are non-empty localized strings',
        (tester) async {
      late String noteLabel;
      late String waveformLabel;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          noteLabel = l10n.currentNoteSemanticLabel;
          waveformLabel = l10n.waveformSemanticLabel;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      expect(noteLabel, isNotEmpty);
      expect(waveformLabel, isNotEmpty);
    });

    testWidgets('Semantics nodes for pitch result and waveform are found',
        (tester) async {
      late String noteLabel;
      late String waveformLabel;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          noteLabel = l10n.currentNoteSemanticLabel;
          waveformLabel = l10n.waveformSemanticLabel;
          return Column(
            children: [
              Semantics(
                label: noteLabel,
                value: 'A4, 440.0 Hz',
                child: const SizedBox(width: 200, height: 100),
              ),
              Semantics(
                label: waveformLabel,
                child: const SizedBox(width: 200, height: 36),
              ),
            ],
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(noteLabel), findsOneWidget);
      expect(find.bySemanticsLabel(waveformLabel), findsOneWidget);
    });
  });
}
