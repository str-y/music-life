import 'package:music_life/config/app_config.dart';
import 'package:music_life/models/premium_video_export.dart';
import 'package:music_life/theme/dynamic_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
const Set<String> _supportedLocaleCodes = <String>{'en', 'ja'};

/// Immutable application settings persisted in local storage.
class AppSettings {

  const AppSettings({
    this.darkMode = false,
    this.useSystemTheme = true,
    this.localeCode,
    this.themeColorNote,
    this.referencePitch = 440.0,
    this.tunerTransposition = 'C',
    this.hapticFeedbackEnabled = true,
    this.dynamicThemeMode = DynamicThemeMode.chill,
    this.dynamicThemeIntensity = 0.7,
    this.dynamicThemeNote,
    this.dynamicThemeEnergy = 0.0,
    this.cloudSyncEnabled = false,
    this.lastCloudSyncAt,
    this.rewardedPremiumExpiresAt,
    this.premiumVideoExportSkin = PremiumVideoExportSkin.aurora,
    this.premiumVideoExportColor = 0xFF7C4DFF,
    this.premiumVideoExportEffect = PremiumVideoExportEffect.glow,
    this.premiumVideoExportShowLogo = true,
    this.premiumVideoExportQuality = PremiumVideoExportQuality.high,
  });
  final bool darkMode;
  final bool useSystemTheme;
  final String? localeCode;
  final String? themeColorNote;
  final double referencePitch;
  final String tunerTransposition;
  final bool hapticFeedbackEnabled;
  final DynamicThemeMode dynamicThemeMode;
  final double dynamicThemeIntensity;
  final String? dynamicThemeNote;
  final double dynamicThemeEnergy;
  final bool cloudSyncEnabled;
  final DateTime? lastCloudSyncAt;
  final DateTime? rewardedPremiumExpiresAt;
  final PremiumVideoExportSkin premiumVideoExportSkin;
  final int premiumVideoExportColor;
  final PremiumVideoExportEffect premiumVideoExportEffect;
  final bool premiumVideoExportShowLogo;
  final PremiumVideoExportQuality premiumVideoExportQuality;

  AppSettings copyWith({
    bool? darkMode,
    bool? useSystemTheme,
    String? localeCode,
    String? themeColorNote,
    double? referencePitch,
    String? tunerTransposition,
    bool? hapticFeedbackEnabled,
    DynamicThemeMode? dynamicThemeMode,
    double? dynamicThemeIntensity,
    String? dynamicThemeNote,
    double? dynamicThemeEnergy,
    bool? cloudSyncEnabled,
    DateTime? lastCloudSyncAt,
    DateTime? rewardedPremiumExpiresAt,
    PremiumVideoExportSkin? premiumVideoExportSkin,
    int? premiumVideoExportColor,
    PremiumVideoExportEffect? premiumVideoExportEffect,
    bool? premiumVideoExportShowLogo,
    PremiumVideoExportQuality? premiumVideoExportQuality,
    bool clearLastCloudSyncAt = false,
    bool clearRewardedPremiumExpiresAt = false,
    bool clearLocaleCode = false,
    bool clearThemeColorNote = false,
    bool clearDynamicThemeNote = false,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      localeCode: clearLocaleCode ? null : (localeCode ?? this.localeCode),
      themeColorNote:
          clearThemeColorNote ? null : (themeColorNote ?? this.themeColorNote),
      referencePitch: referencePitch ?? this.referencePitch,
      tunerTransposition: tunerTransposition ?? this.tunerTransposition,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      dynamicThemeMode: dynamicThemeMode ?? this.dynamicThemeMode,
      dynamicThemeIntensity: _clampDynamicThemeIntensity(
        dynamicThemeIntensity ?? this.dynamicThemeIntensity,
      ),
      dynamicThemeNote: clearDynamicThemeNote
          ? null
          : (dynamicThemeNote ?? this.dynamicThemeNote),
      dynamicThemeEnergy: dynamicThemeEnergy ?? this.dynamicThemeEnergy,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      lastCloudSyncAt: clearLastCloudSyncAt
          ? null
          : (lastCloudSyncAt ?? this.lastCloudSyncAt),
      rewardedPremiumExpiresAt: clearRewardedPremiumExpiresAt
          ? null
          : (rewardedPremiumExpiresAt ?? this.rewardedPremiumExpiresAt),
      premiumVideoExportSkin:
          premiumVideoExportSkin ?? this.premiumVideoExportSkin,
      premiumVideoExportColor:
          premiumVideoExportColor ?? this.premiumVideoExportColor,
      premiumVideoExportEffect:
          premiumVideoExportEffect ?? this.premiumVideoExportEffect,
      premiumVideoExportShowLogo:
          premiumVideoExportShowLogo ?? this.premiumVideoExportShowLogo,
      premiumVideoExportQuality:
          premiumVideoExportQuality ?? this.premiumVideoExportQuality,
    );
  }

