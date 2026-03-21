import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/screens/library_screen.dart';
import 'package:music_life/services/permission_service.dart';
import 'package:music_life/services/recording_storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      const RecordConfig(
        numChannels: 1,
      ),
    );
  });

  group('LibraryScreen recording stability', () {
    testWidgets('shows storage error and skips recorder start when preflight fails',
        (tester) async {
      final repo = _MockRecordingRepository();
      final recorder = _MockAudioRecorder();
      final storageService = _FakeRecordingStorageService(
        estimatedMegabytes: 9,
        onPrepareForRecording: () async {
          throw const RecordingStorageException(requiredBytes: 9 * 1024 * 1024);
        },
      );
      when(repo.loadRecordings).thenAnswer((_) async => const []);
      when(repo.loadPracticeLogs).thenAnswer((_) async => const []);
      when(recorder.dispose).thenAnswer((_) async {});
      when(recorder.isRecording).thenAnswer((_) async => false);

      late String expectedWarning;
      late String expectedError;
      await tester.pumpWidget(
        _wrapLibraryScreen(
          Builder(builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expectedWarning = l10n.recordingStorageEstimateWarning(
              storageService.estimatedRequiredMegabytes,
            );
            expectedError = l10n.recordingStorageCheckFailed(
              storageService.estimatedRequiredMegabytes,
            );
            return LibraryScreen(
              permissionService: _GrantedPermissionService(),
              recordingStorageService: storageService,
              audioRecorderFactory: () => recorder,
            );
          }),
          repository: repo,
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      await tester.tap(find.byType(FloatingActionButton));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.text(expectedWarning), findsOneWidget);

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.mic),
      ));
      await tester.pump();
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.text(expectedError), findsOneWidget);
      verifyNever(() => recorder.start(any(), path: any(named: 'path')));
    });

    testWidgets('cleans up audio file when recording save fails', (tester) async {
      final repo = _MockRecordingRepository();
      final recorder = _MockAudioRecorder();
      final tempDir = await Directory.systemTemp.createTemp(
        'library-screen-recording-test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final storageService = _FakeRecordingStorageService(
        estimatedMegabytes: 9,
        onPrepareForRecording: () async => RecordingStorageCheckResult(
          recordingsDirectoryPath: tempDir.path,
          estimatedRequiredBytes: 9 * 1024 * 1024,
        ),
      );
      when(repo.loadRecordings).thenAnswer((_) async => const []);
      when(repo.loadPracticeLogs).thenAnswer((_) async => const []);
      when(() => repo.saveRecordings(any())).thenThrow(Exception('save failed'));
      when(recorder.dispose).thenAnswer((_) async {});
      when(recorder.isRecording).thenAnswer((_) async => false);
      when(recorder.stop).thenAnswer((_) async => null);
      when(
        () => recorder.onAmplitudeChanged(const Duration(milliseconds: 120)),
      ).thenAnswer((_) => const Stream<Amplitude>.empty());
      when(() => recorder.start(any(), path: any(named: 'path'))).thenAnswer((
        invocation,
      ) async {
        final path =
            invocation.namedArguments[const Symbol('path')]! as String;
        await File(path).writeAsBytes(<int>[1, 2, 3]);
      });

      late String expectedError;
      await tester.pumpWidget(
        _wrapLibraryScreen(
          Builder(builder: (context) {
            expectedError = AppLocalizations.of(context)!.recordingSaveFailed;
            return LibraryScreen(
              permissionService: _GrantedPermissionService(),
              recordingStorageService: storageService,
              audioRecorderFactory: () => recorder,
            );
          }),
          repository: repo,
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      await tester.tap(find.byType(FloatingActionButton));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.mic),
      ));
      await tester.pump();
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      await tester.tap(
        find.text(
          AppLocalizations.of(tester.element(find.byType(AlertDialog)))!.save,
        ),
      );
      await tester.pump();
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.text(expectedError), findsOneWidget);
      expect((await tempDir.list().toList()).isEmpty, isTrue);
    });
  });
}

Widget _wrapLibraryScreen(
  Widget child, {
  required RecordingRepository repository,
}) {
  return ProviderScope(
    overrides: [
      recordingRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

class _GrantedPermissionService extends PermissionService {
  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    return PermissionStatus.granted;
  }

  @override
  Future<bool> hasMicrophonePermission() async => true;
}

class _FakeRecordingStorageService extends RecordingStorageService {
  _FakeRecordingStorageService({
    required this.onPrepareForRecording,
    required this.estimatedMegabytes,
  });

  final Future<RecordingStorageCheckResult> Function() onPrepareForRecording;
  final int estimatedMegabytes;

  @override
  int get estimatedRequiredMegabytes => estimatedMegabytes;

  @override
  Future<RecordingStorageCheckResult> prepareForRecording() {
    return onPrepareForRecording();
  }
}

class _MockRecordingRepository extends Mock implements RecordingRepository {}

class _MockAudioRecorder extends Mock implements AudioRecorder {}
