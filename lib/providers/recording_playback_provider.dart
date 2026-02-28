import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../repositories/recording_repository.dart';
import '../utils/app_logger.dart';

class RecordingPlaybackState {
  const RecordingPlaybackState({
    this.activeRecordingId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.volume = 1.0,
  });

  final String? activeRecordingId;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final double volume;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  RecordingPlaybackState copyWith({
    String? activeRecordingId,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    double? volume,
  }) {
    return RecordingPlaybackState(
      activeRecordingId: activeRecordingId ?? this.activeRecordingId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
    );
  }
}

class RecordingPlaybackNotifier extends AutoDisposeNotifier<RecordingPlaybackState> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  RecordingPlaybackState build() {
    ref.onDispose(() {
      for (final sub in _subs) {
        unawaited(sub.cancel());
      }
      unawaited(_player?.dispose());
    });
    return const RecordingPlaybackState();
  }

  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    final player = AudioPlayer();
    _subs.add(player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    }));
    _subs.add(player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    }));
    _subs.add(player.playerStateStream.listen((playerState) {
      final completed = playerState.processingState == ProcessingState.completed;
      state = state.copyWith(
        isPlaying: playerState.playing && !completed,
        position: completed ? Duration.zero : state.position,
      );
      if (completed) {
        unawaited(player.seek(Duration.zero));
      }
    }));
    _player = player;
    await player.setVolume(state.volume);
  }

  Future<void> togglePlayback(RecordingEntry entry) async {
    final path = entry.audioFilePath;
    if (path == null || path.isEmpty) return;
    try {
      await _ensurePlayer();
      final player = _player!;
      if (state.activeRecordingId != entry.id) {
        await player.setAudioSource(
          AudioSource.uri(
            Uri.file(path),
            tag: MediaItem(
              id: entry.id,
              album: 'Music Life',
              title: entry.title,
              duration: Duration(seconds: entry.durationSeconds),
            ),
          ),
        );
        state = state.copyWith(
          activeRecordingId: entry.id,
          position: Duration.zero,
          duration: Duration(seconds: entry.durationSeconds),
        );
      }
      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
    } catch (e, st) {
      AppLogger.reportError(
        'RecordingPlaybackNotifier: failed to toggle playback',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> seekToRatio(double ratio) async {
    final duration = state.duration;
    if (duration.inMilliseconds <= 0) return;
    try {
      await _ensurePlayer();
      final clamped = ratio.clamp(0.0, 1.0).toDouble();
      final next = Duration(
        milliseconds: (duration.inMilliseconds * clamped).round(),
      );
      await _player!.seek(next);
      state = state.copyWith(position: next);
    } catch (e, st) {
      AppLogger.reportError(
        'RecordingPlaybackNotifier: failed to seek',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(volume: clamped);
    try {
      await _ensurePlayer();
      await _player!.setVolume(clamped);
    } catch (e, st) {
      AppLogger.reportError(
        'RecordingPlaybackNotifier: failed to set volume',
        error: e,
        stackTrace: st,
      );
    }
  }
}

final recordingPlaybackProvider =
    NotifierProvider.autoDispose<RecordingPlaybackNotifier, RecordingPlaybackState>(
  RecordingPlaybackNotifier.new,
);
