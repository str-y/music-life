import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool darkMode;
  final double referencePitch;
  final String? dynamicThemeNote;
  final double dynamicThemeEnergy;

  const AppSettings({
    this.darkMode = false,
    this.referencePitch = 440.0,
    this.dynamicThemeNote,
    this.dynamicThemeEnergy = 0.0,
  });

  AppSettings copyWith({
    bool? darkMode,
    double? referencePitch,
    String? dynamicThemeNote,
    double? dynamicThemeEnergy,
    bool clearDynamicThemeNote = false,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      referencePitch: referencePitch ?? this.referencePitch,
      dynamicThemeNote: clearDynamicThemeNote
          ? null
          : (dynamicThemeNote ?? this.dynamicThemeNote),
      dynamicThemeEnergy: dynamicThemeEnergy ?? this.dynamicThemeEnergy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          darkMode == other.darkMode &&
          referencePitch == other.referencePitch &&
          dynamicThemeNote == other.dynamicThemeNote &&
          dynamicThemeEnergy == other.dynamicThemeEnergy;

  @override
  int get hashCode =>
      Object.hash(darkMode, referencePitch, dynamicThemeNote, dynamicThemeEnergy);
}

class SettingsRepository {
  const SettingsRepository(this._prefs);

  static const _kDarkMode = 'darkMode';
  static const _kReferencePitch = 'referencePitch';

  final SharedPreferences _prefs;

  AppSettings load() {
    return AppSettings(
      darkMode: _prefs.getBool(_kDarkMode) ?? false,
      referencePitch: _prefs.getDouble(_kReferencePitch) ?? 440.0,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(_kDarkMode, settings.darkMode);
    await _prefs.setDouble(_kReferencePitch, settings.referencePitch);
  }
}
