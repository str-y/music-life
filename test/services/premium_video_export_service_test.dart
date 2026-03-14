import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/models/premium_video_export.dart';
import 'package:music_life/services/premium_video_export_service.dart';

void main() {
  const service = PremiumVideoExportService();

  test('buildPlan includes premium waveform composition and logo overlay', () {
    final plan = service.buildPlan(
      sourceVideoPath: '/tmp/performance.mp4',
      settings: const PremiumVideoExportSettings(
        skin: PremiumVideoExportSkin.aurora,
        waveformColorValue: 0xFF00E5FF,
        effect: PremiumVideoExportEffect.glow,
        showLogo: true,
        quality: PremiumVideoExportQuality.high,
      ),
    );

    expect(plan.outputVideoPath, endsWith('performance_high_sns_export.mp4'));
    expect(plan.resolutionLabel, '1440×2560');
    expect(plan.bitrateLabel, '16 Mbps');
    expect(plan.ffmpegCommandLine, contains('showwaves=s=1440x280'));
    expect(plan.ffmpegCommandLine, contains('colors=#00E5FF'));
    expect(plan.ffmpegCommandLine, contains('gblur=sigma=16:steps=2'));
    expect(plan.ffmpegCommandLine, contains('drawtext=text=\'music-life\''));
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
    expect(plan.ffmpegCommandLine, isNot(contains('drawtext=text=\'music-life\'')));
  });

  test('createShareReadyCopy writes a shareable exported file', () async {
    final sourceDirectory = await Directory.systemTemp.createTemp(
      'music_life_video_export_test_',
    );
    addTearDown(() => sourceDirectory.delete(recursive: true));
    final sourceFile = File('${sourceDirectory.path}/take.mp4');
    await sourceFile.writeAsBytes(const <int>[1, 2, 3, 4, 5]);

    final plan = service.buildPlan(
      sourceVideoPath: sourceFile.path,
      settings: const PremiumVideoExportSettings(),
    );
    final exported = await service.createShareReadyCopy(plan);

    expect(await exported.exists(), isTrue);
    expect(exported.path, endsWith('_high_sns_export.mp4'));
    expect(await exported.readAsBytes(), await sourceFile.readAsBytes());
  });
}
