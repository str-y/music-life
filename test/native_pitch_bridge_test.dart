import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/services/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';

class _StubPermissionGateway implements PermissionGateway {
  _StubPermissionGateway({
    required this.onHasMicrophonePermission,
  });

  final Future<bool> Function() onHasMicrophonePermission;

  @override
  Future<bool> hasMicrophonePermission() => onHasMicrophonePermission();

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    return PermissionStatus.denied;
  }
}

void main() {
  tearDown(
    NativePitchBridge.resetNativeResourceInitializationCallbackForTesting,
  );

  test('does not initialize native resources during construction', () {
    var initializationAttempts = 0;
    NativePitchBridge.configureNativeResourceInitializationCallbackForTesting(
      () => initializationAttempts++,
    );

    final bridge = NativePitchBridge(
      permissionService: PermissionService(
        gateway: _StubPermissionGateway(
          onHasMicrophonePermission: () async => false,
        ),
      ),
    );

    expect(bridge, isA<NativePitchBridge>());
    expect(initializationAttempts, 0);
  });

  test('does not initialize native resources when permission is denied',
      () async {
    var initializationAttempts = 0;
    NativePitchBridge.configureNativeResourceInitializationCallbackForTesting(
      () => initializationAttempts++,
    );

    final bridge = NativePitchBridge(
      permissionService: PermissionService(
        gateway: _StubPermissionGateway(
          onHasMicrophonePermission: () async => false,
        ),
      ),
    );

    final started = await bridge.startCapture();

    expect(started, isFalse);
    expect(initializationAttempts, 0);
  });

  test('initializes native resources lazily when capture starts', () async {
    var initializationAttempts = 0;
    final reportedErrors = <Object>[];
    NativePitchBridge.configureNativeResourceInitializationCallbackForTesting(
      () => initializationAttempts++,
    );

    final bridge = NativePitchBridge(
      onError: (error, _) => reportedErrors.add(error),
      permissionService: PermissionService(
        gateway: _StubPermissionGateway(
          onHasMicrophonePermission: () async => true,
        ),
      ),
    );

    final started = await bridge.startCapture();

    expect(started, isFalse);
    expect(initializationAttempts, 1);
    expect(reportedErrors, isNotEmpty);
  });
}
