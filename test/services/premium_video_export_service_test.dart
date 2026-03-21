import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/models/premium_video_export.dart';
import 'package:music_life/services/premium_video_export_service.dart';

void main() {
  final service = PremiumVideoExportService();

  test('buildPlan includes premium waveform composition and logo overlay', () {
    final plan = service.buildPlan(
      sourceVideoPath: '/tmp/performance.mp4',
      settings: const PremiumVideoExportSettings(
        waveformColorValue: 0xFF00E5FF,
      ),
    );

    expect(plan.outputVideoPath, endsWith('performance_high_sns_export.mp4'));
    expect(plan.resolutionLabel, '1440×2560');
    expect(plan.bitrateLabel, '16 Mbps');
    expect(plan.ffmpegCommandLine, contains('showwaves=s=1440x280'));
    expect(plan.ffmpegCommandLine, contains('colors=#00E5FF'));
    expect(plan.ffmpegCommandLine, contains('gblur=sigma=16:steps=2'));
    expect(plan.ffmpegCommandLine, contains("drawtext=text='music-life'"));
  });

  test('buildPlan omits logo overlay and upgrades output for ultra preset', () {
    final plan = service.buildPlan(
      sourceVideoPath: '/tmp/session.mov',
      settings: const PremiumVideoExportSettings(
        skin: PremiumVideoExportSkin.sunsetGold,
        waveformColorValue: 0xFFFFB300,
        effect: PremiumVideoExportEffect.shimmer,
        showLogo: false,
        quality: PremiumVideoExportQuality.ultra,
      ),
    );

    expect(plan.outputVideoPath, endsWith('session_ultra_sns_export.mp4'));
    expect(plan.resolutionLabel, '2160×3840');
    expect(plan.bitrateLabel, '30 Mbps');
    expect(plan.ffmpegCommandLine, contains('tmix=frames=3'));
    expect(plan.ffmpegCommandLine, contains('-preset slow'));
    expect(plan.ffmpegCommandLine, isNot(contains("drawtext=text='music-life'")));
  });

  test('createShareReadyCopy runs ffmpeg and returns the processed file',
      () async {
    final sourceDirectory = await Directory.systemTemp.createTemp(
      'music_life_video_export_test_',
    );
    addTearDown(() => sourceDirectory.delete(recursive: true));
    final sourceFile = File('${sourceDirectory.path}/take.mp4');
    await sourceFile.writeAsBytes(const <int>[1, 2, 3, 4, 5]);
    final executedCommands = <String>[];
    final exportService = PremiumVideoExportService(
      processRunner: (executable, arguments) async {
        executedCommands.add('$executable ${arguments.join(' ')}');
        final outputFile = File(arguments.last);
        await outputFile.writeAsBytes(const <int>[9, 8, 7, 6]);
        return ProcessResult(0, 0, '', '');
      },
    );

    final plan = exportService.buildPlan(
      sourceVideoPath: sourceFile.path,
      settings: const PremiumVideoExportSettings(),
    );
    final exported = await exportService.createShareReadyCopy(plan);

    expect(await exported.exists(), isTrue);
    expect(exported.path, endsWith('_high_sns_export.mp4'));
    expect(executedCommands, hasLength(1));
    expect(executedCommands.single, contains('ffmpeg -y -i'));
    expect(
      await exported.readAsBytes(),
      isNot(equals(await sourceFile.readAsBytes())),
    );
  });

  test('createShareReadyCopy falls back to copying the source when ffmpeg fails',
      () async {
    final sourceDirectory = await Directory.systemTemp.createTemp(
      'music_life_video_export_fallback_test_',
    );
    addTearDown(() => sourceDirectory.delete(recursive: true));
    final sourceFile = File('${sourceDirectory.path}/take.mp4');
    await sourceFile.writeAsBytes(const <int>[1, 2, 3, 4, 5]);
    final exportService = PremiumVideoExportService(
      processRunner: (_, _) async => ProcessResult(0, 1, '', 'ffmpeg missing'),
    );

    final plan = exportService.buildPlan(
      sourceVideoPath: sourceFile.path,
      settings: const PremiumVideoExportSettings(),
    );
    final exported = await exportService.createShareReadyCopy(plan);

    expect(await exported.readAsBytes(), await sourceFile.readAsBytes());
  });
}
