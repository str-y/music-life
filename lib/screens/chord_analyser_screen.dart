import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../native_pitch_bridge.dart';
import '../widgets/mic_permission_denied_view.dart';

/// Maximum number of historical chord entries shown in the timeline.
const int _maxHistory = 12;

enum _ChordAnalyserStatus { loading, permissionDenied, running }

class ChordAnalyserScreen extends StatefulWidget {
  const ChordAnalyserScreen({super.key});

  @override
  State<ChordAnalyserScreen> createState() => _ChordAnalyserScreenState();
}

class _ChordAnalyserScreenState extends State<ChordAnalyserScreen>
    with SingleTickerProviderStateMixin {
  NativePitchBridge? _bridge;

  _ChordAnalyserStatus _status = _ChordAnalyserStatus.loading;

  /// The chord currently being detected.
  String _currentChord = '---';

  /// Ordered list of recently detected chords (newest first).
  final List<_ChordEntry> _history = [];

  /// Key for the animated history list.
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  StreamSubscription<String>? _subscription;

  /// Controller for the pulsing "listening" indicator.
  late final AnimationController _listeningCtrl;

  @override
  void initState() {
    super.initState();
    _listeningCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startCapture();
  }

  Future<void> _startCapture() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _status = _ChordAnalyserStatus.permissionDenied);
      return;
    }

    final bridge = NativePitchBridge();
    final started = await bridge.startCapture();
    if (!mounted) {
      bridge.dispose();
      return;
    }
    if (!started) {
      bridge.dispose();
      setState(() => _status = _ChordAnalyserStatus.permissionDenied);
      return;
    }

    _bridge = bridge;
    _subscription = bridge.chordStream.listen((chord) {
      if (!mounted) return;
      setState(() => _currentChord = chord);
      _history.insert(0, _ChordEntry(chord: chord, time: DateTime.now()));
      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 300),
      );
      if (_history.length > _maxHistory) {
        final removed = _history.removeLast();
        _listKey.currentState?.removeItem(
          _maxHistory,
          (context, animation) => _ChordHistoryTile(
            entry: removed,
            isLatest: false,
            colorScheme: Theme.of(context).colorScheme,
            animation: animation,
          ),
          duration: Duration.zero,
        );
      }
    });
    setState(() => _status = _ChordAnalyserStatus.running);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bridge?.dispose();
    _listeningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chordAnalyserTitle),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: switch (_status) {
        _ChordAnalyserStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        _ChordAnalyserStatus.permissionDenied => MicPermissionDeniedView(
            onRetry: () async {
              setState(() => _status = _ChordAnalyserStatus.loading);
              await _startCapture();
            },
          ),
        _ChordAnalyserStatus.running => _ChordAnalyserBody(
            currentChord: _currentChord,
            history: _history,
            listKey: _listKey,
            listeningCtrl: _listeningCtrl,
            colorScheme: colorScheme,
          ),
      },
    );
  }
}

// ── Chord analyser body ───────────────────────────────────────────────────────

class _ChordAnalyserBody extends StatelessWidget {
  const _ChordAnalyserBody({
    required this.currentChord,
    required this.history,
    required this.listKey,
    required this.listeningCtrl,
    required this.colorScheme,
  });

  final String currentChord;
  final List<_ChordEntry> history;
  final GlobalKey<AnimatedListState> listKey;
  final AnimationController listeningCtrl;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Current chord ──────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Center(
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
                    currentChord,
                    key: ValueKey(currentChord),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 80,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                _ListeningIndicator(controller: listeningCtrl),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // ── Chord history timeline ──────────────────────────────────
        Padding(
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
        Expanded(
          flex: 4,
          child: history.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.noChordHistory,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : AnimatedList(
                  key: listKey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  initialItemCount: history.length,
                  itemBuilder: (context, index, animation) {
                    final entry = history[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ChordHistoryTile(
                        entry: entry,
                        isLatest: index == 0,
                        colorScheme: colorScheme,
                        animation: animation,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';

// ── Pulsing listening indicator ───────────────────────────────────────────────

class _ListeningIndicator extends StatelessWidget {
  const _ListeningIndicator({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final interval = Interval(
              i * 0.15,
              0.55 + i * 0.15,
              curve: Curves.easeInOut,
            );
            final t = interval.transform(controller.value);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 6 + t * 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35 + t * 0.65),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ChordEntry {
  const _ChordEntry({
    required this.chord,
    required this.time,
  });

  final String chord;
  final DateTime time;
}

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
    final timeLabel = _formatTime(entry.time);

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
    );
  }
}
