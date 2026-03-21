import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/utils/app_logger.dart';
enum AppFlavor {
  dev,
  staging,
  prod;

  static AppFlavor fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'dev':
      case 'development':
        return AppFlavor.dev;
      case 'staging':
      case 'stage':
        return AppFlavor.staging;
      case 'prod':
      case 'production':
      default:
        return AppFlavor.prod;
    }
  }

  String get displayName {
    switch (this) {
      case AppFlavor.dev:
        return 'Development';
      case AppFlavor.staging:
        return 'Staging';
      case AppFlavor.prod:
        return 'Production';
    }
  }
}

class AppConfig {

  const AppConfig({
    this.flavor = AppFlavor.prod,
    this.apiBaseUrl = defaultApiBaseUrl,
    this.audioFrameSize = defaultAudioFrameSize,
    this.audioSampleRate = defaultAudioSampleRate,
    this.pitchDetectionThreshold = defaultPitchDetectionThreshold,
    this.logLevel,
    this.testBannerIdAndroid = defaultTestBannerIdAndroid,
    this.testBannerIdIos = defaultTestBannerIdIos,
    this.testInterstitialIdAndroid = defaultTestInterstitialIdAndroid,
    this.testInterstitialIdIos = defaultTestInterstitialIdIos,
    this.testRewardedIdAndroid = defaultTestRewardedIdAndroid,
    this.testRewardedIdIos = defaultTestRewardedIdIos,
    this.audioNotificationChannelId = defaultAudioNotificationChannelId,
    this.audioNotificationChannelName = defaultAudioNotificationChannelName,
    this.recordingsStorageKey = defaultRecordingsStorageKey,
    this.practiceLogsStorageKey = defaultPracticeLogsStorageKey,
    this.recordingsMigratedStorageKey = defaultRecordingsMigratedStorageKey,
    this.compositionsStorageKey = defaultCompositionsStorageKey,
    this.compositionsMigratedStorageKey = defaultCompositionsMigratedStorageKey,
    this.darkModeStorageKey = defaultDarkModeStorageKey,
    this.useSystemThemeStorageKey = defaultUseSystemThemeStorageKey,
    this.localeStorageKey = defaultLocaleStorageKey,
    this.themeColorNoteStorageKey = defaultThemeColorNoteStorageKey,
    this.dynamicThemeModeStorageKey = defaultDynamicThemeModeStorageKey,
    this.dynamicThemeIntensityStorageKey = defaultDynamicThemeIntensityStorageKey,
    this.referencePitchStorageKey = defaultReferencePitchStorageKey,
    this.tunerTranspositionStorageKey = defaultTunerTranspositionStorageKey,
    this.hapticFeedbackEnabledStorageKey = defaultHapticFeedbackEnabledStorageKey,
    this.metronomeBpmStorageKey = defaultMetronomeBpmStorageKey,
    this.metronomeTimeSignatureNumeratorStorageKey =
        defaultMetronomeTimeSignatureNumeratorStorageKey,
    this.metronomeTimeSignatureDenominatorStorageKey =
        defaultMetronomeTimeSignatureDenominatorStorageKey,
    this.metronomePresetsStorageKey = defaultMetronomePresetsStorageKey,
    this.cloudSyncEnabledStorageKey = defaultCloudSyncEnabledStorageKey,
    this.lastCloudSyncAtStorageKey = defaultLastCloudSyncAtStorageKey,
    this.cloudBackupBundleStorageKey = defaultCloudBackupBundleStorageKey,
    this.rewardedPremiumExpiresAtStorageKey =
        defaultRewardedPremiumExpiresAtStorageKey,
    this.metronomeSoundPacksStorageKey = defaultMetronomeSoundPacksStorageKey,
    this.selectedMetronomeSoundPackStorageKey =
        defaultSelectedMetronomeSoundPackStorageKey,
    this.premiumVideoExportSkinStorageKey =
        defaultPremiumVideoExportSkinStorageKey,
    this.premiumVideoExportColorStorageKey =
        defaultPremiumVideoExportColorStorageKey,
    this.premiumVideoExportEffectStorageKey =
        defaultPremiumVideoExportEffectStorageKey,
    this.premiumVideoExportShowLogoStorageKey =
        defaultPremiumVideoExportShowLogoStorageKey,
    this.premiumVideoExportQualityStorageKey =
        defaultPremiumVideoExportQualityStorageKey,
    this.defaultDarkMode = false,
    this.defaultUseSystemTheme = true,
    this.defaultDynamicThemeMode = defaultChillDynamicThemeMode,
    this.defaultDynamicThemeIntensity = 0.7,
    this.defaultReferencePitch = 440.0,
    this.defaultTunerTransposition = _defaultTunerTransposition,
    this.defaultHapticFeedbackEnabled = true,
    this.defaultPremiumVideoExportSkin = defaultAuroraPremiumVideoExportSkin,
    this.defaultPremiumVideoExportColor = _defaultPremiumVideoExportColorValue,
    this.defaultPremiumVideoExportEffect = defaultGlowPremiumVideoExportEffect,
    this.defaultPremiumVideoExportShowLogo = true,
    this.defaultPremiumVideoExportQuality = defaultHighPremiumVideoExportQuality,
    this.defaultMetronomeBpm = 120,
    this.defaultMetronomeTimeSignatureNumerator = 4,
    this.defaultMetronomeTimeSignatureDenominator = 4,
  });

