import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

enum AppLogLevel { trace, debug, info, warning, error }

/// Utility for logging errors with exception and stack-trace details.
///
/// In debug builds, details are printed via [debugPrint]; in all builds the
/// error is forwarded to [FlutterError.reportError] so that registered
/// reporters (e.g. crash-reporting SDKs) receive it.
class AppLogger {
  AppLogger._();

  static const int _maxBufferedLogs = 1000;
  static final List<String> _bufferedLogs = <String>[];

  static AppLogLevel minimumLevel =
      kReleaseMode ? AppLogLevel.info : AppLogLevel.debug;

  static void debug(String message) => log(AppLogLevel.debug, message);

  static void trace(String message) => log(AppLogLevel.trace, message);

  static void info(String message) => log(AppLogLevel.info, message);

  static void warning(String message) => log(AppLogLevel.warning, message);

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      log(
        AppLogLevel.error,
        message,
        error: error,
        stackTrace: stackTrace,
      );

  static void log(
    AppLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) return;
    final timestamp = DateTime.now().toIso8601String();
    final header = '[AppLogger][$timestamp][${level.name.toUpperCase()}] $message';
    final details = StringBuffer(header);
    if (error != null) details.write('\nError: $error');
    if (stackTrace != null) details.write('\n$stackTrace');
    final line = details.toString();
    debugPrint(line);
    _bufferedLogs.add(line);
    if (_bufferedLogs.length > _maxBufferedLogs) {
      _bufferedLogs.removeAt(0);
    }
  }

  /// Logs [message] together with the [error] object and [stackTrace].
  static void reportError(
    String message, {
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.error(
      message,
      error: error,
      stackTrace: stackTrace,
    );
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'music_life',
        context: ErrorDescription(message),
      ),
    );
  }

  static Future<File> exportLogsToFile({String? filePath}) async {
    final resolvedPath = filePath ??
        p.join(
          await getDatabasesPath(),
          'music_life_logs_${DateTime.now().millisecondsSinceEpoch}.log',
        );
    final file = File(resolvedPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(_bufferedLogs.join('\n'), flush: true);
    return file;
  }

  @visibleForTesting
  static List<String> get bufferedLogs => List.unmodifiable(_bufferedLogs);

  @visibleForTesting
  static void clearBufferedLogs() => _bufferedLogs.clear();
}