  bool get hasRewardedPremiumAccess =>
      rewardedPremiumExpiresAt?.isAfter(DateTime.now()) ?? false;

  PremiumVideoExportSettings get premiumVideoExportSettings =>
      PremiumVideoExportSettings(
        skin: premiumVideoExportSkin,
        waveformColorValue: premiumVideoExportColor,
        effect: premiumVideoExportEffect,
        showLogo: premiumVideoExportShowLogo,
        quality: premiumVideoExportQuality,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          darkMode == other.darkMode &&
          useSystemTheme == other.useSystemTheme &&
           localeCode == other.localeCode &&
           themeColorNote == other.themeColorNote &&
           referencePitch == other.referencePitch &&
           tunerTransposition == other.tunerTransposition &&
           hapticFeedbackEnabled == other.hapticFeedbackEnabled &&
           dynamicThemeMode == other.dynamicThemeMode &&
           dynamicThemeIntensity == other.dynamicThemeIntensity &&
           dynamicThemeNote == other.dynamicThemeNote &&
           dynamicThemeEnergy == other.dynamicThemeEnergy &&
           cloudSyncEnabled == other.cloudSyncEnabled &&
           lastCloudSyncAt == other.lastCloudSyncAt &&
           rewardedPremiumExpiresAt == other.rewardedPremiumExpiresAt &&
           premiumVideoExportSkin == other.premiumVideoExportSkin &&
           premiumVideoExportColor == other.premiumVideoExportColor &&
           premiumVideoExportEffect == other.premiumVideoExportEffect &&
           premiumVideoExportShowLogo == other.premiumVideoExportShowLogo &&
           premiumVideoExportQuality == other.premiumVideoExportQuality;

  @override
  int get hashCode => Object.hashAll([
        darkMode,
        useSystemTheme,
        localeCode,
        themeColorNote,
        referencePitch,
        tunerTransposition,
        hapticFeedbackEnabled,
        dynamicThemeMode,
        dynamicThemeIntensity,
        dynamicThemeNote,
        dynamicThemeEnergy,
        cloudSyncEnabled,
        lastCloudSyncAt,
        rewardedPremiumExpiresAt,
        premiumVideoExportSkin,
        premiumVideoExportColor,
        premiumVideoExportEffect,
        premiumVideoExportShowLogo,
        premiumVideoExportQuality,
      ]);

  static double _clampDynamicThemeIntensity(double intensity) {
    return intensity.clamp(0.0, 1.0);
  }
}

/// Loads and saves [AppSettings] values via shared preferences.
class SettingsRepository {
  const SettingsRepository(this._prefs, {AppConfig config = const AppConfig()})
      : _config = config;

  final SharedPreferences _prefs;
  final AppConfig _config;

  /// Reads settings from storage, falling back to configured defaults.
  AppSettings load() {
    return AppSettings(
      darkMode:
          _prefs.getBool(_config.darkModeStorageKey) ?? _config.defaultDarkMode,
      useSystemTheme: _prefs.getBool(_config.useSystemThemeStorageKey) ??
          _config.defaultUseSystemTheme,
      localeCode: _decodeLocaleCode(
        _prefs.getString(_config.localeStorageKey),
      ),
      themeColorNote: _prefs.getString(_config.themeColorNoteStorageKey),
      referencePitch: _prefs.getDouble(_config.referencePitchStorageKey) ??
          _config.defaultReferencePitch,
      tunerTransposition:
          _prefs.getString(_config.tunerTranspositionStorageKey) ??
              _config.defaultTunerTransposition,
      hapticFeedbackEnabled:
          _prefs.getBool(_config.hapticFeedbackEnabledStorageKey) ??
              _config.defaultHapticFeedbackEnabled,
      dynamicThemeMode: DynamicThemeMode.fromStorage(
        _prefs.getString(_config.dynamicThemeModeStorageKey) ??
            _config.defaultDynamicThemeMode,
      ),
      dynamicThemeIntensity: AppSettings._clampDynamicThemeIntensity(
        _prefs.getDouble(_config.dynamicThemeIntensityStorageKey) ??
            _config.defaultDynamicThemeIntensity,
      ),
      cloudSyncEnabled:
          _prefs.getBool(_config.cloudSyncEnabledStorageKey) ?? false,
      lastCloudSyncAt: _decodeDateTime(
        _prefs.getString(_config.lastCloudSyncAtStorageKey),
      ),
      rewardedPremiumExpiresAt: _decodeDateTime(
        _prefs.getString(_config.rewardedPremiumExpiresAtStorageKey),
      ),
      premiumVideoExportSkin: PremiumVideoExportSkin.fromStorage(
        _prefs.getString(_config.premiumVideoExportSkinStorageKey) ??
            _config.defaultPremiumVideoExportSkin,
      ),
      premiumVideoExportColor:
          _prefs.getInt(_config.premiumVideoExportColorStorageKey) ??
              _config.defaultPremiumVideoExportColor,
      premiumVideoExportEffect: PremiumVideoExportEffect.fromStorage(
        _prefs.getString(_config.premiumVideoExportEffectStorageKey) ??
            _config.defaultPremiumVideoExportEffect,
      ),
      premiumVideoExportShowLogo:
          _prefs.getBool(_config.premiumVideoExportShowLogoStorageKey) ??
              _config.defaultPremiumVideoExportShowLogo,
      premiumVideoExportQuality: PremiumVideoExportQuality.fromStorage(
        _prefs.getString(_config.premiumVideoExportQualityStorageKey) ??
            _config.defaultPremiumVideoExportQuality,
      ),
    );
  }