  factory AppConfig.dev() => const AppConfig(
        flavor: AppFlavor.dev,
        apiBaseUrl: defaultDevApiBaseUrl,
        logLevel: AppLogLevel.debug,
        audioNotificationChannelId: '$defaultAudioNotificationChannelId.dev',
        audioNotificationChannelName: 'Music Life Dev Playback',
        recordingsStorageKey: 'dev_$defaultRecordingsStorageKey',
        practiceLogsStorageKey: 'dev_$defaultPracticeLogsStorageKey',
        recordingsMigratedStorageKey: 'dev_$defaultRecordingsMigratedStorageKey',
        compositionsStorageKey: 'dev_$defaultCompositionsStorageKey',
        compositionsMigratedStorageKey:
            'dev_$defaultCompositionsMigratedStorageKey',
        darkModeStorageKey: 'dev_$defaultDarkModeStorageKey',
        useSystemThemeStorageKey: 'dev_$defaultUseSystemThemeStorageKey',
        localeStorageKey: 'dev_$defaultLocaleStorageKey',
        themeColorNoteStorageKey: 'dev_$defaultThemeColorNoteStorageKey',
        dynamicThemeModeStorageKey: 'dev_$defaultDynamicThemeModeStorageKey',
        dynamicThemeIntensityStorageKey:
            'dev_$defaultDynamicThemeIntensityStorageKey',
        referencePitchStorageKey: 'dev_$defaultReferencePitchStorageKey',
        tunerTranspositionStorageKey:
            'dev_$defaultTunerTranspositionStorageKey',
        metronomeBpmStorageKey: 'dev_$defaultMetronomeBpmStorageKey',
        metronomeTimeSignatureNumeratorStorageKey:
            'dev_$defaultMetronomeTimeSignatureNumeratorStorageKey',
        metronomeTimeSignatureDenominatorStorageKey:
            'dev_$defaultMetronomeTimeSignatureDenominatorStorageKey',
        metronomePresetsStorageKey: 'dev_$defaultMetronomePresetsStorageKey',
        cloudSyncEnabledStorageKey: 'dev_$defaultCloudSyncEnabledStorageKey',
        lastCloudSyncAtStorageKey: 'dev_$defaultLastCloudSyncAtStorageKey',
        cloudBackupBundleStorageKey: 'dev_$defaultCloudBackupBundleStorageKey',
        rewardedPremiumExpiresAtStorageKey:
            'dev_$defaultRewardedPremiumExpiresAtStorageKey',
        metronomeSoundPacksStorageKey:
            'dev_$defaultMetronomeSoundPacksStorageKey',
        selectedMetronomeSoundPackStorageKey:
            'dev_$defaultSelectedMetronomeSoundPackStorageKey',
        premiumVideoExportSkinStorageKey:
            'dev_$defaultPremiumVideoExportSkinStorageKey',
        premiumVideoExportColorStorageKey:
            'dev_$defaultPremiumVideoExportColorStorageKey',
        premiumVideoExportEffectStorageKey:
            'dev_$defaultPremiumVideoExportEffectStorageKey',
        premiumVideoExportShowLogoStorageKey:
            'dev_$defaultPremiumVideoExportShowLogoStorageKey',
        premiumVideoExportQualityStorageKey:
            'dev_$defaultPremiumVideoExportQualityStorageKey',
      );

