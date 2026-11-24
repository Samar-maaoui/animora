// ignore_for_file: constant_identifier_names
enum AnimalStatus {
  AVAILABLE,
  FOSTERED,
  PENDING_ADOPTION,
  ADOPTED,
  LOST,
  FOUND,
}

extension AnimalStatusLabel on AnimalStatus {
  String get label => switch (this) {
    AnimalStatus.AVAILABLE => 'À adopter',
    AnimalStatus.FOSTERED => 'En famille d’accueil',
    AnimalStatus.PENDING_ADOPTION => 'Adoption en cours',
    AnimalStatus.ADOPTED => 'Adopté',
    AnimalStatus.LOST => 'Perdu',
    AnimalStatus.FOUND => 'Trouvé',
  };
}