  /// Persists all supported settings values to storage.
  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_config.darkModeStorageKey, settings.darkMode);
    await _prefs.setBool(
      _config.useSystemThemeStorageKey,
      settings.useSystemTheme,
    );
    if (settings.localeCode == null || settings.localeCode!.isEmpty) {
      await _prefs.remove(_config.localeStorageKey);
    } else {
      await _prefs.setString(
        _config.localeStorageKey,
        settings.localeCode!,
      );
    }
    if (settings.themeColorNote == null || settings.themeColorNote!.isEmpty) {
      await _prefs.remove(_config.themeColorNoteStorageKey);
    } else {
      await _prefs.setString(
        _config.themeColorNoteStorageKey,
        settings.themeColorNote!,
      );
    }
    await _prefs.setDouble(
      _config.referencePitchStorageKey,
      settings.referencePitch,
    );
    await _prefs.setString(
      _config.tunerTranspositionStorageKey,
      settings.tunerTransposition,
    );
    await _prefs.setBool(
      _config.hapticFeedbackEnabledStorageKey,
      settings.hapticFeedbackEnabled,
    );
    await _prefs.setString(
      _config.dynamicThemeModeStorageKey,
      settings.dynamicThemeMode.storageValue,
    );
    await _prefs.setDouble(
      _config.dynamicThemeIntensityStorageKey,
      AppSettings._clampDynamicThemeIntensity(settings.dynamicThemeIntensity),
    );
    await _prefs.setBool(
      _config.cloudSyncEnabledStorageKey,
      settings.cloudSyncEnabled,
    );
    if (settings.lastCloudSyncAt == null) {
      await _prefs.remove(_config.lastCloudSyncAtStorageKey);
    } else {
      await _prefs.setString(
        _config.lastCloudSyncAtStorageKey,
        settings.lastCloudSyncAt!.toIso8601String(),
      );
    }
    if (settings.rewardedPremiumExpiresAt == null) {
      await _prefs.remove(_config.rewardedPremiumExpiresAtStorageKey);
    } else {
      await _prefs.setString(
        _config.rewardedPremiumExpiresAtStorageKey,
        settings.rewardedPremiumExpiresAt!.toIso8601String(),
      );
    }
    await _prefs.setString(
      _config.premiumVideoExportSkinStorageKey,
      settings.premiumVideoExportSkin.storageValue,
    );
    await _prefs.setInt(
      _config.premiumVideoExportColorStorageKey,
      settings.premiumVideoExportColor,
    );
    await _prefs.setString(
      _config.premiumVideoExportEffectStorageKey,
      settings.premiumVideoExportEffect.storageValue,
    );
    await _prefs.setBool(
      _config.premiumVideoExportShowLogoStorageKey,
      settings.premiumVideoExportShowLogo,
    );
    await _prefs.setString(
      _config.premiumVideoExportQualityStorageKey,
      settings.premiumVideoExportQuality.storageValue,
    );
  }

  DateTime? _decodeDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String? _decodeLocaleCode(String? value) {
    if (value == null || value.isEmpty) return null;
    return _supportedLocaleCodes.contains(value) ? value : null;
  }
}
