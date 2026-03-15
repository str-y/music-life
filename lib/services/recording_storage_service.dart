import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:music_life/utils/app_logger.dart';
const int _bytesPerMegabyte = 1024 * 1024;

class RecordingStorageCheckResult {
  const RecordingStorageCheckResult({
    required this.recordingsDirectoryPath,
    required this.estimatedRequiredBytes,
  });

  final String recordingsDirectoryPath;
  final int estimatedRequiredBytes;

  int get estimatedRequiredMegabytes =>
      (estimatedRequiredBytes + _bytesPerMegabyte - 1) ~/ _bytesPerMegabyte;
}

class RecordingStorageException implements Exception {
  const RecordingStorageException({
    required this.requiredBytes,
    this.cause,
  });

  final int requiredBytes;
  final Object? cause;

  int get requiredMegabytes =>
      (requiredBytes + _bytesPerMegabyte - 1) ~/ _bytesPerMegabyte;
}

abstract interface class RecordingStorageGateway {
  Future<String> getRecordingsDirectoryPath();

  Future<void> verifyWritableSpace(String directoryPath, int requiredBytes);
}

class _DefaultRecordingStorageGateway implements RecordingStorageGateway {
  const _DefaultRecordingStorageGateway();

  static const int _probeChunkBytes = _bytesPerMegabyte;
  static final Uint8List _probeChunk = Uint8List(_probeChunkBytes);
  static final Random _probeRandom = Random();

  @override
  Future<String> getRecordingsDirectoryPath() async {
    final databasesPath = await getDatabasesPath();
    final directory = Directory(p.join(databasesPath, 'recordings'));
    await directory.create(recursive: true);
    return directory.path;
  }

  @override
  Future<void> verifyWritableSpace(String directoryPath, int requiredBytes) async {
    if (requiredBytes <= 0) return;

    final probeFile = File(
      p.join(
        directoryPath,
        '.recording_space_check_'
        '${DateTime.now().microsecondsSinceEpoch}_${_probeRandom.nextInt(1 << 32)}',
      ),
    );

    RandomAccessFile? handle;
    try {
      handle = await probeFile.open(mode: FileMode.write);
      var remainingBytes = requiredBytes;
      while (remainingBytes > 0) {
        final nextChunkBytes = min(remainingBytes, _probeChunk.length);
        await handle.writeFrom(_probeChunk, 0, nextChunkBytes);
        remainingBytes -= nextChunkBytes;
      }
      await handle.flush();
    } finally {
      await handle?.close();
      if (await probeFile.exists()) {
        await probeFile.delete();
      }
    }
  }
}

class RecordingStorageService {
  const RecordingStorageService({
    RecordingStorageGateway gateway = const _DefaultRecordingStorageGateway(),
    Duration estimatedRecordingDuration = const Duration(minutes: 10),
    int estimatedBytesPerSecond = 12 * 1024,
    int safetyMarginBytes = 2 * _bytesPerMegabyte,
  }) : _gateway = gateway,
       _estimatedRecordingDuration = estimatedRecordingDuration,
       _estimatedBytesPerSecond = estimatedBytesPerSecond,
       _safetyMarginBytes = safetyMarginBytes;

  final RecordingStorageGateway _gateway;
  final Duration _estimatedRecordingDuration;
  final int _estimatedBytesPerSecond;
  final int _safetyMarginBytes;

  int get estimatedRequiredBytes =>
      (_estimatedRecordingDuration.inSeconds * _estimatedBytesPerSecond) +
      _safetyMarginBytes;

  int get estimatedRequiredMegabytes =>
      (estimatedRequiredBytes + _bytesPerMegabyte - 1) ~/ _bytesPerMegabyte;

  Future<RecordingStorageCheckResult> prepareForRecording() async {
    final requiredBytes = estimatedRequiredBytes;
    try {
      final directoryPath = await _gateway.getRecordingsDirectoryPath();
      await _gateway.verifyWritableSpace(directoryPath, requiredBytes);
      return RecordingStorageCheckResult(
        recordingsDirectoryPath: directoryPath,
        estimatedRequiredBytes: requiredBytes,
      );
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to verify recording storage availability.',
        error: error,
        stackTrace: stackTrace,
      );
      throw RecordingStorageException(requiredBytes: requiredBytes, cause: error);
    }
  }

  Future<void> deleteFileIfExists(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to delete recording file.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

const defaultRecordingStorageService = RecordingStorageService();
