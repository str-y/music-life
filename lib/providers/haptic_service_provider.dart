import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/services/haptic_service.dart';
import 'package:music_life/providers/app_settings_provider.dart';

final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(
    isEnabled: () => ref.read(appSettingsProvider).hapticFeedbackEnabled,
  );
});
