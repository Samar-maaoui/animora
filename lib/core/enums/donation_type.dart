// ignore_for_file: constant_identifier_names
enum DonationType { FINANCIAL, MATERIAL }

extension DonationTypeLabel on DonationType {
  String get label => switch (this) {
    DonationType.FINANCIAL => 'Financier simulé',
    DonationType.MATERIAL => 'Matériel',
  };
}
