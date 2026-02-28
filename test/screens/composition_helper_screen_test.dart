import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/composition_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/composition_repository.dart';
import 'package:music_life/screens/composition_helper_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('kMaxCompositions', () {
    test('is 50', () {
      expect(kMaxCompositions, equals(50));
    });
  });

  group('Composition Model', () {
    final comp = Composition(
      id: 'id1',
      title: 'My Song',
      chords: ['C', 'Am', 'F', 'G'],
    );

    test('toJson produces expected map', () {
      final json = comp.toJson();
      expect(json['id'], 'id1');
      expect(json['title'], 'My Song');
      expect(json['chords'], ['C', 'Am', 'F', 'G']);
    });

    test('fromJson round-trips through toJson', () {
      final restored = Composition.fromJson(comp.toJson());
      expect(restored.id, comp.id);
      expect(restored.title, comp.title);
      expect(restored.chords, comp.chords);
    });
  });

  group('CompositionRepository', () {
    test('load returns empty list when no data is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = CompositionRepository(prefs);
      final result = await repo.load();
      expect(result, isEmpty);
    });

    test('load returns compositions when valid JSON is stored', () async {
      SharedPreferences.setMockInitialValues({
        'compositions_v1': '[{"id":"1","title":"Test","chords":["C","G"]}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = CompositionRepository(prefs);
      final result = await repo.load();
      expect(result.length, 1);
      expect(result.first.title, 'Test');
    });
  });

  group('CompositionNotifier – AsyncValue states', () {
    test('build resolves to AsyncData when repository load succeeds', () async {
      final mockRepo = _MockCompositionRepository();
      when(() => mockRepo.load()).thenAnswer((_) async => []);

      final container = ProviderContainer(
        overrides: [
          compositionRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(compositionProvider).isLoading, isTrue);
      await container.read(compositionProvider.future);
      expect(container.read(compositionProvider).hasValue, isTrue);
    });

    test('build exposes AsyncError when repository load fails', () async {
      final mockRepo = _MockCompositionRepository();
      when(() => mockRepo.load()).thenThrow(Exception('test error'));

      final container = ProviderContainer(
        overrides: [
          compositionRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(compositionProvider.future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(compositionProvider).hasError, isTrue);
    });
  });

  group('CompositionHelperScreen – error notifications', () {
    testWidgets('shows load-error SnackBar when stored data is corrupt',
        (tester) async {
      final mockRepo = _MockCompositionRepository();
      when(() => mockRepo.load()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw Exception('test error');
      });

      late String expectedError;
      await tester.runAsync(() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            compositionRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: _wrap(
            Builder(builder: (ctx) {
              expectedError = AppLocalizations.of(ctx)!.compositionLoadError;
              return const CompositionHelperScreen();
            }),
          ),
        ));
        // Allow the 100ms mock delay to complete
        await Future.delayed(const Duration(milliseconds: 200));
      });

      await tester.pump(); // Handle the rebuild after async
      await tester.pump(const Duration(milliseconds: 100)); // Handle SnackBar entrance
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining(expectedError), findsOneWidget);
    });

    testWidgets('shows limit-reached SnackBar when exceeding kMaxCompositions',
        (tester) async {
      final mockRepo = _MockCompositionRepository();
      final existing = List.generate(
        kMaxCompositions,
        (i) => Composition(id: '$i', title: 'C$i', chords: []),
      );

      when(() => mockRepo.load()).thenAnswer((_) => Future.value(existing));
      when(() => mockRepo.save(any())).thenAnswer((_) => Future.value());

      late String expectedError;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          compositionRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: _wrap(
          Builder(builder: (ctx) {
            expectedError = AppLocalizations.of(ctx)!
                .compositionLimitReached(kMaxCompositions);
            return const CompositionHelperScreen();
          }),
        ),
      ));

      // Wait for provider to load
      await tester.pumpAndSettle();

      // Trigger Save Dialog
      await tester.tap(find.text('C'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();

      // Confirm dialog (TextField title is autofocus)
      final saveBtnToken =
          AppLocalizations.of(tester.element(find.byType(AlertDialog)))!.save;
      await tester.tap(find.text(saveBtnToken));

      // Wait for SnackBar
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(expectedError), findsOneWidget);
    });

    testWidgets('adds dynamically built chord from dialog', (tester) async {
      final mockRepo = _MockCompositionRepository();
      when(() => mockRepo.load()).thenAnswer((_) => Future.value([]));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          compositionRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: _wrap(const CompositionHelperScreen()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Builder'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chord_builder_root')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('D').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chord_builder_quality')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Min').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chord_builder_extension')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chord_builder_bass')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chord_builder_add')));
      await tester.pumpAndSettle();

      expect(find.text('Dm7/A'), findsOneWidget);
    });
  });
}

class _MockCompositionRepository extends Mock implements CompositionRepository {}
