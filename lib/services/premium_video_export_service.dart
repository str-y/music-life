import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/premium_video_export.dart';

typedef PremiumVideoProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class PremiumVideoExportPlan {
  const PremiumVideoExportPlan({
    required this.sourceVideoPath,
    required this.outputVideoPath,
    required this.renderWidth,
    required this.renderHeight,
    required this.videoBitrateMbps,
    required this.skin,
    required this.effect,
    required this.waveformColorHex,
    required this.showLogo,
    required this.ffmpegArguments,
  });

  final String sourceVideoPath;
  final String outputVideoPath;
  final int renderWidth;
  final int renderHeight;
  final int videoBitrateMbps;
  final PremiumVideoExportSkin skin;
  final PremiumVideoExportEffect effect;
  final String waveformColorHex;
  final bool showLogo;
  final List<String> ffmpegArguments;

  String get resolutionLabel => '${renderWidth}×$renderHeight';

  String get bitrateLabel => '${videoBitrateMbps} Mbps';

  String get ffmpegCommandLine => ffmpegArguments.join(' ');
}

class PremiumVideoExportService {
  PremiumVideoExportService({
    PremiumVideoProcessRunner processRunner = _defaultProcessRunner,
  }) : _processRunner = processRunner;

  final PremiumVideoProcessRunner _processRunner;

  PremiumVideoExportPlan buildPlan({
    required String sourceVideoPath,
    required PremiumVideoExportSettings settings,
  }) {
    final quality = _resolveQualityPreset(settings.quality);
    final skin = _resolveSkinPreset(settings.skin);
    final effect = _resolveEffectPreset(settings.effect);
    final waveformColorHex = _formatColor(settings.waveformColorValue);
    final outputVideoPath = _buildOutputPath(sourceVideoPath, settings.quality);
    final logoFilter = settings.showLogo
        ? ',drawtext=text=\'music-life\':fontcolor=white:fontsize=42:'
            'x=w-tw-56:y=72:box=1:boxcolor=black@0.28:boxborderw=18'
        : '';
    final filterComplex =
        '[0:v]scale=${quality.width}:${quality.height}:'
        'force_original_aspect_ratio=increase,'
        'crop=${quality.width}:${quality.height},'
        'eq=saturation=${skin.saturation}:contrast=${skin.contrast}'
        '[video];'
        '[0:a]aformat=channel_layouts=stereo,'
        'showwaves=s=${quality.width}x${skin.waveformHeight}:'
        'mode=cline:colors=$waveformColorHex,'
        'format=rgba,'
        '${effect.waveformFilter}colorchannelmixer=aa=${skin.opacity}'
        '[waves];'
        '[video][waves]overlay=0:H-h-${skin.bottomOffset}'
        '$logoFilter[outv]';

    return PremiumVideoExportPlan(
      sourceVideoPath: sourceVideoPath,
      outputVideoPath: outputVideoPath,
      renderWidth: quality.width,
      renderHeight: quality.height,
      videoBitrateMbps: quality.videoBitrateMbps,
      skin: settings.skin,
      effect: settings.effect,
      waveformColorHex: waveformColorHex,
      showLogo: settings.showLogo,
      ffmpegArguments: [
        'ffmpeg',
        '-y',
        '-i',
        sourceVideoPath,
        '-filter_complex',
        filterComplex,
        '-map',
        '[outv]',
        '-map',
        '0:a',
        '-c:v',
        'libx264',
        '-preset',
        quality.encoderPreset,
        '-r',
        '30',
        '-b:v',
        '${quality.videoBitrateMbps}M',
        '-maxrate',
        '${quality.videoBitrateMbps}M',
        '-bufsize',
        '${quality.videoBitrateMbps * 2}M',
        '-c:a',
        'aac',
        '-b:a',
        '320k',
        outputVideoPath,
      ],
    );
  }

