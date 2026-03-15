import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../metronome_sound_library.dart';
import '../models/premium_video_export.dart';
import '../theme/dynamic_theme_mode.dart';

const Set<String> _supportedLocaleCodes = <String>{'en', 'ja'};
const Set<int> _supportedMetronomeDenominators = <int>{4, 8};

class MetronomePreset {
  const MetronomePreset({
    required this.name,
    required this.bpm,
    required this.timeSignatureNumerator,
    required this.timeSignatureDenominator,
  });

  final String name;
  final int bpm;
  final int timeSignatureNumerator;
  final int timeSignatureDenominator;

  String get timeSignatureLabel =>
      '$timeSignatureNumerator/$timeSignatureDenominator';

  Map<String, Object> toJson() => {
        'name': name,
        'bpm': bpm,
        'timeSignatureNumerator': timeSignatureNumerator,
        'timeSignatureDenominator': timeSignatureDenominator,
      };

  factory MetronomePreset.fromJson(Map<String, dynamic> json) {
    return MetronomePreset(
      name: (json['name'] as String?)?.trim() ?? '',
      bpm: _sanitizeMetronomeBpm(json['bpm'] as int?),
      timeSignatureNumerator: _sanitizeTimeSignatureNumerator(
        json['timeSignatureNumerator'] as int?,
      ),
      timeSignatureDenominator: _sanitizeTimeSignatureDenominator(
        json['timeSignatureDenominator'] as int?,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetronomePreset &&
          name == other.name &&
          bpm == other.bpm &&
          timeSignatureNumerator == other.timeSignatureNumerator &&
          timeSignatureDenominator == other.timeSignatureDenominator;

  @override
  int get hashCode => Object.hash(
        name,
        bpm,
        timeSignatureNumerator,
        timeSignatureDenominator,
      );
}

/// Immutable application settings persisted in local storage.
class AppSettings {
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
  final int metronomeBpm;
  final int metronomeTimeSignatureNumerator;
  final int metronomeTimeSignatureDenominator;
  final List<MetronomePreset> metronomePresets;
  final List<String> installedMetronomeSoundPackIds;
  final String selectedMetronomeSoundPackId;
  final PremiumVideoExportSkin premiumVideoExportSkin;
  final int premiumVideoExportColor;
  final PremiumVideoExportEffect premiumVideoExportEffect;
  final bool premiumVideoExportShowLogo;
  final PremiumVideoExportQuality premiumVideoExportQuality;

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
    this.metronomeBpm = 120,
    this.metronomeTimeSignatureNumerator = 4,
    this.metronomeTimeSignatureDenominator = 4,
    this.metronomePresets = const <MetronomePreset>[],
    this.installedMetronomeSoundPackIds = const <String>[
      defaultMetronomeSoundPackId,
    ],
    this.selectedMetronomeSoundPackId = defaultMetronomeSoundPackId,
    this.premiumVideoExportSkin = PremiumVideoExportSkin.aurora,
    this.premiumVideoExportColor = 0xFF7C4DFF,
    this.premiumVideoExportEffect = PremiumVideoExportEffect.glow,
    this.premiumVideoExportShowLogo = true,
    this.premiumVideoExportQuality = PremiumVideoExportQuality.high,
  });

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
    int? metronomeBpm,
    int? metronomeTimeSignatureNumerator,
    int? metronomeTimeSignatureDenominator,
    List<MetronomePreset>? metronomePresets,
    List<String>? installedMetronomeSoundPackIds,
    String? selectedMetronomeSoundPackId,
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
      lastCloudSyncAt:
          clearLastCloudSyncAt ? null : (lastCloudSyncAt ?? this.lastCloudSyncAt),
      rewardedPremiumExpiresAt: clearRewardedPremiumExpiresAt
          ? null
          : (rewardedPremiumExpiresAt ?? this.rewardedPremiumExpiresAt),
      metronomeBpm: _sanitizeMetronomeBpm(metronomeBpm ?? this.metronomeBpm),
      metronomeTimeSignatureNumerator: _sanitizeTimeSignatureNumerator(
        metronomeTimeSignatureNumerator ??
            this.metronomeTimeSignatureNumerator,
      ),
      metronomeTimeSignatureDenominator: _sanitizeTimeSignatureDenominator(
        metronomeTimeSignatureDenominator ??
            this.metronomeTimeSignatureDenominator,
      ),
      metronomePresets: List<MetronomePreset>.unmodifiable(
        metronomePresets ?? this.metronomePresets,
      ),
      installedMetronomeSoundPackIds: normalizeInstalledMetronomeSoundPackIds(
        installedMetronomeSoundPackIds ?? this.installedMetronomeSoundPackIds,
      ),
      selectedMetronomeSoundPackId: normalizeSelectedMetronomeSoundPackId(
        selectedMetronomeSoundPackId ?? this.selectedMetronomeSoundPackId,
        normalizeInstalledMetronomeSoundPackIds(
          installedMetronomeSoundPackIds ?? this.installedMetronomeSoundPackIds,
        ),
      ),
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
          metronomeBpm == other.metronomeBpm &&
          metronomeTimeSignatureNumerator ==
              other.metronomeTimeSignatureNumerator &&
          metronomeTimeSignatureDenominator ==
              other.metronomeTimeSignatureDenominator &&
          listEquals(metronomePresets, other.metronomePresets) &&
          listEquals(
            installedMetronomeSoundPackIds,
            other.installedMetronomeSoundPackIds,
          ) &&
          selectedMetronomeSoundPackId == other.selectedMetronomeSoundPackId &&
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
        metronomeBpm,
        metronomeTimeSignatureNumerator,
        metronomeTimeSignatureDenominator,
        Object.hashAll(metronomePresets),
        Object.hashAll(installedMetronomeSoundPackIds),
        selectedMetronomeSoundPackId,
        premiumVideoExportSkin,
        premiumVideoExportColor,
        premiumVideoExportEffect,
        premiumVideoExportShowLogo,
        premiumVideoExportQuality,
      ]);

  static double _clampDynamicThemeIntensity(double intensity) {
    return intensity.clamp(0.0, 1.0).toDouble();
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
      metronomeBpm: _sanitizeMetronomeBpm(
        _prefs.getInt(_config.metronomeBpmStorageKey) ??
            _config.defaultMetronomeBpm,
      ),
      metronomeTimeSignatureNumerator: _sanitizeTimeSignatureNumerator(
        _prefs.getInt(_config.metronomeTimeSignatureNumeratorStorageKey) ??
            _config.defaultMetronomeTimeSignatureNumerator,
      ),
      metronomeTimeSignatureDenominator: _sanitizeTimeSignatureDenominator(
        _prefs.getInt(_config.metronomeTimeSignatureDenominatorStorageKey) ??
            _config.defaultMetronomeTimeSignatureDenominator,
      ),
      metronomePresets: _decodeMetronomePresets(
        _prefs.getString(_config.metronomePresetsStorageKey),
      ),
      installedMetronomeSoundPackIds: normalizeInstalledMetronomeSoundPackIds(
        _prefs.getStringList(_config.metronomeSoundPacksStorageKey),
      ),
      selectedMetronomeSoundPackId: normalizeSelectedMetronomeSoundPackId(
        _prefs.getString(_config.selectedMetronomeSoundPackStorageKey),
        normalizeInstalledMetronomeSoundPackIds(
          _prefs.getStringList(_config.metronomeSoundPacksStorageKey),
        ),
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
    await _prefs.setInt(
      _config.metronomeBpmStorageKey,
      _sanitizeMetronomeBpm(settings.metronomeBpm),
    );
    await _prefs.setInt(
      _config.metronomeTimeSignatureNumeratorStorageKey,
      _sanitizeTimeSignatureNumerator(
        settings.metronomeTimeSignatureNumerator,
      ),
    );
    await _prefs.setInt(
      _config.metronomeTimeSignatureDenominatorStorageKey,
      _sanitizeTimeSignatureDenominator(
        settings.metronomeTimeSignatureDenominator,
      ),
    );
    await _prefs.setString(
      _config.metronomePresetsStorageKey,
      jsonEncode(
        settings.metronomePresets.map((preset) => preset.toJson()).toList(),
      ),
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
    await _prefs.setStringList(
      _config.metronomeSoundPacksStorageKey,
      normalizeInstalledMetronomeSoundPackIds(
        settings.installedMetronomeSoundPackIds,
      ),
    );
    await _prefs.setString(
      _config.selectedMetronomeSoundPackStorageKey,
      normalizeSelectedMetronomeSoundPackId(
        settings.selectedMetronomeSoundPackId,
        normalizeInstalledMetronomeSoundPackIds(
          settings.installedMetronomeSoundPackIds,
        ),
      ),
    );
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

  List<MetronomePreset> _decodeMetronomePresets(String? value) {
    if (value == null || value.isEmpty) return const <MetronomePreset>[];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const <MetronomePreset>[];
      return decoded
          .whereType<Map>()
          .map((preset) => Map<String, dynamic>.from(preset))
          .map(MetronomePreset.fromJson)
          .where((preset) => preset.name.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return const <MetronomePreset>[];
    }
  }
}

int _sanitizeMetronomeBpm(int? bpm) {
  return (bpm ?? 120).clamp(30, 240).toInt();
}

int _sanitizeTimeSignatureNumerator(int? numerator) {
  return (numerator ?? 4).clamp(2, 12).toInt();
}

int _sanitizeTimeSignatureDenominator(int? denominator) {
  final value = denominator ?? 4;
  return _supportedMetronomeDenominators.contains(value) ? value : 4;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
