import 'package:flutter/foundation.dart';

/// Utility for logging errors with exception and stack-trace details.
///
/// In debug builds, details are printed via [debugPrint]; in all builds the
/// error is forwarded to [FlutterError.reportError] so that registered
/// reporters (e.g. crash-reporting SDKs) receive it.
class AppLogger {
  AppLogger._();

  /// Logs [message] together with the [error] object and [stackTrace].
  static void reportError(
    String message, {
    required Object error,
    required StackTrace stackTrace,
  }) {
    debugPrint('[AppLogger] $message\nError: $error\n$stackTrace');
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'music_life',
        context: ErrorDescription(message),
      ),
    );
  }
}
