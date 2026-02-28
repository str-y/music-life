import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    late AppLogLevel originalLevel;

    setUp(() {
      originalLevel = AppLogger.minimumLevel;
      AppLogger.clearBufferedLogs();
    });

    tearDown(() {
      AppLogger.minimumLevel = originalLevel;
      AppLogger.clearBufferedLogs();
    });

    test('filters logs by minimum level', () {
      AppLogger.minimumLevel = AppLogLevel.warning;

      AppLogger.debug('debug');
      AppLogger.info('info');
      AppLogger.warning('warning');
      AppLogger.error('error');

      final logs = AppLogger.bufferedLogs;
      expect(logs.length, 2);
      expect(logs[0], contains('[WARNING] warning'));
      expect(logs[1], contains('[ERROR] error'));
    });

    test('keeps only the latest 1000 buffered logs', () {
      for (var i = 0; i < 1005; i++) {
        AppLogger.info('entry $i');
      }

      final logs = AppLogger.bufferedLogs;
      expect(logs.length, 1000);
      expect(logs.first, contains('[INFO] entry 5'));
      expect(logs.last, contains('[INFO] entry 1004'));
    });

    test('reportError forwards errors to FlutterError.reportError', () {
      FlutterErrorDetails? captured;
      final previousHandler = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        captured = details;
      };
      addTearDown(() => FlutterError.onError = previousHandler);

      final trace = StackTrace.current;
      AppLogger.reportError(
        'failed to load',
        error: StateError('boom'),
        stackTrace: trace,
      );

      expect(captured, isNotNull);
      expect(captured!.context.toString(), contains('failed to load'));
    });

    test('exports buffered logs to file', () async {
      AppLogger.info('hello');
      final tempDir = await Directory.systemTemp.createTemp('app_logger_test');
      addTearDown(() async => tempDir.delete(recursive: true));
      final filePath = '${tempDir.path}/diagnostics.log';

      final file = await AppLogger.exportLogsToFile(filePath: filePath);
      final content = await file.readAsString();
      final lines = content.split('\n');

      expect(file.path, filePath);
      expect(lines.length, 1);
      expect(content, contains('[INFO] hello'));
    });
  });
}