  factory AppConfig.staging() => const AppConfig(
        flavor: AppFlavor.staging,
        apiBaseUrl: defaultStagingApiBaseUrl,
        logLevel: AppLogLevel.info,
        audioNotificationChannelId:
            '$defaultAudioNotificationChannelId.staging',
        audioNotificationChannelName: 'Music Life Staging Playback',
        recordingsStorageKey: 'staging_$defaultRecordingsStorageKey',
        practiceLogsStorageKey: 'staging_$defaultPracticeLogsStorageKey',
        recordingsMigratedStorageKey:
            'staging_$defaultRecordingsMigratedStorageKey',
        compositionsStorageKey: 'staging_$defaultCompositionsStorageKey',
        compositionsMigratedStorageKey:
            'staging_$defaultCompositionsMigratedStorageKey',
        darkModeStorageKey: 'staging_$defaultDarkModeStorageKey',
        useSystemThemeStorageKey: 'staging_$defaultUseSystemThemeStorageKey',
        localeStorageKey: 'staging_$defaultLocaleStorageKey',
        themeColorNoteStorageKey:
            'staging_$defaultThemeColorNoteStorageKey',
        dynamicThemeModeStorageKey:
            'staging_$defaultDynamicThemeModeStorageKey',
        dynamicThemeIntensityStorageKey:
            'staging_$defaultDynamicThemeIntensityStorageKey',
        referencePitchStorageKey: 'staging_$defaultReferencePitchStorageKey',
        tunerTranspositionStorageKey:
            'staging_$defaultTunerTranspositionStorageKey',
        metronomeBpmStorageKey: 'staging_$defaultMetronomeBpmStorageKey',
        metronomeTimeSignatureNumeratorStorageKey:
            'staging_$defaultMetronomeTimeSignatureNumeratorStorageKey',
        metronomeTimeSignatureDenominatorStorageKey:
            'staging_$defaultMetronomeTimeSignatureDenominatorStorageKey',
        metronomePresetsStorageKey:
            'staging_$defaultMetronomePresetsStorageKey',
        cloudSyncEnabledStorageKey:
            'staging_$defaultCloudSyncEnabledStorageKey',
        lastCloudSyncAtStorageKey: 'staging_$defaultLastCloudSyncAtStorageKey',
        cloudBackupBundleStorageKey:
            'staging_$defaultCloudBackupBundleStorageKey',
        rewardedPremiumExpiresAtStorageKey:
            'staging_$defaultRewardedPremiumExpiresAtStorageKey',
        metronomeSoundPacksStorageKey:
            'staging_$defaultMetronomeSoundPacksStorageKey',
        selectedMetronomeSoundPackStorageKey:
            'staging_$defaultSelectedMetronomeSoundPackStorageKey',
        premiumVideoExportSkinStorageKey:
            'staging_$defaultPremiumVideoExportSkinStorageKey',
        premiumVideoExportColorStorageKey:
            'staging_$defaultPremiumVideoExportColorStorageKey',
        premiumVideoExportEffectStorageKey:
            'staging_$defaultPremiumVideoExportEffectStorageKey',
        premiumVideoExportShowLogoStorageKey:
            'staging_$defaultPremiumVideoExportShowLogoStorageKey',
        premiumVideoExportQualityStorageKey:
            'staging_$defaultPremiumVideoExportQualityStorageKey',
      );

  factory AppConfig.prod() => const AppConfig();

  factory AppConfig.fromEnvironment({String? flavor}) {
    final resolvedFlavor = AppFlavor.fromValue(
      flavor ??
          const String.fromEnvironment(
            flavorEnvironmentKey,
            defaultValue: 'prod',
          ),
    );
    switch (resolvedFlavor) {
      case AppFlavor.dev:
        return AppConfig.dev();
      case AppFlavor.staging:
        return AppConfig.staging();
      case AppFlavor.prod:
        return AppConfig.prod();
    }
  }
  static const String flavorEnvironmentKey = 'APP_FLAVOR';

  static const String defaultApiBaseUrl = 'https://api.musiclife.app';
  static const String defaultDevApiBaseUrl = 'https://dev.api.musiclife.app';
  static const String defaultStagingApiBaseUrl =
      'https://staging.api.musiclife.app';
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
  static const String defaultAudioNotificationChannelId =
      'com.stry.musiclife.audio';
  static const String defaultAudioNotificationChannelName =
      'Music Life Playback';

