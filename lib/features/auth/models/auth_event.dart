/// Entry of the security journal (never contains a password or a hash).
enum AuthEventType {
  register,
  loginSuccess,
  loginFailure,
  loginLocked,
  logout,
  sessionExpired,
  profileUpdate,
  passwordChange,
  statusChange,
  photoUpdate,
  biometricEnabled,
  biometricDisabled,
  loginBiometric,
  passwordResetRequested,
  passwordReset,
  emailCodeSent,
  emailVerified,
  accountRejected,
  accountDeleted,
}

extension AuthEventTypeLabel on AuthEventType {
  String get label => switch (this) {
    AuthEventType.register => 'Inscription',
    AuthEventType.loginSuccess => 'Connexion réussie',
    AuthEventType.loginFailure => 'Échec de connexion',
    AuthEventType.loginLocked => 'Connexion bloquée (verrouillage)',
    AuthEventType.logout => 'Déconnexion',
    AuthEventType.sessionExpired => 'Session expirée',
    AuthEventType.profileUpdate => 'Profil modifié',
    AuthEventType.passwordChange => 'Mot de passe changé',
    AuthEventType.statusChange => 'Statut modifié',
    AuthEventType.photoUpdate => 'Photo de profil modifiée',
    AuthEventType.biometricEnabled => 'Connexion biométrique activée',
    AuthEventType.biometricDisabled => 'Connexion biométrique désactivée',
    AuthEventType.loginBiometric => 'Connexion biométrique',
    AuthEventType.passwordResetRequested => 'Code de réinitialisation demandé',
    AuthEventType.passwordReset => 'Mot de passe réinitialisé',
    AuthEventType.emailCodeSent => 'Code de vérification e-mail envoyé',
    AuthEventType.emailVerified => 'Adresse e-mail vérifiée',
    AuthEventType.accountRejected => 'Inscription refusée (compte supprimé)',
    AuthEventType.accountDeleted => 'Compte supprimé',
  };
}

class AuthEvent {
  const AuthEvent({
    required this.id,
    required this.type,
    required this.createdAt,
    this.email,
    this.userId,
    this.actorId,
    this.details,
  });
  final int id;
  final AuthEventType type;
  final DateTime createdAt;
  final String? email, userId, actorId, details;
}
