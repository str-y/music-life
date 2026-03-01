import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dependency_providers.dart';
import '../repositories/composition_repository.dart';
import '../services/service_error_handler.dart';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Maximum number of compositions a user can save.
const int kMaxCompositions = 50;

class CompositionLimitReachedException implements Exception {
  final int max;
  CompositionLimitReachedException(this.max);
  @override
  String toString() => 'Save limit of $max compositions reached.';
}

class CompositionNotifier extends AutoDisposeAsyncNotifier<List<Composition>> {
  @override
  Future<List<Composition>> build() => _load();

  CompositionRepository get _repo => ref.read(compositionRepositoryProvider);

  Future<List<Composition>> _load() async {
    try {
      return await _repo.load();
    } catch (e, st) {
      ServiceErrorHandler.report(
        'CompositionNotifier: failed to load compositions',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Appends [composition] to the list and persists the change.
  Future<void> saveComposition(Composition composition) async {
    final previous = state.valueOrNull;
    if (previous == null) {
      throw StateError(
        'Cannot save composition: data not loaded. Please wait for initialization to complete.',
      );
    }
    if (previous.length >= kMaxCompositions) {
      throw CompositionLimitReachedException(kMaxCompositions);
    }
    final updated = [...previous, composition];
    state = AsyncValue.data(updated);
    try {
      await _repo.saveOne(composition);
    } catch (e, st) {
      ServiceErrorHandler.report(
        'CompositionNotifier: failed to save composition',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  /// Removes the composition with [id] from the list and persists the change.
  Future<void> deleteComposition(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) {
      throw StateError(
        'Cannot delete composition: data not loaded. Please wait for initialization to complete.',
      );
    }
    final updated = previous.where((c) => c.id != id).toList();
    state = AsyncValue.data(updated);
    try {
      await _repo.deleteOne(id);
    } catch (e, st) {
      ServiceErrorHandler.report(
        'CompositionNotifier: failed to delete composition',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.data(previous);
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final compositionProvider =
    AsyncNotifierProvider.autoDispose<CompositionNotifier, List<Composition>>(
  CompositionNotifier.new,
);
