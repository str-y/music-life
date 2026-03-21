import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/screens/library/recordings_tab.dart';
import 'package:music_life/widgets/shared/waveform_view.dart';

Widget _wrap(Widget child, {Locale? locale, ThemeData? theme}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: ProviderScope(child: Scaffold(body: child)),
  );
}

void main() {
  group('RecordingsTab', () {
    testWidgets('shows enhanced empty-state content when recordings list is empty',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const RecordingsTab(recordings: []),
      ));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.text('Your recording library is ready'), findsOneWidget);
      expect(
        find.text(
          'Capture your first take to save ideas, replay sessions, and track your progress over time.',
        ),
        findsOneWidget,
      );
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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      await tester.tap(find.text('Start your first recording'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows recording title when list has one entry', (tester) async {
      final recordings = [
        RecordingEntry(
          id: '1',
          title: 'My First Take',
          recordedAt: DateTime(2024, 1, 10, 9),
          durationSeconds: 90,
          waveformData: const [0.2, 0.8, 0.4],
        ),
      ];

      await tester.pumpWidget(_wrap(RecordingsTab(recordings: recordings)));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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
          recordedAt: DateTime(2024, 5),
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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.text('Take A'), findsOneWidget);
      expect(find.text('Take B'), findsOneWidget);
    });

    testWidgets('renders recordings in newest-first order', (tester) async {
      final recordings = [
        RecordingEntry(
          id: 'older',
          title: 'Older',
          recordedAt: DateTime(2024, 5),
          durationSeconds: 30,
          waveformData: const [0.1],
        ),
        RecordingEntry(
          id: 'newer',
          title: 'Newer',
          recordedAt: DateTime(2024, 5, 2),
          durationSeconds: 30,
          waveformData: const [0.1],
        ),
      ];

      await tester.pumpWidget(_wrap(RecordingsTab(recordings: recordings)));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      final titleTexts = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (widget) => widget is Text &&
                  (widget.data == 'Older' || widget.data == 'Newer'),
            ),
          )
          .map((text) => text.data)
          .whereType<String>()
          .toList();

      expect(titleTexts, containsAllInOrder(['Newer', 'Older']));
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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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
      );

      expect(
        base.shouldRepaint(
          WaveformPainter(
            data: sameData,
            color: Colors.blue,
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
          ),
        ),
        isTrue,
      );
    });

    testWidgets('clears static waveform caches when tab is disposed',
        (tester) async {
      WaveformPainter.clearCaches();
      final recordings = [
        RecordingEntry(
          id: '1',
          title: 'Cache Target',
          recordedAt: DateTime(2024, 5),
          durationSeconds: 30,
          waveformData: const [0.2, 0.8, 0.4],
        ),
      ];

      await tester.pumpWidget(_wrap(RecordingsTab(recordings: recordings)));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(WaveformPainter.pathCacheSize, greaterThan(0));
      expect(WaveformPainter.pictureCacheSize, greaterThan(0));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(WaveformPainter.pathCacheSize, 0);
      expect(WaveformPainter.pictureCacheSize, 0);
    });

    testWidgets('reuses waveform caches for equivalent waveform data',
        (tester) async {
      WaveformPainter.clearCaches();

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 240,
            child: WaveformView(
              data: [0.2, 0.8, 0.4],
              durationSeconds: 30,
              isPlaying: false,
              color: Colors.blue,
            ),
          ),
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(WaveformPainter.pathCacheSize, 1);
      expect(WaveformPainter.pictureCacheSize, 1);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 240,
            child: WaveformView(
              data: List<double>.from(const [0.2, 0.8, 0.4]),
              durationSeconds: 30,
              isPlaying: false,
              color: Colors.blue,
            ),
          ),
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(WaveformPainter.pathCacheSize, 1);
      expect(WaveformPainter.pictureCacheSize, 1);
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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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

  testWidgets('loads recording tiles in batches while scrolling', (tester) async {
    final recordings = List.generate(
      45,
      (index) => RecordingEntry(
        id: '$index',
        title: 'Take ${index.toString().padLeft(2, '0')}',
        recordedAt: DateTime(2024, 5).add(Duration(minutes: index)),
        durationSeconds: 30,
        waveformData: const [0.1, 0.2, 0.3],
      ),
    );

    await tester.pumpWidget(_wrap(RecordingsTab(recordings: recordings)));
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    final initialListView = tester.widget<ListView>(find.byType(ListView));
    // 40 visible recordings render as 40 tiles plus 39 separators.
    expect(initialListView.childrenDelegate.estimatedChildCount, 79);

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    final pagedListView = tester.widget<ListView>(find.byType(ListView));
    // After scrolling, all 45 recordings are visible with 44 separators.
    expect(pagedListView.childrenDelegate.estimatedChildCount, 89);
  });
}
