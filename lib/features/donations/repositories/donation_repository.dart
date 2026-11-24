import '../models/donation.dart';

abstract interface class DonationRepository {
  Future<List<Donation>> getDonations({int? campaignId});
  Future<Donation> getDonation(int id);
  Future<Donation> createFinancialDonation(
    int campaignId,
    double amount, {
    bool confirmSimulation = false,
    String? requestKey,
  });
  Future<void> confirmFinancialDonation(int id);
  Future<void> cancelDonation(int id);
}
