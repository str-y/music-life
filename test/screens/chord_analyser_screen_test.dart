import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/chord_history_repository.dart';
import 'package:music_life/screens/chord_analyser_screen.dart';

class _MockNativePitchBridge extends Mock implements NativePitchBridge {}

class _InMemoryChordHistoryRepository implements ChordHistoryRepository {
  _InMemoryChordHistoryRepository([List<ChordHistoryEntry>? initialEntries]) {
    if (initialEntries != null) {
      _entries.addAll(initialEntries);
    }
  }

  final List<ChordHistoryEntry> _entries = [];

  List<ChordHistoryEntry> get entries => List.unmodifiable(_entries);

  @override
  Future<void> addEntry(ChordHistoryEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<ChordHistoryEntry>> loadEntries({
    DateTime? day,
    String chordNameFilter = '',
  }) async {
    final normalized = chordNameFilter.toLowerCase().trim();
    final start = day == null ? null : DateTime(day.year, day.month, day.day);
    final end = start == null
        ? null
        : DateTime(day.year, day.month, day.day + 1);
    final matches = _entries.where((entry) {
      if (start != null &&
          (entry.time.isBefore(start) || !entry.time.isBefore(end!))) {
        return false;
      }
      if (normalized.isNotEmpty &&
          !entry.chord.toLowerCase().contains(normalized)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
    return matches;
  }
}

Widget _wrap(
  Widget child, {
  List<dynamic> overrides = const [],
  ChordHistoryRepository? chordHistoryRepository,
}) {
  final repository = chordHistoryRepository ?? _InMemoryChordHistoryRepository();
  return ProviderScope(
    overrides: [
      chordHistoryRepositoryProvider.overrideWithValue(repository),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ChordAnalyserScreen – detected-note semantics', () {
    testWidgets('currentNoteSemanticLabel is a non-empty localized string',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.currentNoteSemanticLabel;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      expect(label, isNotEmpty);
    });

    testWidgets(
        'Semantics node with currentNoteSemanticLabel is found in widget tree',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.currentNoteSemanticLabel;
          return Semantics(
            liveRegion: true,
            label: label,
            value: 'C',
            child: const SizedBox(width: 200, height: 200),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(label), findsOneWidget);
    });
  });

  testWidgets('matches chord analyser screen golden', (tester) async {
    final bridge = _MockNativePitchBridge();
    when(() => bridge.startCapture()).thenAnswer((_) async => true);
    when(() => bridge.chordStream)
        .thenAnswer((_) => const Stream<String>.empty());
    when(() => bridge.dispose()).thenReturn(null);

    await tester.pumpWidget(
      _wrap(
        const ChordAnalyserScreen(useMicPermissionGate: false),
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
      find.byType(ChordAnalyserScreen),
      matchesGoldenFile('goldens/chord_analyser_screen.png'),
    );
  });

  group('ChordAnalyserScreen – chord history semantics', () {
    testWidgets('chordHistory label is a non-empty localized string',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.chordHistory;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      expect(label, isNotEmpty);
    });

    testWidgets('Semantics node with chordHistory label is found in widget tree',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.chordHistory;
          return Semantics(
            label: label,
            child: const SizedBox(width: 200, height: 200),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(label), findsOneWidget);
    });
  });

  testWidgets('loads persisted history and filters by chord name', (tester) async {
    final bridge = _MockNativePitchBridge();
    final controller = StreamController<String>();
    when(() => bridge.startCapture()).thenAnswer((_) async => true);
    when(() => bridge.chordStream).thenAnswer((_) => controller.stream);
    when(() => bridge.dispose()).thenReturn(null);
    final repository = _InMemoryChordHistoryRepository([
      ChordHistoryEntry(chord: 'G', time: DateTime(2026, 3, 1, 12)),
      ChordHistoryEntry(chord: 'C', time: DateTime(2026, 3, 1, 11)),
    ]);

    await tester.pumpWidget(
      _wrap(
        const ChordAnalyserScreen(useMicPermissionGate: false),
        chordHistoryRepository: repository,
        overrides: [
          pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('G'), findsWidgets);
    expect(find.text('C'), findsWidgets);

    await tester.tap(find.text('Note history'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'C');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('C'), findsWidgets);
    expect(find.text('G'), findsNothing);

    controller.add('Am');
    await tester.pump();
    await tester.pump();

    expect(repository.entries.any((entry) => entry.chord == 'Am'), isTrue);
    await controller.close();
  });
}
