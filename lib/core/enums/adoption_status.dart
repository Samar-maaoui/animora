// ignore_for_file: constant_identifier_names
enum AdoptionStatus { PENDING, ACCEPTED, REJECTED, CANCELLED }

extension AdoptionStatusLabel on AdoptionStatus {
  String get label => switch (this) {
    AdoptionStatus.PENDING => 'En attente',
    AdoptionStatus.ACCEPTED => 'Acceptée',
    AdoptionStatus.REJECTED => 'Refusée',
    AdoptionStatus.CANCELLED => 'Annulée',
  };
}
