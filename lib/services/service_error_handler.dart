import 'package:flutter/material.dart';

import '../utils/app_logger.dart';

/// Shared helper for reporting service-layer errors and user notifications.
class ServiceErrorHandler {
  const ServiceErrorHandler._();

  static void report(
    String message, {
    required Object error,
    required StackTrace stackTrace,
  }) {
    AppLogger.reportError(
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void reportAndNotify({
    required BuildContext context,
    required String message,
    required String userMessage,
    required Object error,
    required StackTrace stackTrace,
  }) {
    report(
      message,
      error: error,
      stackTrace: stackTrace,
    );
    showErrorSnackBar(context: context, message: userMessage);
  }

  static void showErrorSnackBar({
    required BuildContext context,
    required String message,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
