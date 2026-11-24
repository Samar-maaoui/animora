import '../models/material_donation.dart';
import '../../../core/enums/material_type.dart';

abstract interface class MaterialDonationRepository {
  Future<List<MaterialDonation>> getMaterialDonations({int? campaignId});
  Future<MaterialDonation?> getMaterialForDonation(int donationId);
  Future<void> createMaterialDonation(
    int campaignId,
    MaterialType type,
    int quantity,
    String description, {
    int? needId,
    String? requestKey,
  });
  Future<void> receiveMaterialDonation(int id, {int? needId});
  Future<void> rejectMaterialDonation(int id);
}
