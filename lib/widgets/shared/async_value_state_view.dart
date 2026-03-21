import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/widgets/shared/loading_state_widget.dart';
import 'package:music_life/widgets/shared/status_message_view.dart';

class AsyncValueStateView<T> extends StatelessWidget {
  const AsyncValueStateView({
    required this.value, required this.data, required this.errorMessage, super.key,
    this.loadingSemanticsLabel,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final String errorMessage;
  final String? loadingSemanticsLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => LoadingStateWidget(semanticsLabel: loadingSemanticsLabel),
      error: (_, _) => StatusMessageView(
        icon: Icons.error_outline,
        iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        message: errorMessage,
        messageStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        action: onRetry == null
            ? null
            : ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.retry),
              ),
      ),
      data: data,
    );
  }
}
