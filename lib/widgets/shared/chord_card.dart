import 'package:flutter/material.dart';

/// A theme-aware chord card container for history and sequence rows.
///
/// Set [highlighted] for the currently active chord so the card uses the
/// primary container tokens and border treatment. Use [padding], [margin], and
/// [child] to adapt the shared surface to each screen's content layout.
class ChordCard extends StatelessWidget {
  const ChordCard({
    required this.child, super.key,
    this.highlighted = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.margin,
    this.opacity = 1.0,
    this.duration = const Duration(milliseconds: 250),
    this.borderWidth = 1.5,
  });

  final Widget child;
  final bool highlighted;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double opacity;
  final Duration duration;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      opacity: opacity,
      duration: duration,
      child: AnimatedContainer(
        duration: duration,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: highlighted
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: highlighted
              ? Border.all(color: colorScheme.primary, width: borderWidth)
              : null,
        ),
        child: child,
      ),
    );
  }
}
