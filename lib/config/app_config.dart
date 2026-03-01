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
    this.testRewardedIdAndroid = defaultTestRewardedIdAndroid,
    this.testRewardedIdIos = defaultTestRewardedIdIos,
    this.recordingsStorageKey = defaultRecordingsStorageKey,
    this.practiceLogsStorageKey = defaultPracticeLogsStorageKey,
    this.recordingsMigratedStorageKey = defaultRecordingsMigratedStorageKey,
    this.compositionsStorageKey = defaultCompositionsStorageKey,
    this.compositionsMigratedStorageKey = defaultCompositionsMigratedStorageKey,
    this.darkModeStorageKey = defaultDarkModeStorageKey,
    this.useSystemThemeStorageKey = defaultUseSystemThemeStorageKey,
    this.themeColorNoteStorageKey = defaultThemeColorNoteStorageKey,
    this.referencePitchStorageKey = defaultReferencePitchStorageKey,
    this.tunerTranspositionStorageKey = defaultTunerTranspositionStorageKey,
    this.rewardedPremiumExpiresAtStorageKey =
        defaultRewardedPremiumExpiresAtStorageKey,
    this.defaultDarkMode = false,
    this.defaultUseSystemTheme = true,
    this.defaultReferencePitch = 440.0,
    this.defaultTunerTransposition = defaultTunerTransposition,
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
  static const String defaultTestRewardedIdAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String defaultTestRewardedIdIos =
      'ca-app-pub-3940256099942544/1712485313';

  static const String defaultRecordingsStorageKey = 'recordings_v1';
  static const String defaultPracticeLogsStorageKey = 'practice_logs_v1';
  static const String defaultRecordingsMigratedStorageKey = 'db_migrated_v1';
  static const String defaultCompositionsStorageKey = 'compositions_v1';
  static const String defaultCompositionsMigratedStorageKey =
      'compositions_db_migrated_v1';
  static const String defaultDarkModeStorageKey = 'darkMode';
  static const String defaultUseSystemThemeStorageKey = 'useSystemTheme';
  static const String defaultThemeColorNoteStorageKey = 'themeColorNote';
  static const String defaultReferencePitchStorageKey = 'referencePitch';
  static const String defaultTunerTranspositionStorageKey = 'tunerTransposition';
  static const String defaultRewardedPremiumExpiresAtStorageKey =
      'rewardedPremiumExpiresAt';
  static const String defaultTunerTransposition = 'C';

  final int audioFrameSize;
  final int audioSampleRate;
  final double pitchDetectionThreshold;

  final String testBannerIdAndroid;
  final String testBannerIdIos;
  final String testInterstitialIdAndroid;
  final String testInterstitialIdIos;
  final String testRewardedIdAndroid;
  final String testRewardedIdIos;

  final String recordingsStorageKey;
  final String practiceLogsStorageKey;
  final String recordingsMigratedStorageKey;
  final String compositionsStorageKey;
  final String compositionsMigratedStorageKey;
  final String darkModeStorageKey;
  final String useSystemThemeStorageKey;
  final String themeColorNoteStorageKey;
  final String referencePitchStorageKey;
  final String tunerTranspositionStorageKey;
  final String rewardedPremiumExpiresAtStorageKey;

  final bool defaultDarkMode;
  final bool defaultUseSystemTheme;
  final double defaultReferencePitch;
  final String defaultTunerTransposition;
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());
