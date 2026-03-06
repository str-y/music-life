import 'package:flutter/material.dart';

const Map<String, Color> keyThemeColors = <String, Color>{
  'C': Colors.red,
  'C#': Colors.deepOrange,
  'Db': Colors.deepOrange,
  'D': Colors.orange,
  'D#': Colors.amber,
  'Eb': Colors.amber,
  'E': Colors.yellow,
  'F': Colors.green,
  'F#': Colors.teal,
  'Gb': Colors.teal,
  'G': Colors.blue,
  'G#': Colors.indigo,
  'Ab': Colors.indigo,
  'A': Colors.purple,
  'A#': Colors.pink,
  'Bb': Colors.pink,
  'B': Colors.cyan,
};
const double minThemeColorWeight = 0.4;
const double themeColorEnergyWeightRange = 0.6;

Color themeSeedColor(String? noteName, double energy) {
  if (noteName == null || noteName.isEmpty) return Colors.deepPurple;
  final match = RegExp(r'^[A-G](?:#|b)?').firstMatch(noteName);
  final key = match?.group(0);
  final base = keyThemeColors[key] ?? Colors.deepPurple;
  final clampedEnergy = energy.clamp(0.0, 1.0).toDouble();
  return Color.lerp(
        Colors.blueGrey,
        base,
        minThemeColorWeight + (clampedEnergy * themeColorEnergyWeightRange),
      ) ??
      base;
}
