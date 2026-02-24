import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';

/// A full-screen view shown when microphone permission has been denied.
///
/// Provides an "Open Settings" button (to allow the permission in system
/// settings) and an optional [onRetry] callback to re-request the permission.
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
