// ignore_for_file: constant_identifier_names
enum MaterialDonationStatus { PENDING, RECEIVED, REJECTED }

extension MaterialDonationStatusLabel on MaterialDonationStatus {
  String get label => switch (this) {
    MaterialDonationStatus.PENDING => 'En attente',
    MaterialDonationStatus.RECEIVED => 'Réceptionné',
    MaterialDonationStatus.REJECTED => 'Rejeté',
  };
}
