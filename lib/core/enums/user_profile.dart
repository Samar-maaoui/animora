enum UserProfile { citizen, veterinarian, fosterFamily, petSitter, admin }

extension UserProfileLabel on UserProfile {
  String get label => switch (this) {
    UserProfile.citizen => 'Citoyen',
    UserProfile.veterinarian => 'Vétérinaire',
    UserProfile.fosterFamily => 'Famille d’accueil',
    UserProfile.petSitter => 'Pet-sitter',
    UserProfile.admin => 'Administrateur',
  };
}
