import 'package:flutter/material.dart';

/// A reusable centered state view for empty and error messaging.
///
/// This widget keeps icon, message, spacing, and optional action layouts
/// consistent across screens while still letting each caller provide
/// theme-aware colors, typography, and action widgets.
class StatusMessageView extends StatelessWidget {
  const StatusMessageView({
    required this.message,
    super.key,
    this.details,
    this.icon,
    this.illustration,
    this.action,
    this.iconColor,
    this.messageStyle,
    this.detailsStyle,
    this.padding = const EdgeInsets.all(24),
    this.iconSize = 48,
  });

  final String message;
  final String? details;
  final IconData? icon;
  final Widget? illustration;
  final Widget? action;
  final Color? iconColor;
  final TextStyle? messageStyle;
  final TextStyle? detailsStyle;
  final EdgeInsetsGeometry padding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (illustration != null || icon != null) ...[
                illustration ?? Icon(icon, size: iconSize, color: iconColor),
                const SizedBox(height: 12),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: messageStyle,
              ),
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!,
                  textAlign: TextAlign.center,
                  style: detailsStyle,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StatusMessageIllustration extends StatelessWidget {
  const StatusMessageIllustration({
    required this.primaryIcon,
    required this.accentIcon,
    required this.colorScheme,
    super.key,
  });

  final IconData primaryIcon;
  final IconData accentIcon;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Icon(primaryIcon, size: 32, color: colorScheme.primary),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: -2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  accentIcon,
                  size: 18,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
