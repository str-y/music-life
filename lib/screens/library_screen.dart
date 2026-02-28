import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:sqflite/sqflite.dart';

import '../l10n/app_localizations.dart';
import '../providers/library_provider.dart';
import '../repositories/recording_repository.dart';
import 'library/log_tab.dart';
import 'library/recordings_tab.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.libraryTitle),
        bottom: TabBar(
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
              : TabBarView(
              controller: _tabController,
              children: [
                RecordingsTab(recordings: state.recordings),
                LogTab(logs: state.logs),
              ],
            ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0 || state.loading || state.hasError) {
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
  final _titleCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  final List<double> _amplitudeData = [];

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
    _recorder.stop().ignore();
    _recorder.dispose();
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

  List<double> _toWaveform(List<double> source, int targetPoints) {
    if (source.isEmpty) return const [];
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
      final segment = source.sublist(start, boundedEnd);
      final sum = segment.fold<double>(0, (acc, value) => acc + value);
      return (sum / segment.length).clamp(0.0, 1.0).toDouble();
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

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.micPermissionNeeded),
          ),
        );
      }
      return;
    }

    final path = await _createRecordingPath();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );

    _amplitudeData.clear();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
      // Convert dBFS (typically in [-60, 0]) into normalized [0, 1] waveform.
      final normalised = ((amp.current - _amplitudeFloorDb) / -_amplitudeFloorDb)
          .clamp(0.0, 1.0)
          .toDouble();
      _amplitudeData.add(normalised);
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
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _ticker = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    await _recorder.stop();
    final data = _toWaveform(_amplitudeData, 40);
    setState(() {
      _state = _RecordingState.stopped;
      _waveformData = data;
    });
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
