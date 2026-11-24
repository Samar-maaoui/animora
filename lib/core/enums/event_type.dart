// ignore_for_file: constant_identifier_names
enum EventType {
  ADOPTION_DAY,
  AWARENESS,
  COLLECTION,
  SOLIDARITY_WALK,
  OTHER;

  String get label => switch (this) {
    EventType.ADOPTION_DAY => "Journée d’adoption",
    EventType.AWARENESS => "Sensibilisation",
    EventType.COLLECTION => "Collecte",
    EventType.SOLIDARITY_WALK => "Marche solidaire",
    EventType.OTHER => "Autre",
  };
}
