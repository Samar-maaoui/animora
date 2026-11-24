import '../models/temoignage.dart';

abstract interface class TestimonyRepository {
  Future<List<Temoignage>> getTestimonies(int id);
  Future<void> addTestimony(
    int id,
    String comment,
    DateTime date, {
    double? latitude,
    double? longitude,
    String? photo,
    bool locationConsent = false,
  });
}
