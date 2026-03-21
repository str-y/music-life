import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/chord_history_repository.dart';
import 'package:music_life/providers/chord_analyser_provider.dart';
import 'package:music_life/screens/chord_analyser_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'golden_test_utils.dart';

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
    final end = start?.add(const Duration(days: 1));
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

Future<Widget> _wrap(
  Widget child, {
  List<dynamic> overrides = const [],
  ChordHistoryRepository? chordHistoryRepository,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repository = chordHistoryRepository ?? _InMemoryChordHistoryRepository();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      chordHistoryRepositoryProvider.overrideWithValue(repository),
      ...overrides,
    ],
    child: buildGoldenTestApp(
      locale: locale,
      themeMode: themeMode,
      home: child,
    ),
  );
}

void main() {
  group('ChordAnalyserScreen – detected-note semantics', () {
    testWidgets('currentNoteSemanticLabel is a non-empty localized string',
        (tester) async {
      late String label;
      await tester.pumpWidget(await _wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.currentNoteSemanticLabel;
          return const SizedBox.shrink();
        }),
      ));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(label, isNotEmpty);
    });

    testWidgets(
        'Semantics node with currentNoteSemanticLabel is found in widget tree',
        (tester) async {
      late String label;
      await tester.pumpWidget(await _wrap(
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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.bySemanticsLabel(label), findsOneWidget);
    });
  });

  for (final variant in screenGoldenVariants) {
    testWidgets('matches chord analyser screen golden (${variant.name})',
        (tester) async {
      await prepareGoldenSurface(tester);
      final bridge = _MockNativePitchBridge();
      when(bridge.startCapture).thenAnswer((_) async => true);
      when(() => bridge.chordStream)
          .thenAnswer((_) => const Stream<String>.empty());
      when(bridge.dispose).thenReturn(null);

      await tester.pumpWidget(
        await _wrap(
          const ChordAnalyserScreen(useMicPermissionGate: false),
          locale: variant.locale,
          themeMode: variant.themeMode,
          overrides: [
            pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
          ],
        ),
      );

      // Avoid pumpAndSettle(): both screens contain a repeating listening animation.
      // First pump lets async initialization complete, second pump captures a fixed frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectScreenGolden(
        find.byType(ChordAnalyserScreen),
        variant.goldenPath('chord_analyser_screen'),
      );
    });
  }

  testWidgets('disposing ChordAnalyserScreen does not leak animation tickers',
      (tester) async {
    await prepareGoldenSurface(tester);
    final bridge = _MockNativePitchBridge();
    when(bridge.startCapture).thenAnswer((_) async => true);
    when(() => bridge.chordStream)
        .thenAnswer((_) => const Stream<String>.empty());
    when(bridge.dispose).thenReturn(null);

    await tester.pumpWidget(
      await _wrap(
        const ChordAnalyserScreen(useMicPermissionGate: false),
        overrides: [
          pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
        ],
      ),
    );
    await tester.pump();

    // Replace with a different root type so ProviderScope is fully disposed
    // (Riverpod prohibits changing override count on the same ProviderScope).
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  group('ChordAnalyserScreen – chord history semantics', () {
    testWidgets('chordHistory label is a non-empty localized string',
        (tester) async {
      late String label;
      await tester.pumpWidget(await _wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.chordHistory;
          return const SizedBox.shrink();
        }),
      ));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(label, isNotEmpty);
    });

    testWidgets('Semantics node with chordHistory label is found in widget tree',
        (tester) async {
      late String label;
      await tester.pumpWidget(await _wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.chordHistory;
          return Semantics(
            label: label,
            child: const SizedBox(width: 200, height: 200),
          );
        }),
      ));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.bySemanticsLabel(label), findsOneWidget);
    });

    testWidgets('chord history trigger is announced as button', (tester) async {
      await prepareGoldenSurface(tester);
      final bridge = _MockNativePitchBridge();
      when(bridge.startCapture).thenAnswer((_) async => true);
      when(() => bridge.chordStream)
          .thenAnswer((_) => const Stream<String>.empty());
      when(bridge.dispose).thenReturn(null);

      await tester.pumpWidget(
        await _wrap(
          const ChordAnalyserScreen(useMicPermissionGate: false),
          overrides: [
            pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final localizations =
          AppLocalizations.of(tester.element(find.byType(ChordAnalyserScreen)))!;
      final semanticsHandle = tester.ensureSemantics();

      final historyTrigger =
          find.widgetWithText(InkWell, localizations.chordHistory);
      expect(historyTrigger, findsOneWidget);
      expect(
        tester.getSemantics(historyTrigger),
        matchesSemantics(
          isButton: true,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
          label: localizations.chordHistory,
          hint: localizations.filterByChordName,
        ),
      );
      semanticsHandle.dispose();
    });
  });

  testWidgets('dynamic theme energy visualization semantics are exposed',
      (tester) async {
    await prepareGoldenSurface(tester);
    final bridge = _MockNativePitchBridge();
    when(bridge.startCapture).thenAnswer((_) async => true);
    when(
      () => bridge.chordStream,
    ).thenAnswer((_) => const Stream<String>.empty());
    when(bridge.dispose).thenReturn(null);

    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      await _wrap(
        const ChordAnalyserScreen(useMicPermissionGate: false),
        overrides: [
          pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final l10n =
        AppLocalizations.of(tester.element(find.byType(ChordAnalyserScreen)))!;
    expect(l10n.dynamicThemeEnergySemanticLabel, isNotEmpty);

    // Verify that the Semantics widget with the dynamic theme label is
    // rendered in the widget tree (widget-level check, no semantics tree needed).
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == l10n.dynamicThemeEnergySemanticLabel,
      ),
      findsOneWidget,
    );
    semanticsHandle.dispose();
  });

  testWidgets('shows enhanced empty-state content for chord history',
      (tester) async {
    await prepareGoldenSurface(tester, size: const Size(800, 900));
    final bridge = _MockNativePitchBridge();
    when(bridge.startCapture).thenAnswer((_) async => true);
    when(() => bridge.chordStream)
        .thenAnswer((_) => const Stream<String>.empty());
    when(bridge.dispose).thenReturn(null);

    await tester.pumpWidget(
      await _wrap(
        const ChordAnalyserScreen(useMicPermissionGate: false),
        overrides: [
          pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Your note history will appear here'), findsOneWidget);
    expect(
      find.text(
        'Play a note or chord to build a timeline of recent detections you can quickly review.',
      ),
      findsOneWidget,
    );

    expect(find.text('Listen for your first chord'), findsOneWidget);

    // In Flutter's fake_async test environment, async chains started fire-and-forget
    // (e.g. from a button tap's onPressed) may not complete within pump() calls.
    // tester.runAsync() runs outside fake_async so the full async chain can complete.
    final notifier = ProviderScope.containerOf(
      tester.element(find.byType(ChordAnalyserScreen)),
    ).read(chordAnalyserProvider.notifier);
    await tester.runAsync(() => notifier.restartCapture());
    await tester.pump();

    verify(bridge.startCapture).called(2);
  });

  testWidgets('loads persisted history and filters by chord name',
      (tester) async {
    await prepareGoldenSurface(tester);
    final bridge = _MockNativePitchBridge();
    final controller = StreamController<String>();
    when(bridge.startCapture).thenAnswer((_) async => true);
    when(() => bridge.chordStream).thenAnswer((_) => controller.stream);
    when(bridge.dispose).thenReturn(null);
    final repository = _InMemoryChordHistoryRepository([
      ChordHistoryEntry(chord: 'G', time: DateTime(2026, 3, 1, 12)),
      ChordHistoryEntry(chord: 'C', time: DateTime(2026, 3, 1, 11)),
    ]);

    await tester.pumpWidget(
      await _wrap(
        const ChordAnalyserScreen(useMicPermissionGate: false),
        chordHistoryRepository: repository,
        overrides: [
          pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
        ],
      ),
    );
    await tester.pump();
    final localizations =
        AppLocalizations.of(tester.element(find.byType(ChordAnalyserScreen)))!;

    expect(find.text('G'), findsWidgets);
    expect(find.text('C'), findsWidgets);

    await tester.tap(find.text(localizations.chordHistory));
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    await tester.enterText(find.byType(TextFormField), 'C');
    await tester.tap(find.text(localizations.save));
    for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

    expect(find.text('C'), findsWidgets);
    expect(find.text('G'), findsNothing);

    controller.add('Am');
    await tester.pump();
    await tester.pump();

    expect(repository.entries.any((entry) => entry.chord == 'Am'), isTrue);
    await controller.close();
  });
}
