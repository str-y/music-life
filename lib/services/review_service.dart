import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

abstract class InAppReviewApi {
  Future<bool> isAvailable();

  Future<void> requestReview();
}

class InAppReviewClient implements InAppReviewApi {
  const InAppReviewClient();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

class ReviewService {
  ReviewService({InAppReviewApi? api}) : _api = api ?? const InAppReviewClient();

  final InAppReviewApi _api;

  Future<bool> requestReviewIfAvailable() async {
    if (!await _api.isAvailable()) {
      return false;
    }
    await _api.requestReview();
    return true;
  }
}
