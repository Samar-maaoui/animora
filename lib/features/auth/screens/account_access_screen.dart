import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/animora_logo_app_bar.dart';
import '../../../core/enums/user_profile.dart';
import '../state/auth_session.dart';

class AccountAccessScreen extends StatefulWidget {
  const AccountAccessScreen({super.key, this.blocked = false});
  final bool blocked;
  @override
  State<AccountAccessScreen> createState() => _AccountAccessScreenState();
}

class _AccountAccessScreenState extends State<AccountAccessScreen> {
  String? _error;
  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    return Scaffold(
      appBar: const AnimoraLogoAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            EmptyStateWidget(
              title: widget.blocked
                  ? 'Compte bloqué'
                  : 'Compte en attente de validation',
              message: widget.blocked
                  ? 'Votre compte est bloqué. L’accès à l’application est suspendu. Contactez l’administrateur.'
                  : 'Votre adresse e-mail est vérifiée et votre demande de compte '
                        '${session.currentUser == null ? '' : '« ${session.currentUser!.profile.label} » '}'
                        'a bien été reçue. Un administrateur doit la valider avant que '
                        'vous puissiez accéder à Animora. Reconnectez-vous plus tard.',
              icon: widget.blocked
                  ? Icons.lock_outline
                  : Icons.hourglass_top_rounded,
            ),
            if (_error != null) Text(_error!, textAlign: TextAlign.center),
            AppButton(
              label: 'Retour à la connexion',
              loading: session.busy,
              onPressed: () async {
                try {
                  await session.logout();
                } catch (error) {
                  if (mounted) setState(() => _error = authErrorMessage(error));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
