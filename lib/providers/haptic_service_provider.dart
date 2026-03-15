import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/haptic_service.dart';
import 'app_settings_provider.dart';

final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(
    isEnabled: () => ref.read(appSettingsProvider).hapticFeedbackEnabled,
  );
});
