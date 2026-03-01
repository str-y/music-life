import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../l10n/app_localizations.dart';
import '../providers/library_provider.dart';
import '../repositories/recording_repository.dart';
import '../utils/app_logger.dart';
import 'library/log_tab.dart';
import 'library/recordings_tab.dart';

@visibleForTesting
List<double> downsampleWaveform(List<double> source, int targetPoints) {
  if (source.isEmpty || targetPoints <= 0) return const [];
  if (source.length <= targetPoints) return List<double>.from(source);
  final bucket = source.length / targetPoints;
  return List<double>.generate(targetPoints, (i) {
    final start = (i * bucket).floor();
    final end = ((i + 1) * bucket).ceil();
    final boundedEnd = _boundWaveformEnd(
      end: end,
      min: start + 1,
      max: source.length,
    );
    double sum = 0.0;
    for (var j = start; j < boundedEnd; j++) {
      sum += source[j];
    }
    return (sum / (boundedEnd - start)).clamp(0.0, 1.0).toDouble();
  });
}

int _boundWaveformEnd({
  required int end,
  required int min,
  required int max,
}) {
  if (end < min) return min;
  if (end > max) return max;
  return end;
}

List<double> _downsampleWaveformInIsolate(Map<String, Object> args) {
  final source = (args['source'] as List).cast<double>();
  final targetPoints = args['targetPoints'] as int;
  return downsampleWaveform(source, targetPoints);
}

@visibleForTesting
List<double> buildLiveWaveformPreview(
  List<double> amplitudeData, {
  int targetPoints = 40,
}) {
  if (amplitudeData.isEmpty) return const [];
  return downsampleWaveform(amplitudeData, targetPoints);
}

