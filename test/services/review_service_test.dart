import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/services/review_service.dart';

class _MockInAppReviewApi extends Mock implements InAppReviewApi {}

void main() {
  group('ReviewService', () {
    test('returns false when review dialog is unavailable', () async {
      final api = _MockInAppReviewApi();
      when(() => api.isAvailable()).thenAnswer((_) async => false);
      final service = ReviewService(api: api);

      final shown = await service.requestReviewIfAvailable();

      expect(shown, isFalse);
      verifyNever(() => api.requestReview());
    });

    test('requests review dialog when available', () async {
      final api = _MockInAppReviewApi();
      when(() => api.isAvailable()).thenAnswer((_) async => true);
      when(() => api.requestReview()).thenAnswer((_) async {});
      final service = ReviewService(api: api);

      final shown = await service.requestReviewIfAvailable();

      expect(shown, isTrue);
      verify(() => api.requestReview()).called(1);
    });
  });
}
