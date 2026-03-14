import 'package:permission_handler/permission_handler.dart';

import '../utils/app_logger.dart';

abstract interface class PermissionGateway {
  Future<PermissionStatus> requestMicrophonePermission();

  Future<bool> hasMicrophonePermission();
}

class _PermissionHandlerGateway implements PermissionGateway {
  const _PermissionHandlerGateway();

  @override
  Future<PermissionStatus> requestMicrophonePermission() {
    return Permission.microphone.request();
  }

  @override
  Future<bool> hasMicrophonePermission() async {
    return Permission.microphone.isGranted;
  }
}

/// Centralizes microphone permission checks/requests and error handling.
class PermissionService {
  const PermissionService({
    PermissionGateway gateway = const _PermissionHandlerGateway(),
  }) : _gateway = gateway;

  final PermissionGateway _gateway;

  /// Requests microphone permission and falls back to denied on errors.
  Future<PermissionStatus> requestMicrophonePermission() async {
    try {
      return await _gateway.requestMicrophonePermission();
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
      return await _gateway.hasMicrophonePermission();
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
