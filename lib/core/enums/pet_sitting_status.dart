// ignore_for_file: constant_identifier_names
enum PetSittingStatus {
  PENDING,
  ACCEPTED,
  REJECTED,
  CANCELLED,
  IN_PROGRESS,
  COMPLETED,
}

extension PetSittingStatusLabel on PetSittingStatus {
  String get label => switch (this) {
    PetSittingStatus.PENDING => 'En attente',
    PetSittingStatus.ACCEPTED => 'Acceptée',
    PetSittingStatus.REJECTED => 'Refusée',
    PetSittingStatus.CANCELLED => 'Annulée',
    PetSittingStatus.IN_PROGRESS => 'En cours',
    PetSittingStatus.COMPLETED => 'Terminée',
  };
}
