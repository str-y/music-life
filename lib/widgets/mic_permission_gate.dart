import 'package:flutter/material.dart';

import '../services/permission_service.dart';
import 'mic_permission_denied_view.dart';

enum _GateStatus { loading, denied, granted }

/// A widget that gates its [child] behind a microphone-permission check.
///
/// While the request is pending a [CircularProgressIndicator] is shown.
/// If the user denies access, a consistent [MicPermissionDeniedView] is
/// displayed instead.  The [child] is rendered only once permission is granted.
class MicPermissionGate extends StatefulWidget {
  const MicPermissionGate({
    super.key,
    required this.child,
    this.permissionService = defaultPermissionService,
  });

  final Widget child;
  final PermissionService permissionService;

  @override
  State<MicPermissionGate> createState() => _MicPermissionGateState();
}

class _MicPermissionGateState extends State<MicPermissionGate> {
  _GateStatus _status = _GateStatus.loading;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    setState(() => _status = _GateStatus.loading);
    final status = await widget.permissionService.requestMicrophonePermission();
    if (!mounted) return;
    setState(
      () => _status =
          status.isGranted ? _GateStatus.granted : _GateStatus.denied,
    );
  }

  @override
  Widget build(BuildContext context) => switch (_status) {
        _GateStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        _GateStatus.denied =>
          MicPermissionDeniedView(onRetry: _requestPermission),
        _GateStatus.granted => widget.child,
      };
}
