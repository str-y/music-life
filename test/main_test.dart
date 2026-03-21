import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/main.dart' as app;
import 'package:music_life/utils/app_logger.dart';

void main() {
  void Function(FlutterErrorDetails)? previousOnError;

  setUp(() {
    previousOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    AppLogger.clearBufferedLogs();
  });

  tearDown(() {
    FlutterError.onError = previousOnError;
    AppLogger.clearBufferedLogs();
  });

  test('runWithAppErrorLogging logs unhandled asynchronous exceptions', () async {
    await app.runWithAppErrorLogging(() async {
      Future<void>.microtask(() => throw StateError('boom'));
      await Future<void>.delayed(Duration.zero);
    });

    expect(AppLogger.bufferedLogs, isNotEmpty);
    expect(
      AppLogger.bufferedLogs.last,
      contains('Unhandled asynchronous exception'),
    );
    expect(AppLogger.bufferedLogs.last, contains('StateError: boom'));
  });

  test('runWithAppErrorLogging allows successful startup work to complete', () async {
    var didRun = false;

    await app.runWithAppErrorLogging(() async {
      didRun = true;
      await Future<void>.delayed(Duration.zero);
    });

    expect(didRun, isTrue);
    expect(AppLogger.bufferedLogs, isEmpty);
  });
}
