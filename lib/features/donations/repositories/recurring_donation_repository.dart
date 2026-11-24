import '../models/recurring_donation.dart';
import '../models/donation.dart';
import '../../../core/enums/donation_frequency.dart';
import '../../../core/enums/recurring_donation_status.dart';

abstract interface class RecurringDonationRepository {
  Future<List<RecurringDonation>> getRecurringDonations();
  Future<void> createRecurringDonation(
    int campaignId,
    double amount,
    DonationFrequency frequency,
    DateTime nextDate, {
    String? requestKey,
  });
  Future<void> changeRecurringStatus(int id, RecurringDonationStatus status);
  Future<Donation> prepareRecurringOccurrence(int id);
}
