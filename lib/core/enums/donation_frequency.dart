// ignore_for_file: constant_identifier_names
enum DonationFrequency { WEEKLY, MONTHLY }

extension DonationFrequencyLabel on DonationFrequency {
  String get label => switch (this) {
    DonationFrequency.WEEKLY => 'Chaque semaine',
    DonationFrequency.MONTHLY => 'Chaque mois',
  };
}
