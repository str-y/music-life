import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/services/recording_storage_service.dart';
import 'package:path/path.dart' as p;

class _StubRecordingStorageGateway implements RecordingStorageGateway {
  _StubRecordingStorageGateway({
    required this.directoryPath,
    required this.onVerifyWritableSpace,
  });

  final String directoryPath;
  final Future<void> Function(String directoryPath, int requiredBytes)
  onVerifyWritableSpace;

  @override
  Future<String> getRecordingsDirectoryPath() async => directoryPath;

  @override
  Future<void> verifyWritableSpace(String directoryPath, int requiredBytes) {
    return onVerifyWritableSpace(directoryPath, requiredBytes);
  }
}

void main() {
  group('RecordingStorageService', () {
    test('prepareForRecording returns directory and estimated bytes', () async {
      late String verifiedDirectoryPath;
      late int verifiedRequiredBytes;
      final service = RecordingStorageService(
        gateway: _StubRecordingStorageGateway(
          directoryPath: '/tmp/recordings',
          onVerifyWritableSpace: (directoryPath, requiredBytes) async {
            verifiedDirectoryPath = directoryPath;
            verifiedRequiredBytes = requiredBytes;
          },
        ),
        estimatedRecordingDuration: const Duration(minutes: 5),
        estimatedBytesPerSecond: 1000,
        safetyMarginBytes: 500,
      );

      final result = await service.prepareForRecording();

      expect(verifiedDirectoryPath, '/tmp/recordings');
      expect(verifiedRequiredBytes, 300500);
      expect(result.recordingsDirectoryPath, '/tmp/recordings');
      expect(result.estimatedRequiredBytes, 300500);
      expect(result.estimatedRequiredMegabytes, 1);
    });

    test('prepareForRecording wraps storage errors with estimate', () async {
      final service = RecordingStorageService(
        gateway: _StubRecordingStorageGateway(
          directoryPath: '/tmp/recordings',
          onVerifyWritableSpace: (_, _) async {
            throw const FileSystemException('disk full');
          },
        ),
        estimatedRecordingDuration: const Duration(minutes: 1),
        estimatedBytesPerSecond: 1024,
        safetyMarginBytes: 1024,
      );

      await expectLater(
        service.prepareForRecording(),
        throwsA(
          isA<RecordingStorageException>()
              .having((error) => error.requiredBytes, 'requiredBytes', 62464)
              .having((error) => error.requiredMegabytes, 'requiredMegabytes', 1),
        ),
      );
    });

    test('deleteFileIfExists removes existing files and ignores missing ones',
        () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'recording-storage-service-test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final file = File(p.join(tempDir.path, 'sample.m4a'));
      await file.writeAsString('audio');
      final service = RecordingStorageService(
        gateway: _StubRecordingStorageGateway(
          directoryPath: tempDir.path,
          onVerifyWritableSpace: (_, _) async {},
        ),
      );

      await service.deleteFileIfExists(file.path);
      await service.deleteFileIfExists(file.path);
      await service.deleteFileIfExists(null);
      await service.deleteFileIfExists('');

      expect(await file.exists(), isFalse);
    });
  });
}
