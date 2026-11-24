import '../models/donation_receipt.dart';

abstract interface class DonationReceiptRepository {
  Future<DonationReceipt?> getReceiptForDonation(int id);
  Future<DonationReceipt> getReceipt(int id);
}
