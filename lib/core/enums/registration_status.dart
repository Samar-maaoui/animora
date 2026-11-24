// ignore_for_file: constant_identifier_names
enum RegistrationStatus {
  CONFIRMED,
  WAITLISTED,
  CANCELLED,
  ATTENDED;

  String get label => switch (this) {
    RegistrationStatus.CONFIRMED => "Confirmée",
    RegistrationStatus.WAITLISTED => "Liste d’attente",
    RegistrationStatus.CANCELLED => "Annulée",
    RegistrationStatus.ATTENDED => "Présent",
  };
}
