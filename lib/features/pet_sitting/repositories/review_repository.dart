import '../models/review.dart';

abstract interface class ReviewRepository {
  Future<List<Review>> getReviews(String sitterId);
  Future<void> addReview(int requestId, int rating, String comment);
}
