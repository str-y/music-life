import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/composition_provider.dart';
import '../repositories/composition_repository.dart';

// ── Palette chords ────────────────────────────────────────────────────────────

const List<String> _kPaletteChords = [
  'C', 'Cm', 'D', 'Dm', 'E', 'Em', 'F', 'Fm',
  'G', 'Gm', 'A', 'Am', 'B', 'Bm',
  'C7', 'D7', 'E7', 'F7', 'G7', 'A7', 'B7',
  'Cmaj7', 'Dmaj7', 'Emaj7', 'Fmaj7', 'Gmaj7', 'Amaj7',
  'Dm7', 'Em7', 'Am7', 'Bm7',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class CompositionHelperScreen extends ConsumerStatefulWidget {
  const CompositionHelperScreen({super.key});

  @override
  ConsumerState<CompositionHelperScreen> createState() =>
      _CompositionHelperScreenState();
}

class _CompositionHelperScreenState
    extends ConsumerState<CompositionHelperScreen> {

  /// Monotonically increasing counter used to assign stable unique IDs to
  /// each chord entry so that [ReorderableListView] keys remain stable across
  /// reorders and deletions.
  int _nextChordId = 0;

  /// Current chord sequence being edited.  Each entry carries a unique [id]
  /// so the [ReorderableListView] can track items correctly.
  final List<({int id, String chord})> _sequence = [];

  // ── Playback state ─────────────────────────────────────────────────────
  bool _isPlaying = false;
  int _playingIndex = -1;
  int _bpm = 80;
  Timer? _playTimer;

  @override
  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  // ── Sequence mutations ─────────────────────────────────────────────────

  void _addChord(String chord) {
    setState(() => _sequence.add((id: _nextChordId++, chord: chord)));
  }

  void _removeChord(int index) {
    _stopPlayback();
    setState(() => _sequence.removeAt(index));
  }

  void _clearSequence() {
    _stopPlayback();
    setState(() => _sequence.clear());
  }

  void _reorderSequence(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final entry = _sequence.removeAt(oldIndex);
      _sequence.insert(newIndex, entry);
    });
  }

  // ── Playback ───────────────────────────────────────────────────────────

  void _startPlayback() {
    if (_sequence.isEmpty) return;
    setState(() {
      _isPlaying = true;
      _playingIndex = 0;
    });
    final interval = Duration(milliseconds: (60000 / _bpm).round());
    _playTimer?.cancel();
    _playTimer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() {
        _playingIndex = (_playingIndex + 1) % _sequence.length;
      });
    });
  }

  void _stopPlayback() {
    _playTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _playingIndex = -1;
    });
  }

  // ── Save / load ────────────────────────────────────────────────────────

  Future<void> _showSaveDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final savedCount = ref.read(compositionProvider).compositions.length;
    final controller = TextEditingController(
      text: l10n.compositionDefaultName(savedCount + 1),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.compositionSave),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: l10n.compositionTitle),
          autofocus: true,
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final title = controller.text.trim().isEmpty
        ? l10n.compositionUntitled
        : controller.text.trim();
    final composition = Composition(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      chords: _sequence.map((e) => e.chord).toList(),
    );
    try {
      await ref.read(compositionProvider.notifier).saveComposition(composition);
    } on CompositionLimitReachedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.compositionLimitReached(e.max))),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.compositionSaveError)),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.compositionSavedSuccess)),
    );
  }

  Future<void> _showLoadDialog() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final selected = await showModalBottomSheet<Composition?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _LoadCompositionSheet(
        compositions: ref.read(compositionProvider).compositions,
        onDelete: (comp) async {
          try {
            await ref
                .read(compositionProvider.notifier)
                .deleteComposition(comp.id);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.compositionDeleteError)),
            );
          }
        },
      ),
    );
    if (selected == null || !mounted) return;
    _stopPlayback();
    setState(() {
      _sequence
        ..clear()
        ..addAll(
          selected.chords.map((c) => (id: _nextChordId++, chord: c)),
        );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.compositionLoadSuccess(selected.title))),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(compositionProvider).hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.compositionLoadError),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final compositionState = ref.watch(compositionProvider);

    ref.listen(compositionProvider, (previous, next) {
      if (next.hasError && (previous == null || !previous.hasError)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.compositionLoadError)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.compositionHelperTitle),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          if (_sequence.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: l10n.compositionSave,
              onPressed: _showSaveDialog,
            ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: l10n.compositionLoad,
            onPressed: compositionState.compositions.isEmpty
                ? null
                : _showLoadDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chord palette ────────────────────────────────────────────
          _ChordPalette(onChordTap: _addChord),
          const Divider(height: 1),

          // ── Sequence header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Icon(
                  Icons.queue_music,
                  size: 18,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.compositionSequence(_sequence.length),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.secondary,
                        ),
                  ),
                ),
                if (_sequence.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: Text(l10n.compositionClear),
                    onPressed: _clearSequence,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),

          // ── Chord sequence ───────────────────────────────────────────
          Expanded(
            child: _sequence.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.compositionEmpty,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: _sequence.length,
                    onReorder: _reorderSequence,
                    itemBuilder: (ctx, index) {
                      final entry = _sequence[index];
                      final isActive =
                          _isPlaying && index == _playingIndex;
                      return _SequenceChordTile(
                        key: ValueKey(entry.id),
                        chord: entry.chord,
                        index: index,
                        isActive: isActive,
                        onRemove: () => _removeChord(index),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // ── Playback controls ────────────────────────────────────────
          _PlaybackControls(
            isPlaying: _isPlaying,
            bpm: _bpm,
            canPlay: _sequence.isNotEmpty,
            onPlay: _startPlayback,
            onStop: _stopPlayback,
            onBpmChanged: (v) {
              setState(() => _bpm = v);
              if (_isPlaying) {
                _stopPlayback();
                _startPlayback();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Chord palette ─────────────────────────────────────────────────────────────

class _ChordPalette extends StatelessWidget {
  const _ChordPalette({required this.onChordTap});

  final ValueChanged<String> onChordTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            l10n.compositionPalette,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.secondary,
                ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: _kPaletteChords.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              final chord = _kPaletteChords[i];
              return ActionChip(
                label: Text(chord),
                onPressed: () => onChordTap(chord),
                tooltip: '${l10n.compositionAddChord} $chord',
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Sequence chord tile ───────────────────────────────────────────────────────

class _SequenceChordTile extends StatelessWidget {
  const _SequenceChordTile({
    super.key,
    required this.chord,
    required this.index,
    required this.isActive,
    required this.onRemove,
  });

  final String chord;
  final int index;
  final bool isActive;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Text(
          '${index + 1}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        title: Text(
          chord,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? colorScheme.onPrimaryContainer
                    : null,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: l10n.compositionDelete,
              onPressed: onRemove,
              color: colorScheme.onSurfaceVariant,
            ),
            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }
}

// ── Playback controls ─────────────────────────────────────────────────────────

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.isPlaying,
    required this.bpm,
    required this.canPlay,
    required this.onPlay,
    required this.onStop,
    required this.onBpmChanged,
  });

  final bool isPlaying;
  final int bpm;
  final bool canPlay;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final ValueChanged<int> onBpmChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.compositionBpmLabel(bpm),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Slider(
                  min: 40,
                  max: 200,
                  divisions: 160,
                  value: bpm.toDouble(),
                  label: '$bpm',
                  onChanged: (v) => onBpmChanged(v.round()),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
            label: Text(
              isPlaying ? l10n.compositionStop : l10n.compositionPlay,
            ),
            onPressed: canPlay ? (isPlaying ? onStop : onPlay) : null,
            style: FilledButton.styleFrom(
              backgroundColor:
                  isPlaying ? colorScheme.error : null,
              foregroundColor:
                  isPlaying ? colorScheme.onError : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Load composition bottom sheet ─────────────────────────────────────────────

class _LoadCompositionSheet extends StatefulWidget {
  const _LoadCompositionSheet({
    required this.compositions,
    required this.onDelete,
  });

  final List<Composition> compositions;
  final Future<void> Function(Composition) onDelete;

  @override
  State<_LoadCompositionSheet> createState() =>
      _LoadCompositionSheetState();
}

class _LoadCompositionSheetState extends State<_LoadCompositionSheet> {
  late List<Composition> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.compositions];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                l10n.compositionLoad,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.compositionNoSaved,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final comp = _items[index];
                        return ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(comp.title),
                          subtitle: Text(
                            l10n.compositionChordCount(
                              comp.chords.length,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.compositionDeleteProject,
                            onPressed: () async {
                              await widget.onDelete(comp);
                              if (!mounted) return;
                              setState(() => _items
                                  .removeWhere((c) => c.id == comp.id));
                            },
                          ),
                          onTap: () =>
                              Navigator.of(context).pop(comp),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
