import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rhythm & Metronome screen.
///
/// Features:
///  - Pro-grade metronome: large BPM display with +/− controls and a
///    play/stop button.
///  - Groove analysis: the lower half of the screen shows an animated
///    "target" (concentric rings).  When the user taps on the beat the ring
///    animates to show how far from the perfect grid the tap was.
class RhythmScreen extends StatefulWidget {
  const RhythmScreen({super.key});

  @override
  State<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends State<RhythmScreen>
    with TickerProviderStateMixin {
  // ── Metronome state ──────────────────────────────────────────────────────
  int _bpm = 120;
  bool _isPlaying = false;
  Timer? _ticker;
  int _beatCount = 0;

  // ── Groove analysis state ────────────────────────────────────────────────
  /// Offset of the last user tap relative to the ideal beat, in milliseconds.
  /// Negative = early, positive = late.
  double _lastOffsetMs = 0;

  /// Cumulative timing score [0–100].
  double _timingScore = 100;

  /// Timestamp of the last scheduled beat (for tap comparison).
  DateTime? _lastBeatTime;

  /// Animation controller for the target ring pulse on each beat.
  late final AnimationController _beatPulseCtrl;
  late final Animation<double> _beatPulseAnim;

  /// Animation controller for the user-tap impact ring.
  late final AnimationController _tapRingCtrl;
  late final Animation<double> _tapRingAnim;

  static const int _minBpm = 30;
  static const int _maxBpm = 240;

  // ── Timing helpers ───────────────────────────────────────────────────────
  Duration get _beatDuration => Duration(
        microseconds: (60 * 1000 * 1000 ~/ _bpm),
      );

  void _startMetronome() {
    _ticker?.cancel();
    _beatCount = 0;
    _lastBeatTime = DateTime.now();
    _beatPulseCtrl.forward(from: 0);
    _ticker = Timer.periodic(_beatDuration, (_) {
      _lastBeatTime = DateTime.now();
      _beatPulseCtrl.forward(from: 0);
      setState(() => _beatCount++);
    });
    setState(() => _isPlaying = true);
  }

  void _stopMetronome() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _isPlaying = false;
      _beatCount = 0;
    });
  }

  void _toggleMetronome() {
    if (_isPlaying) {
      _stopMetronome();
    } else {
      _startMetronome();
    }
  }

  void _changeBpm(int delta) {
    setState(() {
      _bpm = (_bpm + delta).clamp(_minBpm, _maxBpm);
    });
    if (_isPlaying) {
      _startMetronome(); // restart at new tempo
    }
  }

  // ── Groove tap ───────────────────────────────────────────────────────────
  void _onGrooveTap() {
    if (!_isPlaying || _lastBeatTime == null) return;

    final now = DateTime.now();
    final beatMs = _beatDuration.inMilliseconds.toDouble();
    final elapsedMs =
        now.difference(_lastBeatTime!).inMilliseconds.toDouble();

    // Map elapsed time to [-beatMs/2, +beatMs/2].
    double offset = elapsedMs;
    if (offset > beatMs / 2) offset -= beatMs;

    setState(() {
      _lastOffsetMs = offset;
      // Score penalty: proportional to |offset| / (beatMs/2), capped at 20 pts.
      final penalty = (offset.abs() / (beatMs / 2)) * 20;
      _timingScore = (_timingScore - penalty).clamp(0, 100);
    });

    _tapRingCtrl.forward(from: 0);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _beatPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _beatPulseAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _beatPulseCtrl, curve: Curves.easeOut),
    );

    _tapRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tapRingAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tapRingCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _beatPulseCtrl.dispose();
    _tapRingCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('リズム & メトロノーム'),
      ),
      body: Column(
        children: [
          // ── Top half: metronome controls ────────────────────────────────
          Expanded(
            child: _buildMetronomeSection(colorScheme),
          ),
          const Divider(height: 1),
          // ── Bottom half: groove analysis target ─────────────────────────
          Expanded(
            child: _buildGrooveSection(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildMetronomeSection(ColorScheme cs) {
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // BPM display
          Text(
            '$_bpm',
            style: TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.bold,
              color: cs.primary,
              letterSpacing: -4,
            ),
          ),
          const Text(
            'BPM',
            style: TextStyle(fontSize: 18, letterSpacing: 4),
          ),
          const SizedBox(height: 16),
          // BPM controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BpmButton(
                label: '−10',
                onPressed: () => _changeBpm(-10),
              ),
              const SizedBox(width: 8),
              _BpmButton(
                label: '−1',
                onPressed: () => _changeBpm(-1),
              ),
              const SizedBox(width: 24),
              // Play / Stop button
              AnimatedBuilder(
                animation: _beatPulseAnim,
                builder: (context, child) {
                  final scale = _isPlaying
                      ? 1.0 + _beatPulseAnim.value * 0.08
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: FloatingActionButton(
                  heroTag: 'playStop',
                  onPressed: _toggleMetronome,
                  backgroundColor: _isPlaying
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  child: Icon(
                    _isPlaying ? Icons.stop : Icons.play_arrow,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _BpmButton(
                label: '+1',
                onPressed: () => _changeBpm(1),
              ),
              const SizedBox(width: 8),
              _BpmButton(
                label: '+10',
                onPressed: () => _changeBpm(10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrooveSection(ColorScheme cs) {
    final scoreRatio = _timingScore / 100.0;
    final offsetLabel = _isPlaying
        ? (_lastOffsetMs >= 0
            ? '+${_lastOffsetMs.toStringAsFixed(0)} ms'
            : '${_lastOffsetMs.toStringAsFixed(0)} ms')
        : '---';
    final scoreColor = Color.lerp(cs.error, cs.primary, scoreRatio)!;

    return GestureDetector(
      onTap: _onGrooveTap,
      child: Container(
        color: cs.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'グルーヴ解析',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 2,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // Animated target
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([_beatPulseAnim, _tapRingAnim]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _GrooveTargetPainter(
                      beatPhase: _beatPulseAnim.value,
                      tapPhase: _tapRingAnim.value,
                      offsetMs: _lastOffsetMs,
                      beatDurationMs: _beatDuration.inMilliseconds.toDouble(),
                      isPlaying: _isPlaying,
                      primaryColor: cs.primary,
                      errorColor: cs.error,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
            // Score readout
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(
                        'タイミング',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
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
                        'スコア',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _timingScore.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                  if (_isPlaying)
                    Text(
                      'タップしてリズムを刻もう',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── BPM helper button ────────────────────────────────────────────────────────

class _BpmButton extends StatelessWidget {
  const _BpmButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(50, 36),
      ),
      child: Text(label),
    );
  }
}

// ── Groove target painter ────────────────────────────────────────────────────

class _GrooveTargetPainter extends CustomPainter {
  const _GrooveTargetPainter({
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

    // Draw concentric static rings.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = primaryColor.withValues(alpha: 60 / 255);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * i / 3, ringPaint);
    }

    // Beat pulse: expanding ring that fades out.
    if (isPlaying && beatPhase > 0) {
      final pulseRadius = maxRadius * 0.3 * beatPhase;
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = primaryColor.withValues(alpha: (1 - beatPhase) * 200 / 255);
      canvas.drawCircle(center, pulseRadius, pulsePaint);
    }

    // Center dot.
    canvas.drawCircle(
      center,
      8,
      Paint()..color = primaryColor,
    );

    // Tap impact ring: radius encodes timing accuracy.
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
  bool shouldRepaint(_GrooveTargetPainter old) =>
      old.beatPhase != beatPhase ||
      old.tapPhase != tapPhase ||
      old.offsetMs != offsetMs ||
      old.isPlaying != isPlaying;
}
