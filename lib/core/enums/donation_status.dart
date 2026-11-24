// ignore_for_file: constant_identifier_names
enum DonationStatus { PENDING, CONFIRMED, CANCELLED }

extension DonationStatusLabel on DonationStatus {
  String get label => switch (this) {
    DonationStatus.PENDING => 'En attente',
    DonationStatus.CONFIRMED => 'Confirmé (démonstration)',
    DonationStatus.CANCELLED => 'Annulé',
  };
}
