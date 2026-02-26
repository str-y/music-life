import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../repositories/recording_repository.dart';

// ---------------------------------------------------------------------------
// Recordings tab
// ---------------------------------------------------------------------------

class RecordingsTab extends StatefulWidget {
  const RecordingsTab({super.key, required this.recordings});

  final List<RecordingEntry> recordings;

  @override
  State<RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends State<RecordingsTab> {
  String? _playingId;
  double _positionRatio = 0;
  DateTime? _playbackStart;
  Duration _playbackDuration = Duration.zero;
  Timer? _progressTicker;

  late List<RecordingEntry> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.recordings]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  @override
  void didUpdateWidget(RecordingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recordings != oldWidget.recordings) {
      _sorted = [...widget.recordings]
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    }
  }

  void _startProgressTicker() {
    _progressTicker?.cancel();
    _progressTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _playingId == null || _playbackStart == null) return;
      final elapsed = DateTime.now().difference(_playbackStart!);
      final nextRatio = _playbackDuration.inMilliseconds <= 0
          ? 0.0
          : (elapsed.inMilliseconds / _playbackDuration.inMilliseconds).clamp(0.0, 1.0);
      if (nextRatio >= 1) {
        setState(() {
          _playingId = null;
          _positionRatio = 0;
          _playbackStart = null;
        });
        _progressTicker?.cancel();
        return;
      }
      setState(() {
        _positionRatio = nextRatio;
      });
    });
  }

  void _togglePlayback(String id) {
    final selected = widget.recordings.firstWhere((entry) => entry.id == id);
    setState(() {
      if (_playingId == id) {
        _playingId = null;
        _positionRatio = 0;
        _playbackStart = null;
        _progressTicker?.cancel();
        return;
      }
      _playingId = id;
      _positionRatio = 0;
      _playbackStart = DateTime.now();
      _playbackDuration = Duration(seconds: selected.durationSeconds);
    });
    _startProgressTicker();
    SystemSound.play(SystemSoundType.click);
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sorted.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noRecordings,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _sorted[index];
        final isPlaying = _playingId == entry.id;
        return RecordingTile(
          entry: entry,
          isPlaying: isPlaying,
          progress: isPlaying ? _positionRatio : 0,
          onPlayPause: () => _togglePlayback(entry.id),
        );
      },
    );
  }
}

class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.entry,
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
  });

  final RecordingEntry entry;
  final bool isPlaying;
  final double progress;
  final VoidCallback onPlayPause;

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            iconSize: 40,
            color: colorScheme.primary,
            onPressed: onPlayPause,
            tooltip: isPlaying ? l10n.pause : l10n.play,
          ),
          title: Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _formatDate(entry.recordedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            entry.formattedDuration,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          onTap: onPlayPause,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WaveformView(
                data: entry.waveformData,
                isPlaying: isPlaying,
                color: isPlaying ? colorScheme.primary : colorScheme.outlineVariant,
              ),
              if (isPlaying) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Waveform painter
// ---------------------------------------------------------------------------

class WaveformView extends StatefulWidget {
  const WaveformView({
    super.key,
    required this.data,
    required this.isPlaying,
    required this.color,
  });

  final List<double> data;
  final bool isPlaying;
  final Color color;

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) _breathCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(WaveformView old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _breathCtrl.repeat(reverse: true);
      } else {
        _breathCtrl.stop();
        _breathCtrl.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Visual waveform representation of the recording',
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        child: AnimatedBuilder(
          animation: _breathCtrl,
          builder: (_, __) => CustomPaint(
            painter: WaveformPainter(
              data: widget.data,
              color: widget.color,
              breathPhase: _breathCtrl.value,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.data,
    required this.color,
    this.breathPhase = 0.0,
  });

  final List<double> data;
  final Color color;
  final double breathPhase;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final barCount = data.length;
    final totalSpacing = size.width;
    final barWidth = totalSpacing / (barCount * 1.6);
    final gap = barWidth * 0.6;
    final step = barWidth + gap;
    final centerY = size.height / 2;
    final breathScale = 1.0 + breathPhase * 0.22;

    for (var i = 0; i < barCount; i++) {
      final x = i * step + barWidth / 2;
      final halfHeight =
          (data[i] * centerY * breathScale).clamp(2.0, centerY);
      canvas.drawLine(
        Offset(x, centerY - halfHeight),
        Offset(x, centerY + halfHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.data != data ||
      oldDelegate.breathPhase != breathPhase;
}