  Future<File> createShareReadyCopy(PremiumVideoExportPlan plan) async {
    final outputFile = File(plan.outputVideoPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    final ffmpegArguments = plan.ffmpegArguments.first == 'ffmpeg'
        ? plan.ffmpegArguments.sublist(1)
        : plan.ffmpegArguments;
    final result = await _processRunner('ffmpeg', ffmpegArguments);
    if (result.exitCode == 0 && await outputFile.exists()) {
      return outputFile;
    }

    final sourceFile = File(plan.sourceVideoPath);
    return sourceFile.copy(plan.outputVideoPath);
  }

  String _buildOutputPath(
    String sourceVideoPath,
    PremiumVideoExportQuality quality,
  ) {
    final baseName = p.basenameWithoutExtension(sourceVideoPath);
    return p.join(
      Directory.systemTemp.path,
      '${baseName}_${quality.storageValue}_sns_export.mp4',
    );
  }

  String _formatColor(int colorValue) {
    return '#${(colorValue & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

Future<ProcessResult> _defaultProcessRunner(
  String executable,
  List<String> arguments,
) {
  return Process.run(executable, arguments);
}

class _QualityPreset {
  const _QualityPreset({
    required this.width,
    required this.height,
    required this.videoBitrateMbps,
    required this.encoderPreset,
  });

  final int width;
  final int height;
  final int videoBitrateMbps;
  final String encoderPreset;
}

class _SkinPreset {
  const _SkinPreset({
    required this.waveformHeight,
    required this.bottomOffset,
    required this.opacity,
    required this.saturation,
    required this.contrast,
  });

  final int waveformHeight;
  final int bottomOffset;
  final String opacity;
  final String saturation;
  final String contrast;
}

class _EffectPreset {
  const _EffectPreset({required this.waveformFilter});

  final String waveformFilter;
}

_QualityPreset _resolveQualityPreset(PremiumVideoExportQuality quality) {
  return switch (quality) {
    PremiumVideoExportQuality.social => const _QualityPreset(
        width: 1080,
        height: 1920,
        videoBitrateMbps: 8,
        encoderPreset: 'veryfast',
      ),
    PremiumVideoExportQuality.high => const _QualityPreset(
        width: 1440,
        height: 2560,
        videoBitrateMbps: 16,
        encoderPreset: 'medium',
      ),
    PremiumVideoExportQuality.ultra => const _QualityPreset(
        width: 2160,
        height: 3840,
        videoBitrateMbps: 30,
        encoderPreset: 'slow',
      ),
  };
}

_SkinPreset _resolveSkinPreset(PremiumVideoExportSkin skin) {
  return switch (skin) {
    PremiumVideoExportSkin.aurora => const _SkinPreset(
        waveformHeight: 280,
        bottomOffset: 180,
        opacity: '0.88',
        saturation: '1.08',
        contrast: '1.03',
      ),
    PremiumVideoExportSkin.neonPulse => const _SkinPreset(
        waveformHeight: 320,
        bottomOffset: 160,
        opacity: '0.96',
        saturation: '1.18',
        contrast: '1.08',
      ),
    PremiumVideoExportSkin.sunsetGold => const _SkinPreset(
        waveformHeight: 300,
        bottomOffset: 170,
        opacity: '0.9',
        saturation: '1.1',
        contrast: '1.05',
      ),
  };
}

_EffectPreset _resolveEffectPreset(PremiumVideoExportEffect effect) {
  return switch (effect) {
    PremiumVideoExportEffect.glow => const _EffectPreset(
        waveformFilter: 'gblur=sigma=16:steps=2,',
      ),
    PremiumVideoExportEffect.prism => const _EffectPreset(
        waveformFilter: 'split=3[a][b][c];[a]colorchannelmixer=rr=1:bb=0.4[ar];'
            '[b]colorchannelmixer=gg=1[bg];'
            '[c]colorchannelmixer=bb=1:rr=0.4[cb];'
            '[ar][bg]blend=all_mode=screen[ab];'
            '[ab][cb]blend=all_mode=screen,',
      ),
    PremiumVideoExportEffect.shimmer => const _EffectPreset(
        waveformFilter: 'tmix=frames=3:weights=\'1 2 1\',',
      ),
  };
}
