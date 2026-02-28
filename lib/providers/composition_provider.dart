import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/composition_repository.dart';
import '../service_locator.dart';
import '../utils/app_logger.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class CompositionState {
  const CompositionState({
    this.compositions = const [],
    this.loading = true,
    this.hasError = false,
  });

  final List<Composition> compositions;
  final bool loading;
  final bool hasError;

  CompositionState copyWith({
    List<Composition>? compositions,
    bool? loading,
    bool? hasError,
  }) {
    return CompositionState(
      compositions: compositions ?? this.compositions,
      loading: loading ?? this.loading,
      hasError: hasError ?? this.hasError,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final compositionRepositoryProvider = Provider<CompositionRepository>((ref) {
  return ServiceLocator.instance.compositionRepository;
});

/// Maximum number of compositions a user can save.
const int kMaxCompositions = 50;

class CompositionLimitReachedException implements Exception {
  final int max;
  CompositionLimitReachedException(this.max);
  @override
  String toString() => 'Save limit of $max compositions reached.';
}

class CompositionNotifier extends Notifier<CompositionState> {
  @override
  CompositionState build() {
    // Start loading after the build completes to avoid uninitialized state access.
    Future.delayed(Duration.zero, _load);
    return const CompositionState(loading: true);
  }

  CompositionRepository get _repo => ref.read(compositionRepositoryProvider);

  Future<void> _load() async {
    try {
      final compositions = await _repo.load();
      state = CompositionState(compositions: compositions, loading: false);
    } catch (e, st) {
      AppLogger.reportError(
        'CompositionNotifier: failed to load compositions',
        error: e,
        stackTrace: st,
      );
      state = const CompositionState(loading: false, hasError: true);
    }
  }

  /// Appends [composition] to the list and persists the change.
  Future<void> saveComposition(Composition composition) async {
    if (state.compositions.length >= kMaxCompositions) {
      throw CompositionLimitReachedException(kMaxCompositions);
    }
    final previous = state.compositions;
    final updated = [...previous, composition];
    state = state.copyWith(compositions: updated);
    try {
      await _repo.save(updated);
    } catch (e, st) {
      AppLogger.reportError(
        'CompositionNotifier: failed to save composition',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(compositions: previous);
      rethrow;
    }
  }

  /// Removes the composition with [id] from the list and persists the change.
  Future<void> deleteComposition(String id) async {
    final previous = state.compositions;
    final updated = previous.where((c) => c.id != id).toList();
    state = state.copyWith(compositions: updated);
    try {
      await _repo.save(updated);
    } catch (e, st) {
      AppLogger.reportError(
        'CompositionNotifier: failed to delete composition',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(compositions: previous);
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final compositionProvider =
    NotifierProvider.autoDispose<CompositionNotifier, CompositionState>(
  CompositionNotifier.new,
);
