import 'package:flutter/services.dart';

typedef HapticFeedbackHandler = Future<void> Function();
typedef HapticEnabledReader = bool Function();

class HapticService {
  const HapticService({
    required HapticEnabledReader isEnabled,
    HapticFeedbackHandler? onSelectionClick,
    HapticFeedbackHandler? onMediumImpact,
  })  : _isEnabled = isEnabled,
        _onSelectionClick = onSelectionClick ?? HapticFeedback.selectionClick,
        _onMediumImpact = onMediumImpact ?? HapticFeedback.mediumImpact;

  final HapticEnabledReader _isEnabled;
  final HapticFeedbackHandler _onSelectionClick;
  final HapticFeedbackHandler _onMediumImpact;

  Future<void> selectionClick() => _trigger(_onSelectionClick);

  Future<void> mediumImpact() => _trigger(_onMediumImpact);

  Future<void> _trigger(HapticFeedbackHandler handler) {
    if (!_isEnabled()) {
      return Future<void>.value();
    }
    return handler();
  }
}
