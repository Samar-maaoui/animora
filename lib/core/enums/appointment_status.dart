// ignore_for_file: constant_identifier_names
enum AppointmentStatus { PENDING, CONFIRMED, REJECTED, CANCELLED, COMPLETED }

extension AppointmentStatusLabel on AppointmentStatus {
  String get label => switch (this) {
    AppointmentStatus.PENDING => 'En attente',
    AppointmentStatus.CONFIRMED => 'Confirmé',
    AppointmentStatus.REJECTED => 'Refusé',
    AppointmentStatus.CANCELLED => 'Annulé',
    AppointmentStatus.COMPLETED => 'Terminé',
  };
}
