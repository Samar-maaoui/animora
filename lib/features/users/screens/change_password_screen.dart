import '../../../core/widgets/password_rules_checklist.dart';
import '../../../core/widgets/app_notification.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/models/auth_requests.dart';
import '../../auth/state/auth_session.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidden = true;
  String? _error, _errorField;

  @override
  void dispose() {
    for (final controller in [_current, _next, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clearError(String _) {
    if (_error != null) {
      setState(() {
        _error = null;
        _errorField = null;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    try {
      await context.read<AuthSession>().changePassword(
        _current.text,
        _next.text,
      );
      if (!mounted) return;
      AppNotification.success(
        context,
        'Mot de passe modifié. Vos autres sessions ont été déconnectées.',
      );
      GuardedForm.savedGo(context, '/profile');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(error);
          _errorField = error is AuthFailure ? error.field : null;
        });
      }
    }
  }

  Widget _visibilityToggle(bool busy) => IconButton(
    tooltip: _hidden
        ? 'Afficher les mots de passe'
        : 'Masquer les mots de passe',
    onPressed: busy ? null : () => setState(() => _hidden = !_hidden),
    icon: Icon(
      _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Changer le mot de passe')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GuardedForm(
              formKey: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    key: const ValueKey('currentPassword'),
                    label: 'Mot de passe actuel',
                    controller: _current,
                    obscureText: _hidden,
                    validator: FormValidators.requiredText,
                    errorText: _errorField == 'currentPassword' ? _error : null,
                    enabled: !session.busy,
                    onChanged: _clearError,
                    suffixIcon: _visibilityToggle(session.busy),
                  ),
                  AppTextField(
                    key: const ValueKey('newPassword'),
                    label: 'Nouveau mot de passe',
                    controller: _next,
                    obscureText: _hidden,
                    validator: (value) =>
                        FormValidators.newPassword(value, _current.text),
                    errorText: _errorField == 'newPassword' ? _error : null,
                    enabled: !session.busy,
                    onChanged: _clearError,
                  ),
                  PasswordRulesChecklist(controller: _next),
                  AppTextField(
                    key: const ValueKey('passwordConfirmation'),
                    label: 'Confirmer le nouveau mot de passe',
                    controller: _confirmation,
                    obscureText: _hidden,
                    validator: (value) =>
                        FormValidators.confirmation(value, _next.text),
                    enabled: !session.busy,
                    onChanged: _clearError,
                  ),
                  if (_error != null && _errorField == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  AppButton(
                    label: 'Enregistrer',
                    loading: session.busy,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
