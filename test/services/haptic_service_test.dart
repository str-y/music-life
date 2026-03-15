import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/services/haptic_service.dart';

void main() {
  group('HapticService', () {
    test('selectionClick forwards haptics when enabled', () async {
      var callCount = 0;
      final service = HapticService(
        isEnabled: () => true,
        onSelectionClick: () async {
          callCount++;
        },
      );

      await service.selectionClick();

      expect(callCount, 1);
    });

    test('mediumImpact skips haptics when disabled', () async {
      var callCount = 0;
      final service = HapticService(
        isEnabled: () => false,
        onMediumImpact: () async {
          callCount++;
        },
      );

      await service.mediumImpact();

      expect(callCount, 0);
    });
  });
}