  static const String defaultRecordingsStorageKey = 'recordings_v1';
  static const String defaultPracticeLogsStorageKey = 'practice_logs_v1';
  static const String defaultRecordingsMigratedStorageKey = 'db_migrated_v1';
  static const String defaultCompositionsStorageKey = 'compositions_v1';
  static const String defaultCompositionsMigratedStorageKey =
      'compositions_db_migrated_v1';
  static const String defaultDarkModeStorageKey = 'darkMode';
  static const String defaultUseSystemThemeStorageKey = 'useSystemTheme';
  static const String defaultLocaleStorageKey = 'localeCode';
  static const String defaultThemeColorNoteStorageKey = 'themeColorNote';
  static const String defaultDynamicThemeModeStorageKey = 'dynamicThemeMode';
  static const String defaultDynamicThemeIntensityStorageKey =
      'dynamicThemeIntensity';
  static const String defaultReferencePitchStorageKey = 'referencePitch';
  static const String defaultTunerTranspositionStorageKey = 'tunerTransposition';
  static const String defaultHapticFeedbackEnabledStorageKey =
      'hapticFeedbackEnabled';
  static const String defaultMetronomeBpmStorageKey = 'metronomeBpm';
  static const String defaultMetronomeTimeSignatureNumeratorStorageKey =
      'metronomeTimeSignatureNumerator';
  static const String defaultMetronomeTimeSignatureDenominatorStorageKey =
      'metronomeTimeSignatureDenominator';
  static const String defaultMetronomePresetsStorageKey = 'metronomePresets';
  static const String defaultCloudSyncEnabledStorageKey = 'cloudSyncEnabled';
  static const String defaultLastCloudSyncAtStorageKey = 'lastCloudSyncAt';
  static const String defaultCloudBackupBundleStorageKey = 'cloudBackupBundle';
  static const String defaultRewardedPremiumExpiresAtStorageKey =
      'rewardedPremiumExpiresAt';
  static const String defaultMetronomeSoundPacksStorageKey =
      'metronomeSoundPacks';
  static const String defaultSelectedMetronomeSoundPackStorageKey =
      'selectedMetronomeSoundPack';
  static const String defaultPremiumVideoExportSkinStorageKey =
      'premiumVideoExportSkin';
  static const String defaultPremiumVideoExportColorStorageKey =
      'premiumVideoExportColor';
  static const String defaultPremiumVideoExportEffectStorageKey =
      'premiumVideoExportEffect';
  static const String defaultPremiumVideoExportShowLogoStorageKey =
      'premiumVideoExportShowLogo';
  static const String defaultPremiumVideoExportQualityStorageKey =
      'premiumVideoExportQuality';
  static const String _defaultTunerTransposition = 'C';
  static const String defaultChillDynamicThemeMode = 'chill';
  static const String defaultAuroraPremiumVideoExportSkin = 'aurora';
  static const int _defaultPremiumVideoExportColorValue = 0xFF7C4DFF;
  static const String defaultGlowPremiumVideoExportEffect = 'glow';
  static const String defaultHighPremiumVideoExportQuality = 'high';

  final AppFlavor flavor;
  final String apiBaseUrl;
  final int audioFrameSize;
  final int audioSampleRate;
  final double pitchDetectionThreshold;
  final AppLogLevel? logLevel;

  final String testBannerIdAndroid;
  final String testBannerIdIos;
  final String testInterstitialIdAndroid;
  final String testInterstitialIdIos;
  final String testRewardedIdAndroid;
  final String testRewardedIdIos;
  final String audioNotificationChannelId;
  final String audioNotificationChannelName;

  final String recordingsStorageKey;
  final String practiceLogsStorageKey;
  final String recordingsMigratedStorageKey;
  final String compositionsStorageKey;
  final String compositionsMigratedStorageKey;
  final String darkModeStorageKey;
  final String useSystemThemeStorageKey;
  final String localeStorageKey;
  final String themeColorNoteStorageKey;
  final String dynamicThemeModeStorageKey;
  final String dynamicThemeIntensityStorageKey;
  final String referencePitchStorageKey;
  final String tunerTranspositionStorageKey;
  final String hapticFeedbackEnabledStorageKey;
  final String metronomeBpmStorageKey;
  final String metronomeTimeSignatureNumeratorStorageKey;
  final String metronomeTimeSignatureDenominatorStorageKey;
  final String metronomePresetsStorageKey;
  final String cloudSyncEnabledStorageKey;
  final String lastCloudSyncAtStorageKey;
  final String cloudBackupBundleStorageKey;
  final String rewardedPremiumExpiresAtStorageKey;
  final String metronomeSoundPacksStorageKey;
  final String selectedMetronomeSoundPackStorageKey;
  final String premiumVideoExportSkinStorageKey;
  final String premiumVideoExportColorStorageKey;
  final String premiumVideoExportEffectStorageKey;
  final String premiumVideoExportShowLogoStorageKey;
  final String premiumVideoExportQualityStorageKey;

  final bool defaultDarkMode;
  final bool defaultUseSystemTheme;
  final String defaultDynamicThemeMode;
  final double defaultDynamicThemeIntensity;
  final double defaultReferencePitch;
  final String defaultTunerTransposition;
  final bool defaultHapticFeedbackEnabled;
  final String defaultPremiumVideoExportSkin;
  final int defaultPremiumVideoExportColor;
  final String defaultPremiumVideoExportEffect;
  final bool defaultPremiumVideoExportShowLogo;
  final String defaultPremiumVideoExportQuality;
  final int defaultMetronomeBpm;
  final int defaultMetronomeTimeSignatureNumerator;
  final int defaultMetronomeTimeSignatureDenominator;

  bool get isProduction => flavor == AppFlavor.prod;

  String get environmentName => flavor.displayName;

  AppLogLevel get effectiveLogLevel =>
      logLevel ?? (kReleaseMode ? AppLogLevel.info : AppLogLevel.debug);
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