// ---------------------------------------------------------------------------
// LibraryScreen
// ---------------------------------------------------------------------------

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    final result = await showDialog<RecordingEntry>(
      context: context,
      builder: (_) => const _AddRecordingDialog(),
    );
    if (result != null && mounted) {
      await ref.read(libraryProvider.notifier).addRecording(result);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.recordingSavedSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    final isWideLayout = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.libraryTitle),
        bottom: isWideLayout
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(icon: const Icon(Icons.mic), text: AppLocalizations.of(context)!.recordingsTab),
                  Tab(icon: const Icon(Icons.calendar_month), text: AppLocalizations.of(context)!.logsTab),
                ],
              ),
      ),
      body: state.loading
          ? Center(
              child: CircularProgressIndicator(
                semanticsLabel: AppLocalizations.of(context)!.loadingLibrary,
              ),
            )
          : state.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.loadDataError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(libraryProvider.notifier).reload(),
                        icon: const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : isWideLayout
                  ? Row(
                      key: const ValueKey('library-wide-layout'),
                      children: [
                        Expanded(
                          child: RecordingsTab(
                            recordings: state.recordings,
                            onCreateRecording: _showAddDialog,
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: LogTab(
                            monthlyLogStatsByMonth: state.monthlyLogStats,
                            onRecordPractice: () => context.push('/practice-log'),
                          ),
                        ),
                      ],
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        RecordingsTab(
                          recordings: state.recordings,
                          onCreateRecording: _showAddDialog,
                        ),
                        LogTab(
                          monthlyLogStatsByMonth: state.monthlyLogStats,
                          onRecordPractice: () => context.push('/practice-log'),
                        ),
                      ],
                    ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if ((!isWideLayout && _tabController.index != 0) || state.loading || state.hasError) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () => _showAddDialog(),
            tooltip: AppLocalizations.of(context)!.newRecording,
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add recording dialog
// ---------------------------------------------------------------------------

enum _RecordingState { idle, recording, stopped }

class _AddRecordingDialog extends StatefulWidget {
  const _AddRecordingDialog();

  @override
  State<_AddRecordingDialog> createState() => _AddRecordingDialogState();
}

class _AddRecordingDialogState extends State<_AddRecordingDialog> {
  static const double _amplitudeFloorDb = -60.0;
  static const int _amplitudeSamplesPerUiUpdate = 3;
  final _titleCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  final List<double> _amplitudeData = [];
  List<double> _liveWaveformPreview = const [];
  int _samplesSinceUiUpdate = 0;

  _RecordingState _state = _RecordingState.idle;
  int _durationSeconds = 0;
  List<double> _waveformData = const [];
  String? _recordingPath;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    unawaited(_disposeRecorder());
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<String> _createRecordingPath() async {
    final dbPath = await getDatabasesPath();
    final dir = Directory(p.join(dbPath, 'recordings'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final fileName = 'rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return p.join(dir.path, fileName);
  }

  Future<void> _disposeRecorder() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to stop recorder while disposing recorder dialog.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    try {
      await _recorder.dispose();
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to dispose audio recorder.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!mounted) return;
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.micPermissionNeeded)),
        );
        return;
      }

      final path = await _createRecordingPath();
      if (!mounted) return;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) {
        await _recorder.stop();
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        return;
      }

      _amplitudeData.clear();
      _liveWaveformPreview = const [];
      _samplesSinceUiUpdate = 0;
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((amp) {
        // Convert dBFS (typically in [-60, 0]) into normalized [0, 1] waveform.
        final normalised = ((amp.current - _amplitudeFloorDb) / -_amplitudeFloorDb)
            .clamp(0.0, 1.0)
            .toDouble();
        _amplitudeData.add(normalised);
        _samplesSinceUiUpdate++;
        if (mounted && _samplesSinceUiUpdate >= _amplitudeSamplesPerUiUpdate) {
          _samplesSinceUiUpdate = 0;
          setState(() {
            _liveWaveformPreview = buildLiveWaveformPreview(_amplitudeData);
          });
        }
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _durationSeconds++);
      });

      setState(() {
        _state = _RecordingState.recording;
        _durationSeconds = 0;
        _waveformData = const [];
        _recordingPath = path;
      });
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to start audio recording.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _ticker = null;
    try {
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      if (!mounted) return;
      await _recorder.stop();
      if (!mounted) return;
      final data = await compute<Map<String, Object>, List<double>>(
        _downsampleWaveformInIsolate,
        {'source': _amplitudeData, 'targetPoints': 40},
      );
      if (!mounted) return;
      setState(() {
        _state = _RecordingState.stopped;
        _waveformData = data;
      });
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to stop audio recording.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isRecording = _state == _RecordingState.recording;
    final hasStopped = _state == _RecordingState.stopped;

    return AlertDialog(
      title: Text(l10n.newRecording),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: l10n.recordingTitleLabel,
                hintText: l10n.recordingTitleHint,
              ),
              autofocus: _state == _RecordingState.idle,
            ),
            const SizedBox(height: 24),
            // Duration counter (shown during and after recording)
            if (_state != _RecordingState.idle) ...[
              Text(
                _formatDuration(_durationSeconds),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
            ],
            // Record / Stop button
            if (!hasStopped) ...[
              IconButton.filled(
                onPressed: isRecording ? _stopRecording : _startRecording,
                iconSize: 40,
                tooltip: isRecording ? l10n.tapToStop : l10n.tapToRecord,
                style: isRecording
                    ? IconButton.styleFrom(backgroundColor: cs.error)
                    : null,
                icon: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  color: isRecording ? cs.onError : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRecording ? l10n.tapToStop : l10n.tapToRecord,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            // Waveform preview after recording stops
            if (isRecording && _amplitudeData.isNotEmpty) ...[
              const SizedBox(height: 8),
              WaveformView(
                data: _liveWaveformPreview,
                durationSeconds: _durationSeconds,
                isPlaying: false,
                animate: true,
                color: cs.error,
              ),
            ],
            if (hasStopped && _waveformData.isNotEmpty) ...[
              const SizedBox(height: 8),
              WaveformView(
                data: _waveformData,
                durationSeconds: _durationSeconds,
                isPlaying: false,
                color: cs.primary,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: hasStopped
              ? () {
                  final title = _titleCtrl.text.trim().isEmpty
                      ? l10n.newRecording
                      : _titleCtrl.text.trim();
                  Navigator.of(context).pop(
                    RecordingEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: title,
                      recordedAt: DateTime.now(),
                      durationSeconds: _durationSeconds,
                      waveformData: _waveformData,
                      audioFilePath: _recordingPath,
                    ),
                  );
                }
              : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
