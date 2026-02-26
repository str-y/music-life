import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../l10n/app_localizations.dart';
import '../repositories/recording_repository.dart';
import '../service_locator.dart';
import '../utils/waveform_analyzer.dart';
import 'library/log_tab.dart';
import 'library/recordings_tab.dart';

// ---------------------------------------------------------------------------
// LibraryScreen
// ---------------------------------------------------------------------------

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final RecordingRepository _repository;

  List<RecordingEntry> _recordings = [];
  List<PracticeLogEntry> _logs = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository = ServiceLocator.instance.recordingRepository;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final recordings = await _repository.loadRecordings();
      final logs = await _repository.loadPracticeLogs();
      if (!mounted) return;
      setState(() {
        _recordings = recordings;
        _logs = logs;
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addRecording(RecordingEntry entry) async {
    final updated = [entry, ..._recordings];
    setState(() => _recordings = updated);
    await _repository.saveRecordings(updated);

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

  Future<void> _showAddDialog() async {
    final result = await showDialog<RecordingEntry>(
      context: context,
      builder: (_) => const _AddRecordingDialog(),
    );
    if (result != null) {
      await _addRecording(result);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                semanticsLabel: AppLocalizations.of(context)!.loadingLibrary,
              ),
            )
          : _hasError
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
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _hasError = false;
                          });
                          _loadData();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : TabBarView(
              controller: _tabController,
              children: [
                RecordingsTab(recordings: _recordings),
                LogTab(logs: _logs),
              ],
            ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0 || _loading || _hasError) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: _showAddDialog,
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
  final _titleCtrl = TextEditingController();
  final _analyzer = WaveformAnalyzer();
  final _recorder = AudioRecorder();

  _RecordingState _state = _RecordingState.idle;
  int _durationSeconds = 0;
  List<double> _waveformData = const [];
  Timer? _ticker;
  StreamSubscription<Uint8List>? _audioSub;

  @override
  void dispose() {
    _ticker?.cancel();
    _audioSub?.cancel();
    _recorder.stop().ignore();
    _recorder.dispose();
    _titleCtrl.dispose();
    super.dispose();
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

    _analyzer.reset();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      ),
    );

    _audioSub = stream.listen(_analyzer.addChunk);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });

    setState(() {
      _state = _RecordingState.recording;
      _durationSeconds = 0;
      _waveformData = const [];
    });
  }

  Future<void> _stopRecording() async {
    _ticker?.cancel();
    _ticker = null;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    final data = _analyzer.compute(40);
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
