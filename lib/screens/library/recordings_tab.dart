import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/recording_playback_provider.dart';
import '../../repositories/recording_repository.dart';
import '../../utils/app_logger.dart';

// ---------------------------------------------------------------------------
// Recordings tab
// ---------------------------------------------------------------------------

class RecordingsTab extends ConsumerStatefulWidget {
  const RecordingsTab({super.key, required this.recordings});

  final List<RecordingEntry> recordings;

  @override
  ConsumerState<RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends ConsumerState<RecordingsTab> {
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

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(recordingPlaybackProvider);
    final playbackNotifier = ref.read(recordingPlaybackProvider.notifier);
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
        final isActive = playback.activeRecordingId == entry.id;
        final isPlaying = isActive && playback.isPlaying;
        return RecordingTile(
          entry: entry,
          isPlaying: isPlaying,
          progress: isActive ? playback.progress : 0,
          volume: playback.volume,
          onPlayPause: () => playbackNotifier.togglePlayback(entry),
          onSeek: isActive ? playbackNotifier.seekToRatio : null,
          onVolumeChanged: isActive ? playbackNotifier.setVolume : null,
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
    required this.volume,
    required this.onPlayPause,
    required this.onSeek,
    required this.onVolumeChanged,
    this.onShare,
  });

  final RecordingEntry entry;
  final bool isPlaying;
  final double progress;
  final double volume;
  final VoidCallback onPlayPause;
  final ValueChanged<double>? onSeek;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback? onShare;

  Future<void> _shareRecording(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final path = entry.audioFilePath;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.recordingUnavailableForShare)),
      );
      return;
    }

    try {
      await Share.shareXFiles(
        [
          XFile(
            path,
            name: recordingShareFileName(entry),
          ),
        ],
        subject: entry.title,
        text: DateFormat.yMd().add_Hm().format(entry.recordedAt),
      );
    } catch (e, st) {
      AppLogger.reportError(
        'RecordingTile: failed to share recording',
        error: e,
        stackTrace: st,
      );
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.recordingShareFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMd(locale).add_Hm();
    final canPlay = entry.audioFilePath?.isNotEmpty == true;
    final canShare = canPlay;
    final isActive = onSeek != null;

    final VoidCallback shareHandler = onShare ?? () { _shareRecording(context); };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
            iconSize: 40,
            color: colorScheme.primary,
            onPressed: canPlay ? onPlayPause : null,
            tooltip: isPlaying ? l10n.pause : l10n.play,
          ),
          title: Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            dateFormat.format(entry.recordedAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.formattedDuration,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: canShare ? shareHandler : null,
                icon: const Icon(Icons.share),
                tooltip: l10n.shareRecording,
              ),
            ],
          ),
          onTap: canPlay ? onPlayPause : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WaveformView(
                data: entry.waveformData,
                durationSeconds: entry.durationSeconds,
                isPlaying: isPlaying,
                color: isPlaying ? colorScheme.primary : colorScheme.outlineVariant,
              ),
              if (isActive) ...[
                const SizedBox(height: 6),
                Semantics(
                  label: 'Seek position in recording',
                  value: '${(progress * 100).round()}%',
                  child: Slider(value: progress, onChanged: onSeek),
                ),
                Row(
                  children: [
                    const Icon(Icons.volume_down, size: 16),
                    Expanded(
                      child: Semantics(
                        label: 'Adjust volume',
                        value: '${(volume * 100).round()}%',
                        child: Slider(
                          value: volume,
                          onChanged: onVolumeChanged,
                        ),
                      ),
                    ),
                    const Icon(Icons.volume_up, size: 16),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String recordingShareFileName(RecordingEntry entry) {
  final detectedExtension = p.extension(entry.audioFilePath ?? '');
  final fileExtension = detectedExtension.isEmpty ? '.m4a' : detectedExtension;
  final dateStamp = DateFormat('yyyyMMdd_HHmm').format(entry.recordedAt);
  final safeTitle = entry.title
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
  final baseName = safeTitle.isEmpty ? 'recording' : safeTitle;
  return '${baseName}_$dateStamp$fileExtension';
}

// ---------------------------------------------------------------------------
// Waveform painter
// ---------------------------------------------------------------------------

class WaveformView extends StatefulWidget {
  const WaveformView({
    super.key,
    required this.data,
    required this.durationSeconds,
    required this.isPlaying,
    required this.color,
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
    final durationStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Semantics(
      label: l10n.waveformSemanticLabel,
      value: l10n.waveformSemanticValue(durationStr),
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
  // Keep cache bounded for list scrolling scenarios while avoiding unbounded
  // picture/path growth in memory.
  static const int _maxCacheEntries = 128;
  static const double _breathScaleFactor = 0.22;
  static final LinkedHashMap<String, Path> _pathCache =
      LinkedHashMap<String, Path>();
  static final LinkedHashMap<String, ui.Picture> _pictureCache =
      LinkedHashMap<String, ui.Picture>();

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final centerY = size.height / 2;
    final breathScale = 1.0 + breathPhase * _breathScaleFactor;
    // Cache is per recording waveform list instance from repository data.
    final dataHash = identityHashCode(data);
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
    final pictureKey = '$cacheKey:${color.value}';
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
    canvas.translate(0.0, centerY);
    canvas.scale(1.0, breathScale);
    canvas.translate(0.0, -centerY);
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
