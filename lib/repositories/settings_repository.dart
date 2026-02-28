import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool darkMode;
  final double referencePitch;

  const AppSettings({
    this.darkMode = false,
    this.referencePitch = 440.0,
  });

  AppSettings copyWith({bool? darkMode, double? referencePitch}) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      referencePitch: referencePitch ?? this.referencePitch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          darkMode == other.darkMode &&
          referencePitch == other.referencePitch;

  @override
  int get hashCode => Object.hash(darkMode, referencePitch);
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
