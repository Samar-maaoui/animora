// ignore_for_file: constant_identifier_names
enum VolunteerTaskStatus {
  AVAILABLE,
  ASSIGNED,
  IN_PROGRESS,
  COMPLETED;

  String get label => switch (this) {
    VolunteerTaskStatus.AVAILABLE => "Disponible",
    VolunteerTaskStatus.ASSIGNED => "Attribuée",
    VolunteerTaskStatus.IN_PROGRESS => "En cours",
    VolunteerTaskStatus.COMPLETED => "Terminée",
  };
}
