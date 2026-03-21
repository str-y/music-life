import 'package:flutter/material.dart';

import 'package:music_life/theme/dynamic_theme_mode.dart';

const Map<String, int> _noteSteps = <String, int>{
  'C': 0,
  'C#': 1,
  'Db': 1,
  'D': 2,
  'D#': 3,
  'Eb': 3,
  'E': 4,
  'F': 5,
  'F#': 6,
  'Gb': 6,
  'G': 7,
  'G#': 8,
  'Ab': 8,
  'A': 9,
  'A#': 10,
  'Bb': 10,
  'B': 11,
};

const double minThemeColorWeight = 0.35;
const double themeColorEnergyWeightRange = 0.65;
final RegExp _notePattern = RegExp('^[A-G](?:#|b)?');
final RegExp _octavePattern = RegExp(r'-?\d+$');

Color themeSeedColor(
  String? noteName,
  double energy, {
  DynamicThemeMode mode = DynamicThemeMode.chill,
  double intensity = 1.0,
}) {
  if (noteName == null || noteName.isEmpty) return Colors.deepPurple;
  final match = _notePattern.firstMatch(noteName);
  final key = match?.group(0);
  final base = _baseThemeColor(key, mode);
  final octave = _parseOctave(noteName);
  final octaveTuned = _applyOctaveRange(base, octave);
  final clampedEnergy = energy.clamp(0.0, 1.0);
  final clampedIntensity = intensity.clamp(0.0, 1.0);
  return Color.lerp(
        Colors.blueGrey,
        octaveTuned,
        minThemeColorWeight +
            (clampedEnergy * clampedIntensity * themeColorEnergyWeightRange),
      ) ??
      octaveTuned;
}

Color _baseThemeColor(String? noteName, DynamicThemeMode mode) {
  final step = _noteSteps[noteName];
  if (step == null) return Colors.deepPurple;
  return switch (mode) {
    DynamicThemeMode.chill => _colorFromHsl(
        hue: (205 + step * 13) % 360,
        saturation: 0.48,
        lightness: 0.58,
      ),
    DynamicThemeMode.intense => _colorFromHsl(
        hue: (352 + step * 28) % 360,
        saturation: 0.82,
        lightness: 0.52,
      ),
    DynamicThemeMode.classical => _colorFromHsl(
        hue: (28 + step * 17) % 360,
        saturation: 0.42,
        lightness: 0.56,
      ),
  };
}

Color _applyOctaveRange(Color color, int? octave) {
  if (octave == null) return color;
  final hsl = HSLColor.fromColor(color);
  if (octave <= 2) {
    return hsl
        .withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();
  }
  if (octave >= 5) {
    return hsl
        .withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation - 0.04).clamp(0.0, 1.0))
        .toColor();
  }
  return color;
}

int? _parseOctave(String noteName) {
  final match = _octavePattern.firstMatch(noteName);
  if (match == null) return null;
  return int.tryParse(match.group(0)!);
}

Color _colorFromHsl({
  required int hue,
  required double saturation,
  required double lightness,
}) {
  return HSLColor.fromAHSL(
    1,
    hue.toDouble(),
    saturation,
    lightness,
  ).toColor();
}
