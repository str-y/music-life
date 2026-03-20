import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

Color _deriveNeutralTone(
  Color accentColor, {
  required double lightness,
  required double saturationFactor,
}) {
  final hsl = HSLColor.fromColor(accentColor);
  return hsl
      .withSaturation(
        (hsl.saturation * saturationFactor).clamp(0.0, 1.0).toDouble(),
      )
      .withLightness(lightness.clamp(0.0, 1.0).toDouble())
      .toColor();
}

/// Renders a shareable square PNG card and returns it as an [XFile].
Future<XFile> generateShareCardImage({
  required String title,
  required List<String> lines,
  required Color accentColor,
  Color? backgroundColor,
  Color? surfaceColor,
  Color? titleColor,
  Color? bodyColor,
  Color? footerColor,
}) async {
  const width = 1080;
  const height = 1080;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const rect = Rect.fromLTWH(0, 0, 1080, 1080);
  final resolvedBackgroundColor = backgroundColor ??
      _deriveNeutralTone(
        accentColor,
        lightness: 0.97,
        saturationFactor: 0.14,
      );
  final resolvedSurfaceColor = surfaceColor ??
      _deriveNeutralTone(
        accentColor,
        lightness: 0.995,
        saturationFactor: 0.05,
      );
  final resolvedTitleColor = titleColor ??
      _deriveNeutralTone(
        accentColor,
        lightness: 0.14,
        saturationFactor: 0.24,
      );
  final resolvedBodyColor = bodyColor ??
      _deriveNeutralTone(
        accentColor,
        lightness: 0.22,
        saturationFactor: 0.18,
      );
  final resolvedFooterColor = footerColor ??
      _deriveNeutralTone(
        accentColor,
        lightness: 0.42,
        saturationFactor: 0.14,
      );

  canvas.drawRect(rect, Paint()..color = resolvedBackgroundColor);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(70, 70, 940, 940),
      const Radius.circular(48),
    ),
    Paint()..color = resolvedSurfaceColor,
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
      style: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: resolvedTitleColor,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(maxWidth: 820);
  titlePainter.paint(canvas, const Offset(130, 140));
  titlePainter.dispose();

  var y = 280.0;
  for (final line in lines.where((line) => line.trim().isNotEmpty)) {
    final linePainter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w500,
          color: resolvedBodyColor,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: 820);
    linePainter.paint(canvas, Offset(130, y));
    y += linePainter.height + 28;
    linePainter.dispose();
  }

  final footerPainter = TextPainter(
    text: TextSpan(
      text: 'music-life',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: resolvedFooterColor,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 820);
  footerPainter.paint(canvas, Offset(130, height - 160));
  footerPainter.dispose();

  final image = await recorder.endRecording().toImage(width, height);
  final ByteData? bytes;
  try {
    bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  } finally {
    image.dispose();
  }
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
