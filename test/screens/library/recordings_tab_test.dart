import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/screens/library/recordings_tab.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('RecordingsTab', () {
    testWidgets('shows empty-state message when recordings list is empty',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const RecordingsTab(recordings: []),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No recordings'), findsOneWidget);
    });

    testWidgets('shows recording title when list has one entry', (tester) async {
      final recordings = [
        RecordingEntry(
          id: '1',
          title: 'My First Take',
          recordedAt: DateTime(2024, 1, 10, 9, 0),
          durationSeconds: 90,
          waveformData: const [0.2, 0.8, 0.4],
        ),
      ];

      await tester.pumpWidget(_wrap(RecordingsTab(recordings: recordings)));
      await tester.pumpAndSettle();

      expect(find.text('My First Take'), findsOneWidget);
    });

    testWidgets('shows formatted duration for each entry', (tester) async {
      final recordings = [
        RecordingEntry(
          id: '1',
          title: 'Short Clip',
          recordedAt: DateTime(2024, 2, 20),
          durationSeconds: 65,
          waveformData: const [],
        ),
      ];

      await tester.pumpWidget(_wrap(RecordingsTab(recordings: recordings)));
      await tester.pumpAndSettle();

      expect(find.text('01:05'), findsOneWidget);
    });

    testWidgets('lists all recordings when multiple entries provided',
        (tester) async {
      final recordings = [
        RecordingEntry(
          id: '1',
          title: 'Take A',
          recordedAt: DateTime(2024, 5, 1),
          durationSeconds: 30,
          waveformData: const [],
        ),
        RecordingEntry(
          id: '2',
          title: 'Take B',
          recordedAt: DateTime(2024, 5, 2),
          durationSeconds: 60,
          waveformData: const [],
        ),
      ];

      await tester.pumpWidget(_wrap(RecordingsTab(recordings: recordings)));
      await tester.pumpAndSettle();

      expect(find.text('Take A'), findsOneWidget);
      expect(find.text('Take B'), findsOneWidget);
    });

    testWidgets('play button toggles to pause when tapped', (tester) async {
      final recordings = [
        RecordingEntry(
          id: '1',
          title: 'Toggle Test',
          recordedAt: DateTime(2024, 3, 5),
          durationSeconds: 120,
          waveformData: const [0.5],
        ),
      ];

      await tester.pumpWidget(_wrap(RecordingsTab(recordings: recordings)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle), findsNothing);

      await tester.tap(find.byIcon(Icons.play_circle));
      await tester.pump();

      expect(find.byIcon(Icons.pause_circle), findsOneWidget);
    });
  });
}
