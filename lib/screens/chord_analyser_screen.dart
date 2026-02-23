import 'dart:async';

import 'package:flutter/material.dart';

/// Maximum number of historical chord entries shown in the timeline.
const int _maxHistory = 12;

class ChordAnalyserScreen extends StatefulWidget {
  const ChordAnalyserScreen({super.key, required this.chordStream});

  /// Stream of chord labels emitted by the native pitch-detection engine.
  final Stream<String> chordStream;

  @override
  State<ChordAnalyserScreen> createState() => _ChordAnalyserScreenState();
}

class _ChordAnalyserScreenState extends State<ChordAnalyserScreen>
    with SingleTickerProviderStateMixin {
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

    _subscription = widget.chordStream.listen((chord) {
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
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _listeningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('コード解析'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // ── Current chord ──────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '現在のコード',
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
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            fontSize: 80,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ListeningIndicator(controller: _listeningCtrl),
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
                  'コード進行の履歴',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.secondary,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _history.isEmpty
                ? Center(
                    child: Text(
                      'まだ履歴がありません',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : AnimatedList(
                    key: _listKey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    initialItemCount: _history.length,
                    itemBuilder: (context, index, animation) {
                      final entry = _history[index];
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
      ),
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
  const _ChordEntry({required this.chord, required this.time});

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
