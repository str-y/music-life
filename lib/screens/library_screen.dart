import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import "package:permission_handler/permission_handler.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/providers/haptic_service_provider.dart';
import 'package:music_life/providers/library_provider.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/router/routes.dart';
import 'package:music_life/services/permission_service.dart';
import 'package:music_life/services/recording_storage_service.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:music_life/widgets/shared/async_value_state_view.dart';
import 'package:music_life/widgets/shared/waveform_view.dart';
import 'package:music_life/screens/library/log_tab.dart';
import 'package:music_life/screens/library/recordings_tab.dart';

typedef AudioRecorderFactory = AudioRecorder Function();

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
  const LibraryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.permissionService,
    this.recordingStorageService,
    this.audioRecorderFactory = AudioRecorder.new,
  });

  final int initialTabIndex;
  final PermissionService? permissionService;
  final RecordingStorageService? recordingStorageService;
  final AudioRecorderFactory audioRecorderFactory;

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
    final RecordingStorageService storageService =
        widget.recordingStorageService ??
        ref.read(recordingStorageServiceProvider);
    final result = await showDialog<RecordingEntry>(
      context: context,
      builder: (_) => _AddRecordingDialog(
        permissionService:
            widget.permissionService ?? ref.read(permissionServiceProvider),
        storageService: storageService,
        recorder: widget.audioRecorderFactory(),
      ),
    );
    if (result != null && mounted) {
      try {
        await ref.read(libraryProvider.notifier).addRecording(result);
        if (mounted) {
          await ref.read(hapticServiceProvider).mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.recordingSavedSuccess),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {
        await storageService.deleteFileIfExists(result.audioFilePath);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.recordingSaveFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final data = libraryState.asData?.value;
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
      body: AsyncValueStateView<LibraryState>(
        value: libraryState,
        loadingSemanticsLabel: AppLocalizations.of(context)!.loadingLibrary,
        errorMessage: AppLocalizations.of(context)!.loadDataError,
        onRetry: () => ref.read(libraryProvider.notifier).reload(),
        data: (state) => isWideLayout
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
                      onRecordPractice: () =>
                          const PracticeLogRoute().push(context),
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
                    onRecordPractice: () =>
                        const PracticeLogRoute().push(context),
                  ),
                ],
              ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if ((!isWideLayout && _tabController.index != 0) || data == null) {
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
  const _AddRecordingDialog({
    required this.permissionService,
    required this.storageService,
    required this.recorder,
  });

  final PermissionService permissionService;
  final RecordingStorageService storageService;
  final AudioRecorder recorder;

  @override
  State<_AddRecordingDialog> createState() => _AddRecordingDialogState();
}

class _AddRecordingDialogState extends State<_AddRecordingDialog> {
  static const double _amplitudeFloorDb = -60.0;
  static const int _amplitudeSamplesPerUiUpdate = 3;
  final _titleCtrl = TextEditingController();
  final List<double> _amplitudeData = [];
  List<double> _liveWaveformPreview = const [];
  int _samplesSinceUiUpdate = 0;

  _RecordingState _state = _RecordingState.idle;
  int _durationSeconds = 0;
  List<double> _waveformData = const [];
  String? _recordingPath;
  bool _preserveRecordingFile = false;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;

  AudioRecorder get _recorder => widget.recorder;
  PermissionService get _permissionService => widget.permissionService;
  RecordingStorageService get _storageService => widget.storageService;

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudeSub?.cancel();
    unawaited(_disposeDialogResources());
    _titleCtrl.dispose();
    super.dispose();
  }

  String _createRecordingPath(String directoryPath) {
    final fileName = 'rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return p.join(directoryPath, fileName);
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

  Future<void> _disposeDialogResources() async {
    await _disposeRecorder();
    if (!_preserveRecordingFile) {
      await _storageService.deleteFileIfExists(_recordingPath);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startRecording() async {
    String? path;
    try {
      final hasPermission =
          (await _permissionService.requestMicrophonePermission()).isGranted;
      if (!mounted) return;
      if (!hasPermission) {
        _showSnackBar(AppLocalizations.of(context)!.micPermissionNeeded);
        return;
      }

      final permissionStillGranted =
          await _permissionService.hasMicrophonePermission();
      if (!mounted) return;
      if (!permissionStillGranted) {
        _showSnackBar(AppLocalizations.of(context)!.micPermissionNeeded);
        return;
      }

      final storageCheck = await _storageService.prepareForRecording();
      if (!mounted) return;
      path = _createRecordingPath(storageCheck.recordingsDirectoryPath);
      _recordingPath = path;
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
        await _storageService.deleteFileIfExists(path);
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
    } on RecordingStorageException catch (error) {
      if (mounted) {
        _showSnackBar(
          AppLocalizations.of(context)!.recordingStorageCheckFailed(
            error.requiredMegabytes,
          ),
        );
      }
    } catch (error, stackTrace) {
      await _storageService.deleteFileIfExists(path ?? _recordingPath);
      AppLogger.reportError(
        'Failed to start audio recording.',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar(AppLocalizations.of(context)!.recordingStartFailed);
      }
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
              if (!isRecording) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.recordingStorageEstimateWarning(
                    _storageService.estimatedRequiredMegabytes,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
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
                  _preserveRecordingFile = true;
                  final now = DateTime.now();
                  Navigator.of(context).pop(
                    RecordingEntry(
                      id: now.millisecondsSinceEpoch.toString(),
                      title: title,
                      recordedAt: now,
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
