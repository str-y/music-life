import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/services/permission_service.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:permission_handler/permission_handler.dart';

class _StubPermissionGateway implements PermissionGateway {
  _StubPermissionGateway({
    this.onRequestMicrophonePermission,
    this.onHasMicrophonePermission,
  });

  final Future<PermissionStatus> Function()? onRequestMicrophonePermission;
  final Future<bool> Function()? onHasMicrophonePermission;

  @override
  Future<PermissionStatus> requestMicrophonePermission() {
    return onRequestMicrophonePermission!.call();
  }

  @override
  Future<bool> hasMicrophonePermission() {
    return onHasMicrophonePermission!.call();
  }
}

void main() {
  setUp(AppLogger.clearBufferedLogs);
  tearDown(AppLogger.clearBufferedLogs);

  group('PermissionService', () {
    test('returns microphone request status from gateway', () async {
      final service = PermissionService(
        gateway: _StubPermissionGateway(
          onRequestMicrophonePermission: () async => PermissionStatus.granted,
          onHasMicrophonePermission: () async => false,
        ),
      );

      final status = await service.requestMicrophonePermission();

      expect(status, PermissionStatus.granted);
    });

    test('returns denied and logs when microphone request throws', () async {
      final service = PermissionService(
        gateway: _StubPermissionGateway(
          onRequestMicrophonePermission: () async => throw StateError('boom'),
          onHasMicrophonePermission: () async => false,
        ),
      );

      final status = await service.requestMicrophonePermission();

      expect(status, PermissionStatus.denied);
      expect(
        AppLogger.bufferedLogs.any(
          (line) => line.contains('Failed to request microphone permission.'),
        ),
        isTrue,
      );
    });

    test('returns current microphone permission from gateway', () async {
      final service = PermissionService(
        gateway: _StubPermissionGateway(
          onRequestMicrophonePermission: () async => PermissionStatus.denied,
          onHasMicrophonePermission: () async => true,
        ),
      );

      final granted = await service.hasMicrophonePermission();

      expect(granted, isTrue);
    });

    test('returns false and logs when permission check throws', () async {
      final service = PermissionService(
        gateway: _StubPermissionGateway(
          onRequestMicrophonePermission: () async => PermissionStatus.denied,
          onHasMicrophonePermission: () async => throw StateError('boom'),
        ),
      );

      final granted = await service.hasMicrophonePermission();

      expect(granted, isFalse);
      expect(
        AppLogger.bufferedLogs.any(
          (line) => line.contains('Failed to check microphone permission.'),
        ),
        isTrue,
      );
    });
  });
}
