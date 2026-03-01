import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    this.audioFrameSize = defaultAudioFrameSize,
    this.audioSampleRate = defaultAudioSampleRate,
    this.pitchDetectionThreshold = defaultPitchDetectionThreshold,
    this.testBannerIdAndroid = defaultTestBannerIdAndroid,
    this.testBannerIdIos = defaultTestBannerIdIos,
    this.testInterstitialIdAndroid = defaultTestInterstitialIdAndroid,
    this.testInterstitialIdIos = defaultTestInterstitialIdIos,
    this.recordingsStorageKey = defaultRecordingsStorageKey,
    this.practiceLogsStorageKey = defaultPracticeLogsStorageKey,
    this.recordingsMigratedStorageKey = defaultRecordingsMigratedStorageKey,
    this.compositionsStorageKey = defaultCompositionsStorageKey,
    this.compositionsMigratedStorageKey = defaultCompositionsMigratedStorageKey,
    this.darkModeStorageKey = defaultDarkModeStorageKey,
    this.referencePitchStorageKey = defaultReferencePitchStorageKey,
    this.defaultDarkMode = false,
    this.defaultReferencePitch = 440.0,
  });

  static const int defaultAudioFrameSize = 2048;
  static const int defaultAudioSampleRate = 44100;
  static const double defaultPitchDetectionThreshold = 0.10;

  static const String defaultTestBannerIdAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String defaultTestBannerIdIos =
      'ca-app-pub-3940256099942544/2934735716';
  static const String defaultTestInterstitialIdAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String defaultTestInterstitialIdIos =
      'ca-app-pub-3940256099942544/4411468910';

  static const String defaultRecordingsStorageKey = 'recordings_v1';
  static const String defaultPracticeLogsStorageKey = 'practice_logs_v1';
  static const String defaultRecordingsMigratedStorageKey = 'db_migrated_v1';
  static const String defaultCompositionsStorageKey = 'compositions_v1';
  static const String defaultCompositionsMigratedStorageKey =
      'compositions_db_migrated_v1';
  static const String defaultDarkModeStorageKey = 'darkMode';
  static const String defaultReferencePitchStorageKey = 'referencePitch';

  final int audioFrameSize;
  final int audioSampleRate;
  final double pitchDetectionThreshold;

  final String testBannerIdAndroid;
  final String testBannerIdIos;
  final String testInterstitialIdAndroid;
  final String testInterstitialIdIos;

  final String recordingsStorageKey;
  final String practiceLogsStorageKey;
  final String recordingsMigratedStorageKey;
  final String compositionsStorageKey;
  final String compositionsMigratedStorageKey;
  final String darkModeStorageKey;
  final String referencePitchStorageKey;

  final bool defaultDarkMode;
  final double defaultReferencePitch;
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());
