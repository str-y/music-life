import 'config/app_config.dart';

/// Centralized application configuration and theme constants.
///
/// All magic numbers for idle timeouts, UI thresholds, and other configurable
/// values are defined here rather than scattered across implementation files.
abstract final class AppConstants {
  // ── Audio engine ──────────────────────────────────────────────────────────

  /// Default audio frame size passed to the native pitch-detection engine.
  static const int audioFrameSize = AppConfig.defaultAudioFrameSize;

  /// Default audio sample rate in Hz.
  static const int audioSampleRate = AppConfig.defaultAudioSampleRate;

  /// Default YIN algorithm threshold for the native pitch-detection engine.
  static const double pitchDetectionThreshold =
      AppConfig.defaultPitchDetectionThreshold;

  // ── Idle timeout ──────────────────────────────────────────────────────────

  /// Duration of audio silence before the listening animation is stopped.
  static const Duration listeningIdleTimeout = Duration(seconds: 5);

  // ── Tuner UI thresholds ───────────────────────────────────────────────────

  /// Cents offset (absolute) within which a note is considered "in tune"
  /// and displayed in green.
  static const double tunerInTuneThresholdCents = 5.0;

  /// Cents offset (absolute) within which a note shows a caution colour
  /// (orange). Notes beyond this are shown in the error colour.
  static const double tunerWarningThresholdCents = 15.0;

  // ── Rhythm / metronome ────────────────────────────────────────────────────

  /// Minimum BPM the metronome will allow.
  static const int metronomeMinBpm = 30;

  /// Maximum BPM the metronome will allow.
  static const int metronomeMaxBpm = 240;

  // ── Chord analyser ────────────────────────────────────────────────────────

  /// Maximum number of historical chord entries shown in the timeline.
  static const int chordHistoryMaxEntries = 12;
}
