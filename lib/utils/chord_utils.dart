/// Formats a [DateTime] as `HH:MM:SS` (24-hour clock, zero-padded).
String formatTimeHMS(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';
