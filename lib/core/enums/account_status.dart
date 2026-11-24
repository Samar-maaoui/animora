enum AccountStatus { pending, active, blocked }

extension AccountStatusLabel on AccountStatus {
  String get label => switch (this) {
    AccountStatus.pending => 'En attente',
    AccountStatus.active => 'Actif',
    AccountStatus.blocked => 'Bloqué',
  };
}
