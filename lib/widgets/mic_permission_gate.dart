import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';

enum _GateStatus { loading, denied, granted }

/// A widget that gates its [child] behind a microphone-permission check.
///
/// While the request is pending a [CircularProgressIndicator] is shown.
/// If the user denies access, a consistent [MicPermissionDeniedView] is
/// displayed instead.  The [child] is rendered only once permission is granted.
class MicPermissionGate extends StatefulWidget {
  const MicPermissionGate({super.key, required this.child});

  final Widget child;

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
    final status = await Permission.microphone.request();
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

/// Shared permission-denied body used by all mic-dependent screens.
///
/// Shows a [Icons.mic_off] icon, an explanation, an "Open Settings" button,
/// and a retry button whose callback is supplied by the caller.
class MicPermissionDeniedView extends StatelessWidget {
  const MicPermissionDeniedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_off,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.micPermissionRequired,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.settings),
              label: Text(l10n.openSettings),
              onPressed: openAppSettings,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
