import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_pitch_bridge.dart';
import 'repositories/composition_repository.dart';
import 'repositories/recording_repository.dart';

/// Factory function type for creating [NativePitchBridge] instances.
typedef PitchBridgeFactory = NativePitchBridge Function();

/// A minimal service locator that manages the lifecycle of long-lived
/// services, enabling dependency injection and mock-friendly testing.
///
/// Initialize once via [ServiceLocator.initialize] in [main] before calling
/// [runApp], then access the singleton via [ServiceLocator.instance]:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await ServiceLocator.initialize();
///   runApp(const MusicLifeApp());
/// }
/// ```
///
/// In tests, supply a custom instance via [overrideForTesting]:
///
/// ```dart
/// ServiceLocator.overrideForTesting(ServiceLocator.forTesting(
///   prefs: mockSharedPreferences,
///   pitchBridgeFactory: () => FakeNativePitchBridge(),
/// ));
/// ```
class ServiceLocator {
  ServiceLocator._({
    required SharedPreferences prefs,
    PitchBridgeFactory? pitchBridgeFactory,
    RecordingRepository? recordingRepository,
    CompositionRepository? compositionRepository,
  })  : _prefs = prefs,
        pitchBridgeFactory =
            pitchBridgeFactory ?? (() => NativePitchBridge()),
        recordingRepository =
            recordingRepository ?? RecordingRepository(prefs),
        compositionRepository =
            compositionRepository ?? CompositionRepository(prefs);

  static ServiceLocator? _instance;

  /// The single global instance.
  ///
  /// Throws if [initialize] has not been called first.
  static ServiceLocator get instance {
    assert(
      _instance != null,
      'ServiceLocator.initialize() must be called before accessing the instance.',
    );
    return _instance!;
  }

  /// Initializes the locator by loading [SharedPreferences] and creating the
  /// [RecordingRepository].  Call once in [main] before [runApp].
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = ServiceLocator._(prefs: prefs);
  }

  /// Creates a locator with explicit dependencies.  Intended for tests.
  @visibleForTesting
  factory ServiceLocator.forTesting({
    required SharedPreferences prefs,
    PitchBridgeFactory? pitchBridgeFactory,
    RecordingRepository? recordingRepository,
    CompositionRepository? compositionRepository,
  }) {
    return ServiceLocator._(
      prefs: prefs,
      pitchBridgeFactory: pitchBridgeFactory,
      recordingRepository: recordingRepository,
      compositionRepository: compositionRepository,
    );
  }

  /// Replaces the global instance.  Call in test [setUp] to inject mocks.
  @visibleForTesting
  static void overrideForTesting(ServiceLocator locator) {
    _instance = locator;
  }

  /// Resets the global instance to `null`.  Call in test [tearDown].
  @visibleForTesting
  static void reset() {
    _instance = null;
  }

  final SharedPreferences _prefs;

  /// The shared [SharedPreferences] instance.
  SharedPreferences get prefs => _prefs;

  /// Factory that creates a new [NativePitchBridge].
  ///
  /// Replace with a mock factory in tests to avoid loading native libraries:
  /// ```dart
  /// pitchBridgeFactory: () => FakeNativePitchBridge(),
  /// ```
  final PitchBridgeFactory pitchBridgeFactory;

  /// The shared [RecordingRepository] instance.
  final RecordingRepository recordingRepository;

  /// The shared [CompositionRepository] instance.
  final CompositionRepository compositionRepository;
}
