import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../app_constants.dart';
import '../native_pitch_bridge.dart';
import '../providers/dependency_providers.dart';
import '../repositories/chord_history_repository.dart';
import '../utils/app_logger.dart';
import '../utils/chord_utils.dart';
import '../widgets/listening_indicator.dart';
import '../widgets/mic_permission_gate.dart';


class ChordAnalyserScreen extends StatelessWidget {
  const ChordAnalyserScreen({super.key, this.useMicPermissionGate = true});

  final bool useMicPermissionGate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chordAnalyserTitle),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: useMicPermissionGate
          ? const MicPermissionGate(child: _ChordAnalyserBody())
          : const _ChordAnalyserBody(),
    );
  }
}

// ── Internal body (shown only after permission is granted) ────────────────────

class _ChordAnalyserBody extends ConsumerStatefulWidget {
  const _ChordAnalyserBody();

  @override
  ConsumerState<_ChordAnalyserBody> createState() => _ChordAnalyserBodyState();
}

class _ChordAnalyserBodyState extends ConsumerState<_ChordAnalyserBody>
    with SingleTickerProviderStateMixin {
  NativePitchBridge? _bridge;
  StreamSubscription<String>? _subscription;
  bool _loading = true;

  /// The chord currently being detected.
  String _currentChord = '---';

  /// Ordered list of recently detected chords (newest first).
  final List<_ChordEntry> _history = [];

  final TextEditingController _chordFilterController = TextEditingController();
  DateTime? _selectedFilterDate;
  String _chordNameFilter = '';

  /// Controller for the pulsing "listening" indicator.
  late final AnimationController _listeningCtrl;

  /// Timer used to stop [_listeningCtrl] after [AppConstants.listeningIdleTimeout] of no audio input.
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _listeningCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadHistory();
    _startCapture();
    _scheduleIdleStop();
  }

  Future<void> _startCapture() async {
    setState(() => _loading = true);

    final bridge = ref.read(pitchBridgeFactoryProvider)(
      onError: _onBridgeError,
    );
    final started = await bridge.startCapture();
    if (!mounted) {
      bridge.dispose();
      return;
    }
    if (!started) {
      // Permission may have been revoked after MicPermissionGate confirmed it.
      bridge.dispose();
      setState(() => _loading = false); // _bridge stays null → shows denied UI
      return;
    }

    _bridge = bridge;
    _subscription = bridge.chordStream.listen((chord) {
      if (!mounted) return;
      if (!_listeningCtrl.isAnimating) {
        _listeningCtrl.repeat(reverse: true);
      }
      _scheduleIdleStop();
      setState(() => _currentChord = chord);
      unawaited(
        _persistChordAndRefresh(
          _ChordEntry(chord: chord, time: DateTime.now()),
        ),
      );
    });
    setState(() => _loading = false);
  }

  Future<void> _persistChordAndRefresh(_ChordEntry entry) async {
    try {
      final repository = ref.read(chordHistoryRepositoryProvider);
      await repository.addEntry(
        ChordHistoryEntry(chord: entry.chord, time: entry.time),
      );
      await _loadHistory();
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to persist chord analysis entry',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _loadHistory() async {
    try {
      final repository = ref.read(chordHistoryRepositoryProvider);
      final entries = await repository.loadEntries(
        day: _selectedFilterDate,
        chordNameFilter: _chordNameFilter,
      );
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(entries.map((e) => _ChordEntry(chord: e.chord, time: e.time)));
      });
    } catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to load chord analysis history',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _openFilterSheet() async {
    final localizations = AppLocalizations.of(context)!;
    final initialDate = _selectedFilterDate;
    final initialChordName = _chordNameFilter;
    _chordFilterController.text = initialChordName;
    DateTime? pendingDate = initialDate;

    final action = await showModalBottomSheet<_HistoryFilterAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dateLabel = pendingDate == null
                ? '-'
                : formatDateYMD(pendingDate!);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _chordFilterController,
                    decoration: InputDecoration(
                      labelText: localizations.currentChord,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${localizations.practiceDate}: $dateLabel'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: pendingDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setModalState(() => pendingDate = picked);
                          }
                        },
                        child: Text(localizations.practiceDate),
                      ),
                      TextButton(
                        onPressed: () => setModalState(() => pendingDate = null),
                        child: Text(localizations.cancel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(_HistoryFilterAction.clear),
                        child: Text(localizations.retry),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(localizations.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context)
                            .pop(_HistoryFilterAction.apply),
                        child: Text(localizations.save),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == _HistoryFilterAction.apply) {
      setState(() {
        _selectedFilterDate = pendingDate;
        _chordNameFilter = _chordFilterController.text.trim();
      });
      await _loadHistory();
      return;
    }

    setState(() {
      _selectedFilterDate = null;
      _chordNameFilter = '';
      _chordFilterController.clear();
    });
    await _loadHistory();
  }

  /// Called when the [NativePitchBridge] reports a runtime error.
  void _onBridgeError(Object error, StackTrace stack) {
    AppLogger.reportError(
      'Chord analyser bridge error',
      error: error,
      stackTrace: stack,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.chordAnalyserError),
      ),
    );
  }

  /// Schedules [_listeningCtrl] to stop after [AppConstants.listeningIdleTimeout] of no audio activity.
  void _scheduleIdleStop() {
    _idleTimer?.cancel();
    _idleTimer = Timer(AppConstants.listeningIdleTimeout, () {
      if (mounted) _listeningCtrl.stop();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _subscription?.cancel();
    _bridge?.dispose();
    _chordFilterController.dispose();
    _listeningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    // Bridge failed to start (e.g. permission revoked after the gate check).
    if (_bridge == null) {
      return MicPermissionDeniedView(
        onRetry: () => _startCapture(),
      );
    }

    return Column(
      children: [
        // ── Current chord ──────────────────────────────────────────
        Expanded(
          flex: 5,
          child: RepaintBoundary(
            child: Center(
              child: Semantics(
                liveRegion: true,
                label: AppLocalizations.of(context)!.currentNoteSemanticLabel,
                value: _currentChord == '---' ? null : _currentChord,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.currentChord,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Text(
                        _currentChord,
                        key: ValueKey(_currentChord),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                              fontSize: 80,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListeningIndicator(controller: _listeningCtrl),
                  ],
                ),
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // ── Chord history timeline ──────────────────────────────────
        InkWell(
          onTap: _openFilterSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: colorScheme.secondary),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!.chordHistory,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.secondary,
                      ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Semantics(
            label: AppLocalizations.of(context)!.chordHistory,
            child: RepaintBoundary(
              child: _history.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.noChordHistory,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final entry = _history[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ChordHistoryTile(
                            entry: entry,
                            isLatest: index == 0,
                            colorScheme: colorScheme,
                            animation: kAlwaysCompleteAnimation,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// ── Data model ────────────────────────────────────────────────────────────────

class _ChordEntry {
  const _ChordEntry({
    required this.chord,
    required this.time,
  });

  final String chord;
  final DateTime time;
}

enum _HistoryFilterAction { apply, clear }

// ── Chord history tile ────────────────────────────────────────────────────────

class _ChordHistoryTile extends StatelessWidget {
  const _ChordHistoryTile({
    required this.entry,
    required this.isLatest,
    required this.colorScheme,
    required this.animation,
  });

  final _ChordEntry entry;
  final bool isLatest;
  final ColorScheme colorScheme;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final timeLabel = formatTimeHMS(entry.time);

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: Semantics(
          label: '${entry.chord}, $timeLabel',
          excludeSemantics: true,
          child: AnimatedOpacity(
            opacity: isLatest ? 1.0 : 0.65,
            duration: const Duration(milliseconds: 300),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isLatest
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: isLatest
                  ? Border.all(color: colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.chord,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight:
                              isLatest ? FontWeight.bold : FontWeight.normal,
                          color: isLatest
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                  ),
                ),
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isLatest
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
