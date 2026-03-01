import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

Future<XFile> generateShareCardImage({
  required String title,
  required List<String> lines,
  Color accentColor = const Color(0xFF6750A4),
}) async {
  const width = 1080;
  const height = 1080;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = const Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  canvas.drawRect(rect, Paint()..color = const Color(0xFFF8F7FF));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(70, 70, 940, 940),
      const Radius.circular(48),
    ),
    Paint()..color = Colors.white,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(70, 70, 940, 16),
      const Radius.circular(48),
    ),
    Paint()..color = accentColor,
  );

  final titlePainter = TextPainter(
    text: TextSpan(
      text: title,
      style: const TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1C1B1F),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(maxWidth: 820);
  titlePainter.paint(canvas, const Offset(130, 140));

  var y = 280.0;
  for (final line in lines.where((line) => line.trim().isNotEmpty)) {
    final linePainter = TextPainter(
      text: TextSpan(
        text: line,
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w500,
          color: Color(0xFF313033),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: 820);
    linePainter.paint(canvas, Offset(130, y));
    y += linePainter.height + 28;
  }

  final footerPainter = TextPainter(
    text: const TextSpan(
      text: 'music-life',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: Color(0xFF625B71),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 820);
  footerPainter.paint(canvas, Offset(130, height - 160));

  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw Exception('Failed to encode share card image');
  }

  final filePath = p.join(
    Directory.systemTemp.path,
    'music_life_share_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  final file = File(filePath);
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  return XFile(file.path, name: p.basename(file.path));
}
