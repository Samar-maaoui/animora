// ignore_for_file: constant_identifier_names
enum EventStatus {
  DRAFT,
  PUBLISHED,
  COMPLETED,
  CANCELLED;

  String get label => switch (this) {
    EventStatus.DRAFT => "Brouillon",
    EventStatus.PUBLISHED => "Publié",
    EventStatus.COMPLETED => "Terminé",
    EventStatus.CANCELLED => "Annulé",
  };
}
