import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/recording_playback_provider.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:music_life/widgets/shared/status_message_view.dart';
import 'package:music_life/widgets/shared/waveform_view.dart';
// ---------------------------------------------------------------------------
// Recordings tab
// ---------------------------------------------------------------------------

class RecordingsTab extends ConsumerStatefulWidget {
  const RecordingsTab({
    super.key,
    required this.recordings,
    this.onCreateRecording,
  });

  final List<RecordingEntry> recordings;
  final VoidCallback? onCreateRecording;

  @override
  ConsumerState<RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends ConsumerState<RecordingsTab> {
  static const int _pageSize = 40;
  static const double _loadMoreThreshold = 320;

  late List<RecordingEntry> _sorted;
  late final ScrollController _scrollController;
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _sorted = _prepareSorted(widget.recordings);
    _visibleCount = _initialVisibleCountFor(_sorted.length);
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(RecordingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recordings != oldWidget.recordings) {
      _sorted = _prepareSorted(widget.recordings);
      _visibleCount = _initialVisibleCountFor(_sorted.length);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    WaveformPainter.clearCaches();
    super.dispose();
  }

  int _initialVisibleCountFor(int totalCount) =>
      totalCount <= _pageSize ? totalCount : _pageSize;

  void _handleScroll() {
    if (!_scrollController.hasClients || _visibleCount >= _sorted.length) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) {
      return;
    }
    final nextVisibleCount =
        (_visibleCount + _pageSize).clamp(0, _sorted.length).toInt();
    if (nextVisibleCount == _visibleCount) {
      return;
    }
    setState(() {
      _visibleCount = nextVisibleCount;
    });
    AppLogger.debug(
      'RecordingsTab: expanded visible recordings to $_visibleCount/${_sorted.length}',
    );
  }

  List<RecordingEntry> _prepareSorted(List<RecordingEntry> recordings) {
    if (_isSortedDescending(recordings)) {
      return [...recordings];
    }
    return [...recordings]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  bool _isSortedDescending(List<RecordingEntry> recordings) {
    for (var i = 1; i < recordings.length; i++) {
      if (recordings[i - 1].recordedAt.isBefore(recordings[i].recordedAt)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(recordingPlaybackProvider);
    final playbackNotifier = ref.read(recordingPlaybackProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    if (_sorted.isEmpty) {
      return StatusMessageView(
        illustration: StatusMessageIllustration(
          primaryIcon: Icons.mic_rounded,
          accentIcon: Icons.graphic_eq_rounded,
          colorScheme: Theme.of(context).colorScheme,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        message: l10n.noRecordings,
        messageStyle: Theme.of(context).textTheme.titleMedium,
        details: l10n.recordingsEmptyHint,
        detailsStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        action: FilledButton.icon(
          onPressed: widget.onCreateRecording,
          icon: const Icon(Icons.mic),
          label: Text(l10n.startFirstRecording),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),

      itemCount: _visibleCount,
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
      if (!context.mounted) return;
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
      if (!context.mounted) return;
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
