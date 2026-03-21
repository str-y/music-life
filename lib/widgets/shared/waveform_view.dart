import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:music_life/l10n/app_localizations.dart';
/// A shared waveform renderer for recorded and live-preview audio.
///
/// Use [isPlaying] for playback-driven animation and [animate] for non-playback
/// active states such as live recording preview. The [data], [durationSeconds],
/// and [color] parameters fully describe the rendered waveform.
class WaveformView extends StatefulWidget {
  const WaveformView({
    required this.data, required this.durationSeconds, required this.isPlaying, required this.color, super.key,
    this.animate = false,
  });

  final List<double> data;
  final int durationSeconds;
  /// True when actual audio playback is active.
  final bool isPlaying;
  /// True for non-playback active states (e.g. live recording preview).
  final bool animate;
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
    if (widget.isPlaying || widget.animate) _breathCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(WaveformView old) {
    super.didUpdateWidget(old);
    if ((widget.isPlaying || widget.animate) !=
        (old.isPlaying || old.animate)) {
      if (widget.isPlaying || widget.animate) {
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
    final l10n = AppLocalizations.of(context)!;
    final m = widget.durationSeconds ~/ 60;
    final s = widget.durationSeconds % 60;
    final durationStr =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Semantics(
      label: l10n.waveformSemanticLabel,
      value: l10n.waveformSemanticValue(durationStr),
      excludeSemantics: true,
      child: SizedBox(
        height: 48,
        child: AnimatedBuilder(
          animation: _breathCtrl,
          builder: (_, _) => CustomPaint(
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
  // Keep cache bounded for list scrolling scenarios while avoiding unbounded
  // picture/path growth in memory.
  static const int _maxCacheEntries = 128;
  static const double _breathScaleFactor = 0.22;
  static final LinkedHashMap<String, Path> _pathCache =
      LinkedHashMap<String, Path>();
  static final LinkedHashMap<String, ui.Picture> _pictureCache =
      LinkedHashMap<String, ui.Picture>();

  static int get pathCacheSize => _pathCache.length;
  static int get pictureCacheSize => _pictureCache.length;

  static void clearCaches() {
    for (final picture in _pictureCache.values) {
      picture.dispose();
    }
    _pictureCache.clear();
    _pathCache.clear();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final centerY = size.height / 2;
    final breathScale = 1.0 + breathPhase * _breathScaleFactor;
    final dataHash = Object.hashAll(data);
    final cacheKey =
        '$dataHash:${size.width.toStringAsFixed(2)}:${size.height.toStringAsFixed(2)}';
    var basePath = _pathCache.remove(cacheKey);
    if (basePath != null) {
      _pathCache[cacheKey] = basePath;
    } else {
      if (_pathCache.length >= _maxCacheEntries) {
        // Path does not own external resources and does not require disposal.
        _pathCache.remove(_pathCache.keys.first);
      }
      basePath = _buildBasePath(data, size);
      _pathCache[cacheKey] = basePath;
    }
    final pictureKey = '$cacheKey:${color.toARGB32()}';
    var picture = _pictureCache.remove(pictureKey);
    if (picture != null) {
      _pictureCache[pictureKey] = picture;
    } else {
      if (_pictureCache.length >= _maxCacheEntries) {
        final firstKey = _pictureCache.keys.first;
        _pictureCache.remove(firstKey)?.dispose();
      }
      picture = _recordPicture(basePath, color);
      _pictureCache[pictureKey] = picture;
    }

    canvas.save();
    canvas.translate(0, centerY);
    canvas.scale(1, breathScale);
    canvas.translate(0, -centerY);
    canvas.drawPicture(picture);
    canvas.restore();
  }

  Path _buildBasePath(List<double> waveformData, Size size) {
    final path = Path();
    final barCount = waveformData.length;
    final totalSpacing = size.width;
    final barWidth = totalSpacing / (barCount * 1.6);
    final gap = barWidth * 0.6;
    final step = barWidth + gap;
    final centerY = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final x = i * step + barWidth / 2;
      final halfHeight = (waveformData[i] * centerY).clamp(2.0, centerY);
      path
        ..moveTo(x, centerY - halfHeight)
        ..lineTo(x, centerY + halfHeight);
    }
    return path;
  }

  ui.Picture _recordPicture(Path path, Color waveformColor) {
    final recorder = ui.PictureRecorder();
    final recorderCanvas = Canvas(recorder);
    final paint = Paint()
      ..color = waveformColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;
    recorderCanvas.drawPath(path, paint);
    return recorder.endRecording();
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.data != data ||
      oldDelegate.breathPhase != breathPhase;
}
