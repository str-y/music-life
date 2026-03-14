import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dependency_providers.dart';
import '../native_pitch_bridge.dart';
import '../repositories/settings_repository.dart';

const double _maxCentsOffsetForThemeEnergy = 50.0;
final RegExp _noteNamePattern = RegExp(r'^[A-G](?:#|b)?');

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return _repo.load();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> update(AppSettings updated) async {
    state = updated;
    await _repo.save(updated);
  }

  Future<void> unlockRewardedPremiumFor(
    Duration duration, {
    DateTime? now,
  }) async {
    final grantedAt = now ?? DateTime.now();
    await update(
      state.copyWith(
        rewardedPremiumExpiresAt: grantedAt.add(duration),
      ),
    );
  }

  void updateDynamicThemeFromPitch(PitchResult pitch) {
    final centsEnergy = (pitch.centsOffset.abs() / _maxCentsOffsetForThemeEnergy)
        .clamp(0.0, 1.0)
        .toDouble();
    final energy = (centsEnergy * _frequencyRangeWeight(pitch.frequency))
        .clamp(0.0, 1.0)
        .toDouble();
    state = state.copyWith(
      dynamicThemeNote: pitch.noteName,
<<<<<<< HEAD
      dynamicThemeEnergy: energy.clamp(0.0, 1.0),
=======
      dynamicThemeEnergy: energy,
>>>>>>> 0ffa5905d34823e9aba5bf8616138036c0c54fac
    );
  }

  void updateDynamicThemeFromChord(String chordName) {
    final note = _noteNamePattern.firstMatch(chordName)?.group(0);
    if (note == null) return;
    state = state.copyWith(
      dynamicThemeNote: note,
      dynamicThemeEnergy: _chordComplexityEnergy(chordName),
    );
  }

  double _frequencyRangeWeight(double frequency) {
    if (frequency < 196.0) return 0.85;
    if (frequency < 523.25) return 1.0;
    return 1.15;
  }

  double _chordComplexityEnergy(String chordName) {
    final suffix = chordName.replaceFirst(_noteNamePattern, '').toLowerCase();
    if (suffix.isEmpty) return 0.28;
    if (suffix.contains('dim') || suffix.contains('aug')) return 0.78;
    if (suffix.contains('maj7') ||
        suffix.contains('m7') ||
        suffix.contains('7') ||
        suffix.contains('sus') ||
        suffix.contains('add')) {
      return 0.64;
    }
    if (suffix.startsWith('m')) return 0.46;
    return 0.38;
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
