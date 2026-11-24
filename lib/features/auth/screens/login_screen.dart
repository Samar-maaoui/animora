import 'package:flutter/material.dart';

import '../../../core/enums/user_profile.dart';
import '../widgets/auth_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.registered = false,
    this.passwordReset = false,
    this.awaitingApproval,
  });
  final bool registered, passwordReset;

  /// Profile of a just-verified account that needs admin validation.
  final UserProfile? awaitingApproval;

  @override
  Widget build(BuildContext context) {
    final awaiting = awaitingApproval;
    return AuthForm(
      // Confetti only when the account is really usable.
      celebrate: registered && awaiting == null,
      noticeIsPending: awaiting != null,
      notice: awaiting != null
          ? 'E-mail vérifié. Votre demande de compte '
                '« ${awaiting.label} » est envoyée : un administrateur doit '
                'la valider avant que vous puissiez utiliser Animora. '
                'Vous pourrez vous connecter pour suivre l’état de votre demande.'
          : registered
          ? '🎉 E-mail vérifié, compte créé ! Connectez-vous pour continuer.'
          : passwordReset
          ? 'Mot de passe réinitialisé. Connectez-vous avec le nouveau.'
          : null,
    );
  }
}
