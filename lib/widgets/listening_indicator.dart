import 'package:flutter/material.dart';

/// A pulsing three-bar "listening" animation.
///
/// Pass an [AnimationController] that repeats (with `reverse: true`) to drive
/// the pulse.  The bar colour defaults to the theme's primary colour but can
/// be overridden via [color].
class ListeningIndicator extends StatelessWidget {
  const ListeningIndicator({
    super.key,
    required this.controller,
    this.color,
  });

  /// Animation controller that drives the pulse.  Should be repeating.
  final AnimationController controller;

  /// Bar colour.  Defaults to [ColorScheme.primary] when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final interval = Interval(
              i * 0.15,
              0.55 + i * 0.15,
              curve: Curves.easeInOut,
            );
            final t = interval.transform(controller.value);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 6 + t * 10,
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.35 + t * 0.65),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
