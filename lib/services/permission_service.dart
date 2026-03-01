import 'package:permission_handler/permission_handler.dart';

import '../utils/app_logger.dart';

/// Centralizes microphone permission checks/requests and error handling.
class PermissionService {
  const PermissionService();

  /// Requests microphone permission and falls back to denied on errors.
  Future<PermissionStatus> requestMicrophonePermission() async {
    try {
      return await Permission.microphone.request();
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to request microphone permission.',
        error: error,
        stackTrace: stackTrace,
      );
      return PermissionStatus.denied;
    }
  }

  /// Returns whether microphone permission is currently granted.
  Future<bool> hasMicrophonePermission() async {
    try {
      return await Permission.microphone.isGranted;
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to check microphone permission.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

const defaultPermissionService = PermissionService();
