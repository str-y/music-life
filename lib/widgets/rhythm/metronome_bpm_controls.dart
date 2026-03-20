import 'package:flutter/material.dart';
import 'package:music_life/l10n/app_localizations.dart';

class MetronomeBpmControls extends StatelessWidget {
  const MetronomeBpmControls({
    super.key,
    required this.bpm,
    required this.isPlaying,
    required this.beatPulseAnimation,
    required this.onDecrease10,
    required this.onDecrease1,
    required this.onTogglePlayStop,
    required this.onIncrease1,
    required this.onIncrease10,
  });

  final int bpm;
  final bool isPlaying;
  final Animation<double> beatPulseAnimation;
  final VoidCallback onDecrease10;
  final VoidCallback onDecrease1;
  final VoidCallback onTogglePlayStop;
  final VoidCallback onIncrease1;
  final VoidCallback onIncrease10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.3),
                end: Offset.zero,
              ).animate(animation.drive(CurveTween(curve: Curves.easeOut))),
              child: child,
            ),
          ),
          child: Text(
            '$bpm',
            key: ValueKey(bpm),
            style: TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: -4,
            ),
          ),
        ),
        Text(
          l10n.bpmLabel,
          style: const TextStyle(fontSize: 18, letterSpacing: 4),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BpmButton(
              label: '−10',
              semanticLabel: l10n.bpmDecrease10SemanticLabel,
              onPressed: onDecrease10,
            ),
            const SizedBox(width: 8),
            _BpmButton(
              label: '−1',
              semanticLabel: l10n.bpmDecrease1SemanticLabel,
              onPressed: onDecrease1,
            ),
            const SizedBox(width: 24),
            AnimatedBuilder(
              animation: beatPulseAnimation,
              builder: (context, child) {
                final scale = isPlaying
                    ? 1.0 + beatPulseAnimation.value * 0.08
                    : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: FloatingActionButton(
                heroTag: 'playStop',
                onPressed: onTogglePlayStop,
                tooltip: isPlaying
                    ? l10n.metronomeStopTooltip
                    : l10n.metronomePlayTooltip,
                backgroundColor: isPlaying
                    ? colorScheme.error
                    : colorScheme.primary,
                child: Icon(
                  isPlaying ? Icons.stop : Icons.play_arrow,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 24),
            _BpmButton(
              label: '+1',
              semanticLabel: l10n.bpmIncrease1SemanticLabel,
              onPressed: onIncrease1,
            ),
            const SizedBox(width: 8),
            _BpmButton(
              label: '+10',
              semanticLabel: l10n.bpmIncrease10SemanticLabel,
              onPressed: onIncrease10,
            ),
          ],
        ),
      ],
    );
  }
}

class _BpmButton extends StatelessWidget {
  const _BpmButton({
    required this.label,
    required this.onPressed,
    required this.semanticLabel,
  });

  final String label;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(50, 36),
        ),
        child: ExcludeSemantics(child: Text(label)),
      ),
    );
  }
}
