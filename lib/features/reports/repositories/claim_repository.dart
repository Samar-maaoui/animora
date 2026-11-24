import '../models/reclamation.dart';

abstract interface class ClaimRepository {
  Future<List<Reclamation>> getClaims();
  Future<Reclamation> getClaim(int id);
  Future<Reclamation> createClaim(int announcementId, String evidence);
  Future<void> decideClaim(int id, {required bool verified});
}
