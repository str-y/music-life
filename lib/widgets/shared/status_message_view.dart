import 'package:flutter/material.dart';

/// A reusable centered state view for empty and error messaging.
///
/// This widget keeps icon, message, spacing, and optional action layouts
/// consistent across screens while still letting each caller provide
/// theme-aware colors, typography, and action widgets.
class StatusMessageView extends StatelessWidget {
  const StatusMessageView({
    super.key,
    required this.message,
    this.icon,
    this.action,
    this.iconColor,
    this.messageStyle,
    this.padding = const EdgeInsets.all(24),
    this.iconSize = 48,
  });

  final String message;
  final IconData? icon;
  final Widget? action;
  final Color? iconColor;
  final TextStyle? messageStyle;
  final EdgeInsetsGeometry padding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: iconSize, color: iconColor),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: messageStyle,
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
