import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/metronome_sound_library.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/metronome_sound_library_controller.dart';
import 'package:music_life/services/ad_service.dart';

class MockAdService extends Mock implements IAdService {}
class MockMetronomeSettingsController extends Mock implements MetronomeSettingsController {}
class MockPremiumSettingsController extends Mock implements PremiumSettingsController {}
class MockRewardItem extends Mock implements RewardItem {}

void main() {
  late MockAdService mockAdService;
  late MockMetronomeSettingsController mockSettingsController;
  late MockPremiumSettingsController mockPremiumController;
  late ProviderContainer container;

  setUp(() {
    mockAdService = MockAdService();
    mockSettingsController = MockMetronomeSettingsController();
    mockPremiumController = MockPremiumSettingsController();
    
    container = ProviderContainer(
      overrides: [
        adServiceProvider.overrideWithValue(mockAdService),
        metronomeSettingsControllerProvider.overrideWithValue(mockSettingsController),
        premiumSettingsControllerProvider.overrideWithValue(mockPremiumController),
      ],
    );
    
    registerFallbackValue(MockRewardItem());
    registerFallbackValue(Duration.zero);
  });

  tearDown(() {
    container.dispose();
  });

  group('MetronomeSoundLibraryNotifier', () {
    test('initial state has no installing pack', () {
      final state = container.read(metronomeSoundLibraryControllerProvider);
      expect(state.installingPackId, isNull);
    });

    test('handleSoundPackAction for free/unlocked pack calls install and select', () async {
      final pack = metronomeSoundPacks.firstWhere((p) => !p.premiumOnly);
      
      when(() => mockSettingsController.installSoundPack(any()))
          .thenAnswer((_) async {});
      when(() => mockSettingsController.selectSoundPack(any()))
          .thenAnswer((_) async {});

      final notifier = container.read(metronomeSoundLibraryControllerProvider.notifier);
      final result = await notifier.handleSoundPackAction(
        pack: pack,
        isLocked: false,
        rewardedDuration: Duration.zero,
      );

      expect(result, isTrue);
      expect(container.read(metronomeSoundLibraryControllerProvider).installingPackId, isNull);
      verify(() => mockSettingsController.installSoundPack(pack.id)).called(1);
      verify(() => mockSettingsController.selectSoundPack(pack.id)).called(1);
    });

    test('handleSoundPackAction for locked pack shows ad and proceeds on success', () async {
      final pack = metronomeSoundPacks.firstWhere((p) => p.premiumOnly);
      
      when(() => mockAdService.showRewardedAd(onUserEarnedReward: any(named: 'onUserEarnedReward')))
          .thenAnswer((invocation) async {
            final onReward = invocation.namedArguments[#onUserEarnedReward] as void Function(RewardItem);
            onReward(MockRewardItem());
            return true;
          });
          
      when(() => mockPremiumController.unlockRewardedPremiumFor(any()))
          .thenAnswer((_) async {});
      when(() => mockSettingsController.installSoundPack(any()))
          .thenAnswer((_) async {});
      when(() => mockSettingsController.selectSoundPack(any()))
          .thenAnswer((_) async {});

      final notifier = container.read(metronomeSoundLibraryControllerProvider.notifier);
      final result = await notifier.handleSoundPackAction(
        pack: pack,
        isLocked: true,
        rewardedDuration: const Duration(hours: 1),
      );

      expect(result, isTrue);
      verify(() => mockAdService.showRewardedAd(onUserEarnedReward: any(named: 'onUserEarnedReward'))).called(1);
      verify(() => mockPremiumController.unlockRewardedPremiumFor(const Duration(hours: 1))).called(1);
      verify(() => mockSettingsController.installSoundPack(pack.id)).called(1);
      verify(() => mockSettingsController.selectSoundPack(pack.id)).called(1);
    });

    test('handleSoundPackAction for locked pack returns false if ad fails', () async {
      final pack = metronomeSoundPacks.firstWhere((p) => p.premiumOnly);
      
      when(() => mockAdService.showRewardedAd(onUserEarnedReward: any(named: 'onUserEarnedReward')))
          .thenAnswer((_) async => false);

      final notifier = container.read(metronomeSoundLibraryControllerProvider.notifier);
      final result = await notifier.handleSoundPackAction(
        pack: pack,
        isLocked: true,
        rewardedDuration: const Duration(hours: 1),
      );

      expect(result, isFalse);
      verify(() => mockAdService.showRewardedAd(onUserEarnedReward: any(named: 'onUserEarnedReward'))).called(1);
      verifyNever(() => mockSettingsController.installSoundPack(any()));
    });
  });
}
