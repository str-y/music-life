import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../metronome_sound_library.dart';

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
      bpm: sanitizeMetronomeBpm(json['bpm'] as int?),
      timeSignatureNumerator: sanitizeTimeSignatureNumerator(
        json['timeSignatureNumerator'] as int?,
      ),
      timeSignatureDenominator: sanitizeTimeSignatureDenominator(
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

class MetronomeSettings {
  const MetronomeSettings({
    this.bpm = 120,
    this.timeSignatureNumerator = 4,
    this.timeSignatureDenominator = 4,
    this.presets = const <MetronomePreset>[],
    this.installedSoundPackIds = const <String>[defaultMetronomeSoundPackId],
    this.selectedSoundPackId = defaultMetronomeSoundPackId,
  });

  final int bpm;
  final int timeSignatureNumerator;
  final int timeSignatureDenominator;
  final List<MetronomePreset> presets;
  final List<String> installedSoundPackIds;
  final String selectedSoundPackId;

  MetronomeSettings copyWith({
    int? bpm,
    int? timeSignatureNumerator,
    int? timeSignatureDenominator,
    List<MetronomePreset>? presets,
    List<String>? installedSoundPackIds,
    String? selectedSoundPackId,
  }) {
    final normalizedInstalledSoundPackIds =
        normalizeInstalledMetronomeSoundPackIds(
      installedSoundPackIds ?? this.installedSoundPackIds,
    );

    return MetronomeSettings(
      bpm: sanitizeMetronomeBpm(bpm ?? this.bpm),
      timeSignatureNumerator: sanitizeTimeSignatureNumerator(
        timeSignatureNumerator ?? this.timeSignatureNumerator,
      ),
      timeSignatureDenominator: sanitizeTimeSignatureDenominator(
        timeSignatureDenominator ?? this.timeSignatureDenominator,
      ),
      presets: List<MetronomePreset>.unmodifiable(presets ?? this.presets),
      installedSoundPackIds: normalizedInstalledSoundPackIds,
      selectedSoundPackId: normalizeSelectedMetronomeSoundPackId(
        selectedSoundPackId ?? this.selectedSoundPackId,
        normalizedInstalledSoundPackIds,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetronomeSettings &&
          bpm == other.bpm &&
          timeSignatureNumerator == other.timeSignatureNumerator &&
          timeSignatureDenominator == other.timeSignatureDenominator &&
          listEquals(presets, other.presets) &&
          listEquals(installedSoundPackIds, other.installedSoundPackIds) &&
          selectedSoundPackId == other.selectedSoundPackId;

  @override
  int get hashCode => Object.hashAll([
        bpm,
        timeSignatureNumerator,
        timeSignatureDenominator,
        Object.hashAll(presets),
        Object.hashAll(installedSoundPackIds),
        selectedSoundPackId,
      ]);
}

class MetronomeSettingsRepository {
  const MetronomeSettingsRepository(
    this._prefs, {
    AppConfig config = const AppConfig(),
  }) : _config = config;

  final SharedPreferences _prefs;
  final AppConfig _config;

  MetronomeSettings load() {
    final installedSoundPackIds = normalizeInstalledMetronomeSoundPackIds(
      _prefs.getStringList(_config.metronomeSoundPacksStorageKey),
    );
    return MetronomeSettings(
      bpm: sanitizeMetronomeBpm(
        _prefs.getInt(_config.metronomeBpmStorageKey) ??
            _config.defaultMetronomeBpm,
      ),
      timeSignatureNumerator: sanitizeTimeSignatureNumerator(
        _prefs.getInt(_config.metronomeTimeSignatureNumeratorStorageKey) ??
            _config.defaultMetronomeTimeSignatureNumerator,
      ),
      timeSignatureDenominator: sanitizeTimeSignatureDenominator(
        _prefs.getInt(_config.metronomeTimeSignatureDenominatorStorageKey) ??
            _config.defaultMetronomeTimeSignatureDenominator,
      ),
      presets: _decodeMetronomePresets(
        _prefs.getString(_config.metronomePresetsStorageKey),
      ),
      installedSoundPackIds: installedSoundPackIds,
      selectedSoundPackId: normalizeSelectedMetronomeSoundPackId(
        _prefs.getString(_config.selectedMetronomeSoundPackStorageKey),
        installedSoundPackIds,
      ),
    );
  }

  Future<void> save(MetronomeSettings settings) async {
    await _prefs.setInt(
      _config.metronomeBpmStorageKey,
      sanitizeMetronomeBpm(settings.bpm),
    );
    await _prefs.setInt(
      _config.metronomeTimeSignatureNumeratorStorageKey,
      sanitizeTimeSignatureNumerator(settings.timeSignatureNumerator),
    );
    await _prefs.setInt(
      _config.metronomeTimeSignatureDenominatorStorageKey,
      sanitizeTimeSignatureDenominator(settings.timeSignatureDenominator),
    );
    await _prefs.setString(
      _config.metronomePresetsStorageKey,
      jsonEncode(settings.presets.map((preset) => preset.toJson()).toList()),
    );
    final installedSoundPackIds = normalizeInstalledMetronomeSoundPackIds(
      settings.installedSoundPackIds,
    );
    await _prefs.setStringList(
      _config.metronomeSoundPacksStorageKey,
      installedSoundPackIds,
    );
    await _prefs.setString(
      _config.selectedMetronomeSoundPackStorageKey,
      normalizeSelectedMetronomeSoundPackId(
        settings.selectedSoundPackId,
        installedSoundPackIds,
      ),
    );
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

int sanitizeMetronomeBpm(int? bpm) {
  return (bpm ?? 120).clamp(30, 240).toInt();
}

int sanitizeTimeSignatureNumerator(int? numerator) {
  return (numerator ?? 4).clamp(2, 12).toInt();
}

int sanitizeTimeSignatureDenominator(int? denominator) {
  final value = denominator ?? 4;
  return _supportedMetronomeDenominators.contains(value) ? value : 4;
}
