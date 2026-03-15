import 'package:flutter/material.dart';

enum PremiumVideoExportSkin {
  aurora,
  neonPulse,
  sunsetGold;

  String get storageValue => switch (this) {
        PremiumVideoExportSkin.aurora => 'aurora',
        PremiumVideoExportSkin.neonPulse => 'neon_pulse',
        PremiumVideoExportSkin.sunsetGold => 'sunset_gold',
      };

  static PremiumVideoExportSkin fromStorage(String? value) {
    return switch (value) {
      'neon_pulse' => PremiumVideoExportSkin.neonPulse,
      'sunset_gold' => PremiumVideoExportSkin.sunsetGold,
      _ => PremiumVideoExportSkin.aurora,
    };
  }
}

enum PremiumVideoExportEffect {
  glow,
  prism,
  shimmer;

  String get storageValue => switch (this) {
        PremiumVideoExportEffect.glow => 'glow',
        PremiumVideoExportEffect.prism => 'prism',
        PremiumVideoExportEffect.shimmer => 'shimmer',
      };

  static PremiumVideoExportEffect fromStorage(String? value) {
    return switch (value) {
      'prism' => PremiumVideoExportEffect.prism,
      'shimmer' => PremiumVideoExportEffect.shimmer,
      _ => PremiumVideoExportEffect.glow,
    };
  }
}

enum PremiumVideoExportQuality {
  social,
  high,
  ultra;

  String get storageValue => switch (this) {
        PremiumVideoExportQuality.social => 'social',
        PremiumVideoExportQuality.high => 'high',
        PremiumVideoExportQuality.ultra => 'ultra',
      };

  static PremiumVideoExportQuality fromStorage(String? value) {
    return switch (value) {
      'social' => PremiumVideoExportQuality.social,
      'ultra' => PremiumVideoExportQuality.ultra,
      _ => PremiumVideoExportQuality.high,
    };
  }
}

class PremiumVideoExportSettings {
  const PremiumVideoExportSettings({
    this.skin = PremiumVideoExportSkin.aurora,
    this.waveformColorValue = 0xFF7C4DFF,
    this.effect = PremiumVideoExportEffect.glow,
    this.showLogo = true,
    this.quality = PremiumVideoExportQuality.high,
  });

  final PremiumVideoExportSkin skin;
  final int waveformColorValue;
  final PremiumVideoExportEffect effect;
  final bool showLogo;
  final PremiumVideoExportQuality quality;

  Color get waveformColor => Color(waveformColorValue);

  PremiumVideoExportSettings copyWith({
    PremiumVideoExportSkin? skin,
    int? waveformColorValue,
    PremiumVideoExportEffect? effect,
    bool? showLogo,
    PremiumVideoExportQuality? quality,
  }) {
    return PremiumVideoExportSettings(
      skin: skin ?? this.skin,
      waveformColorValue: waveformColorValue ?? this.waveformColorValue,
      effect: effect ?? this.effect,
      showLogo: showLogo ?? this.showLogo,
      quality: quality ?? this.quality,
    );
  }
}
