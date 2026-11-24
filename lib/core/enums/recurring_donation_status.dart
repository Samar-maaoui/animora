// ignore_for_file: constant_identifier_names
enum RecurringDonationStatus { ACTIVE, PAUSED, CANCELLED }

extension RecurringDonationStatusLabel on RecurringDonationStatus {
  String get label => switch (this) {
    RecurringDonationStatus.ACTIVE => 'Actif',
    RecurringDonationStatus.PAUSED => 'Suspendu',
    RecurringDonationStatus.CANCELLED => 'Annulé',
  };
}
