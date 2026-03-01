import 'dart:convert';
import 'dart:typed_data';

import '../repositories/recording_repository.dart';

String formatPracticeLogDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

String buildPracticeLogCsv(List<PracticeLogEntry> entries) {
  String escape(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  final buffer = StringBuffer('date,duration_minutes,memo\n');
  for (final entry in entries) {
    buffer.writeln(
      '${formatPracticeLogDate(entry.date)},${entry.durationMinutes},${escape(entry.memo)}',
    );
  }
  return buffer.toString();
}

Uint8List buildPracticeLogPdf(List<PracticeLogEntry> entries) {
  String toPdfText(String input) {
    final asciiOnly = input.runes
        .map((r) => (r >= 0x20 && r <= 0x7e) ? String.fromCharCode(r) : '?')
        .join();
    return asciiOnly
        .replaceAll('\\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  final lines = <String>[
    'Practice Log',
    'Date, Minutes, Memo',
    ...entries.map(
      (e) =>
          '${formatPracticeLogDate(e.date)}, ${e.durationMinutes}, ${e.memo}',
    ),
  ];

  final content = StringBuffer()
    ..writeln('BT')
    ..writeln('/F1 12 Tf')
    ..writeln('14 TL')
    ..writeln('50 780 Td');
  for (final line in lines) {
    content.writeln('(${toPdfText(line)}) Tj');
    content.writeln('T*');
  }
  content.writeln('ET');
  final contentBytes = ascii.encode(content.toString());

  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
    '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    '5 0 obj\n<< /Length ${contentBytes.length} >>\nstream\n${content.toString()}endstream\nendobj\n',
  ];

  final output = BytesBuilder();
  output.add(ascii.encode('%PDF-1.4\n'));

  final offsets = <int>[0];
  for (final obj in objects) {
    offsets.add(output.length);
    output.add(ascii.encode(obj));
  }
  final xrefOffset = output.length;

  output.add(ascii.encode('xref\n0 ${objects.length + 1}\n'));
  output.add(ascii.encode('0000000000 65535 f \n'));
  for (var i = 1; i < offsets.length; i++) {
    output.add(ascii.encode('${offsets[i].toString().padLeft(10, '0')} 00000 n \n'));
  }

  output.add(
    ascii.encode(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
    ),
  );
  return output.takeBytes();
}
