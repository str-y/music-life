enum MetronomeSoundPackType { electronic, acousticDrums, percussion, voiceCount }

enum MetronomeLatencyProfile { ultraLow, balanced, preloaded }

class MetronomeSoundPack {
  const MetronomeSoundPack({
    required this.id,
    required this.type,
    required this.premiumOnly,
    required this.recommendedMinBpm,
    required this.recommendedMaxBpm,
    required this.latencyProfile,
  });

  final String id;
  final MetronomeSoundPackType type;
  final bool premiumOnly;
  final int recommendedMinBpm;
  final int recommendedMaxBpm;
  final MetronomeLatencyProfile latencyProfile;
}

const String defaultMetronomeSoundPackId = 'electronic_click';

const List<MetronomeSoundPack> metronomeSoundPacks = <MetronomeSoundPack>[
  MetronomeSoundPack(
    id: defaultMetronomeSoundPackId,
    type: MetronomeSoundPackType.electronic,
    premiumOnly: false,
    recommendedMinBpm: 60,
    recommendedMaxBpm: 220,
    latencyProfile: MetronomeLatencyProfile.ultraLow,
  ),
  MetronomeSoundPack(
    id: 'acoustic_kit',
    type: MetronomeSoundPackType.acousticDrums,
    premiumOnly: false,
    recommendedMinBpm: 80,
    recommendedMaxBpm: 145,
    latencyProfile: MetronomeLatencyProfile.balanced,
  ),
  MetronomeSoundPack(
    id: 'percussion_clave',
    type: MetronomeSoundPackType.percussion,
    premiumOnly: false,
    recommendedMinBpm: 146,
    recommendedMaxBpm: 240,
    latencyProfile: MetronomeLatencyProfile.ultraLow,
  ),
  MetronomeSoundPack(
    id: 'signature_voice_count',
    type: MetronomeSoundPackType.voiceCount,
    premiumOnly: true,
    recommendedMinBpm: 30,
    recommendedMaxBpm: 79,
    latencyProfile: MetronomeLatencyProfile.preloaded,
  ),
];

MetronomeSoundPack get defaultMetronomeSoundPack => metronomeSoundPacks.first;

MetronomeSoundPack? findMetronomeSoundPackById(String id) {
  for (final pack in metronomeSoundPacks) {
    if (pack.id == id) {
      return pack;
    }
  }
  return null;
}

List<String> normalizeInstalledMetronomeSoundPackIds(Iterable<String>? ids) {
  final normalized = <String>{defaultMetronomeSoundPackId};
  if (ids != null) {
    for (final id in ids) {
      if (findMetronomeSoundPackById(id) != null) {
        normalized.add(id);
      }
    }
  }
  return normalized.toList(growable: false);
}

String normalizeSelectedMetronomeSoundPackId(
  String? selectedId,
  Iterable<String> installedIds,
) {
  if (selectedId != null &&
      installedIds.contains(selectedId) &&
      findMetronomeSoundPackById(selectedId) != null) {
    return selectedId;
  }
  return defaultMetronomeSoundPackId;
}

MetronomeSoundPack recommendMetronomeSoundPack(int bpm) {
  for (final pack in metronomeSoundPacks.skip(1)) {
    if (bpm >= pack.recommendedMinBpm && bpm <= pack.recommendedMaxBpm) {
      return pack;
    }
  }
  return defaultMetronomeSoundPack;
}

MetronomeSoundPack resolveSelectedMetronomeSoundPack({
  required String selectedId,
  required Iterable<String> installedIds,
  required bool hasPremiumAccess,
}) {
  final pack = findMetronomeSoundPackById(
        normalizeSelectedMetronomeSoundPackId(selectedId, installedIds),
      ) ??
      defaultMetronomeSoundPack;
  if (pack.premiumOnly && !hasPremiumAccess) {
    return defaultMetronomeSoundPack;
  }
  return pack;
}
