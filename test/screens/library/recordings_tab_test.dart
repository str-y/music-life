import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/screens/library/recordings_tab.dart';

Widget _wrap(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ProviderScope(child: Scaffold(body: child)),
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

    testWidgets('empty-state CTA calls onCreateRecording', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          RecordingsTab(
            recordings: const [],
            onCreateRecording: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Recording'));
      await tester.pump();

      expect(tapped, isTrue);
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

    testWidgets('formats recording date based on locale', (tester) async {
      final recordedAt = DateTime(2024, 2, 20, 9, 5);
      final recordings = [
        RecordingEntry(
          id: '1',
          title: 'Localized Date',
          recordedAt: recordedAt,
          durationSeconds: 65,
          waveformData: const [],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          RecordingsTab(recordings: recordings),
          locale: const Locale('ja'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat.yMd('ja').add_Hm().format(recordedAt)),
        findsOneWidget,
      );
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

    testWidgets('play button is disabled when entry has no audio file',
        (tester) async {
      final recordings = [
        RecordingEntry(
          id: '1',
          title: 'No Audio',
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

      expect(find.byIcon(Icons.pause_circle), findsNothing);
    });
  });

  group('WaveformPainter', () {
    test('shouldRepaint responds to waveform inputs and animation phase', () {
      final sameData = <double>[0.1, 0.6, 0.3];
      final base = WaveformPainter(
        data: sameData,
        color: Colors.blue,
        breathPhase: 0.0,
      );

      expect(
        base.shouldRepaint(
          WaveformPainter(
            data: sameData,
            color: Colors.blue,
            breathPhase: 0.0,
          ),
        ),
        isFalse,
      );
      expect(
        base.shouldRepaint(
          WaveformPainter(
            data: sameData,
            color: Colors.blue,
            breathPhase: 0.2,
          ),
        ),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          WaveformPainter(
            data: sameData,
            color: Colors.red,
            breathPhase: 0.0,
          ),
        ),
        isTrue,
      );
    });
  });

  group('RecordingTile share', () {
    testWidgets('share button invokes callback when audio file exists',
        (tester) async {
      var shared = false;
      final entry = RecordingEntry(
        id: 'share-1',
        title: 'Share Me',
        recordedAt: DateTime(2024, 6, 1, 8, 30),
        durationSeconds: 45,
        waveformData: const [0.3, 0.5, 0.4],
        audioFilePath: '/tmp/audio.m4a',
      );

      await tester.pumpWidget(
        _wrap(
          RecordingTile(
            entry: entry,
            isPlaying: false,
            progress: 0,
            volume: 1,
            onPlayPause: () {},
            onSeek: null,
            onVolumeChanged: null,
            onShare: () => shared = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.share));
      await tester.pump();

      expect(shared, isTrue);
    });

    test('builds share filename with title/date metadata and extension', () {
      final entry = RecordingEntry(
        id: 'meta-1',
        title: 'Take: 01 / Intro',
        recordedAt: DateTime(2024, 6, 1, 8, 30),
        durationSeconds: 45,
        waveformData: const [],
        audioFilePath: '/tmp/recording.wav',
      );

      expect(
        recordingShareFileName(entry),
        'Take__01___Intro_20240601_0830.wav',
      );
    });
  });
}
