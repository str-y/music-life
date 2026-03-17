import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/rhythm_provider.dart';

class GrooveAnalysisSection extends StatelessWidget {
  const GrooveAnalysisSection({
    super.key,
    required this.colorScheme,
    required this.rhythmState,
    required this.beatPulseAnimation,
    required this.tapRingAnimation,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final RhythmState rhythmState;
  final Animation<double> beatPulseAnimation;
  final Animation<double> tapRingAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scoreRatio = rhythmState.timingScore / 100.0;
    final offsetLabel = rhythmState.isPlaying
        ? (rhythmState.lastOffsetMs >= 0
            ? '+${rhythmState.lastOffsetMs.toStringAsFixed(0)} ms'
            : '${rhythmState.lastOffsetMs.toStringAsFixed(0)} ms')
        : '---';
    final scoreColor = Color.lerp(
      colorScheme.error,
      colorScheme.primary,
      scoreRatio,
    )!;

    return Semantics(
      label: l10n.grooveTargetSemanticLabel,
      onTapHint: l10n.grooveTargetTapHint,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: colorScheme.surfaceContainerHighest,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.grooveAnalysis,
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 2,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RepaintBoundary(
                  child: Semantics(
                    label: l10n.tapTempoRingSemanticLabel,
                    excludeSemantics: true,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        beatPulseAnimation,
                        tapRingAnimation,
                      ]),
                      builder: (context, _) {
                        return CustomPaint(
                          painter: GrooveTargetPainter(
                            beatPhase: beatPulseAnimation.value,
                            tapPhase: tapRingAnimation.value,
                            offsetMs: rhythmState.lastOffsetMs,
                            beatDurationMs: rhythmState.beatDuration.inMilliseconds
                                .toDouble(),
                            isPlaying: rhythmState.isPlaying,
                            primaryColor: colorScheme.primary,
                            errorColor: colorScheme.error,
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          l10n.timing,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          offsetLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          l10n.score,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          rhythmState.timingScore.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                    if (rhythmState.isPlaying)
                      Text(
                        l10n.tapRhythmHint,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GrooveTargetPainter extends CustomPainter {
  const GrooveTargetPainter({
    required this.beatPhase,
    required this.tapPhase,
    required this.offsetMs,
    required this.beatDurationMs,
    required this.isPlaying,
    required this.primaryColor,
    required this.errorColor,
  });

  final double beatPhase;
  final double tapPhase;
  final double offsetMs;
  final double beatDurationMs;
  final bool isPlaying;
  final Color primaryColor;
  final Color errorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 8;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = primaryColor.withValues(alpha: 60 / 255);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * i / 3, ringPaint);
    }

    if (isPlaying && beatPhase > 0) {
      final pulseRadius = maxRadius * (0.1 + 0.9 * beatPhase);
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = primaryColor.withValues(alpha: (1 - beatPhase) * 220 / 255);
      canvas.drawCircle(center, pulseRadius, pulsePaint);
      if (beatPhase < 0.25) {
        final flashOpacity = (1 - beatPhase / 0.25) * 40 / 255;
        canvas.drawCircle(
          center,
          maxRadius * 0.3 * (beatPhase / 0.25),
          Paint()
            ..style = PaintingStyle.fill
            ..color = primaryColor.withValues(alpha: flashOpacity),
        );
      }
    }

    canvas.drawCircle(
      center,
      8,
      Paint()..color = primaryColor,
    );

    if (tapPhase > 0) {
      final maxOffset = beatDurationMs / 2;
      final accuracy = 1 - (offsetMs.abs() / maxOffset).clamp(0.0, 1.0);
      final tapRadius = maxRadius * (1 - accuracy * 0.7);
      final tapColor = Color.lerp(errorColor, primaryColor, accuracy)!;

      final tapPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - tapPhase)
        ..color = tapColor.withValues(alpha: (1 - tapPhase) * 230 / 255);
      canvas.drawCircle(center, tapRadius, tapPaint);
    }
  }

  @override
  bool shouldRepaint(GrooveTargetPainter oldDelegate) =>
      oldDelegate.beatPhase != beatPhase ||
      oldDelegate.tapPhase != tapPhase ||
      oldDelegate.offsetMs != offsetMs ||
      oldDelegate.beatDurationMs != beatDurationMs ||
      oldDelegate.isPlaying != isPlaying ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.errorColor != errorColor;
}
