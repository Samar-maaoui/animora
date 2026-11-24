// ignore_for_file: constant_identifier_names
enum RegistrationType {
  PARTICIPANT,
  VOLUNTEER;

  String get label => switch (this) {
    RegistrationType.PARTICIPANT => "Participant",
    RegistrationType.VOLUNTEER => "Bénévole",
  };
}
