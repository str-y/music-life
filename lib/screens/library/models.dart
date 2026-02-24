class RecordingEntry {
  const RecordingEntry({
    required this.id,
    required this.title,
    required this.recordedAt,
    required this.durationSeconds,
    required this.waveformData,
  });

  final String id;
  final String title;
  final DateTime recordedAt;
  final int durationSeconds;

  /// Normalised amplitude values in [0.0, 1.0] used for waveform preview.
  final List<double> waveformData;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'recordedAt': recordedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'waveformData': waveformData,
      };

  factory RecordingEntry.fromJson(Map<String, dynamic> json) {
    return RecordingEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      waveformData: (json['waveformData'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}

class PracticeLogEntry {
  const PracticeLogEntry({
    required this.date,
    required this.durationMinutes,
    this.memo = '',
  });

  final DateTime date;
  final int durationMinutes;
  final String memo;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'memo': memo,
      };

  factory PracticeLogEntry.fromJson(Map<String, dynamic> json) {
    return PracticeLogEntry(
      date: DateTime.parse(json['date'] as String),
      durationMinutes: json['durationMinutes'] as int,
      memo: json['memo'] as String? ?? '',
    );
  }
}
