import '../../../core/widgets/password_rules_checklist.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/animora_logo_app_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/auth_requests.dart';
import '../state/auth_session.dart';
import '../widgets/auth_visuals.dart';

/// « Mot de passe oublié » : 1) e-mail → code envoyé, 2) code + nouveau mot
/// de passe.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});
  final String? initialEmail;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _codeSent = false, _hidePassword = true, _submitted = false;
  String? _error, _errorField, _demoCode;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendIn = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      _error = authErrorMessage(error);
      _errorField = error is AuthFailure ? error.field : null;
    });
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _errorField = null;
    });
    if (!_codeSent && !_emailForm.currentState!.validate()) return;
    try {
      final demo = await context.read<AuthSession>().requestPasswordReset(
        _email.text,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _demoCode = demo;
      });
      _startCooldown();
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _errorField = null;
    });
    setState(() => _submitted = true);
    if (!_resetForm.currentState!.validate()) return;
    try {
      await context.read<AuthSession>().resetPassword(
        _email.text,
        _code.text,
        _password.text,
      );
      if (mounted) context.go('/login?reset=1');
    } catch (error) {
      _fail(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final busy = session.busy;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AnimoraLogoAppBar(height: 72),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Theme(
                data: authFieldsTheme(Theme.of(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _codeSent
                              ? Icons.mark_email_read_outlined
                              : Icons.lock_reset,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _codeSent
                          ? 'Vérifiez vos e-mails'
                          : 'Mot de passe oublié ?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _codeSent
                          ? 'Si un compte existe pour ${_email.text.trim()}, '
                                'un code à 6 chiffres vient d’être envoyé. '
                                'Il est valable 10 minutes.'
                          : 'Saisissez l’adresse e-mail de votre compte. '
                                'Nous vous enverrons un code de réinitialisation.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 24),
                    if (!_codeSent)
                      Form(
                        key: _emailForm,
                        child: AppTextField(
                          key: const ValueKey('reset-email'),
                          label: 'Adresse e-mail',
                          controller: _email,
                          validator: FormValidators.email,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline,
                          enabled: !busy,
                          errorText: _errorField == 'email' ? _error : null,
                        ),
                      )
                    else
                      _resetFields(busy),
                    if (_error != null && _errorField == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 54,
                      child: AppButton(
                        label: _codeSent
                            ? 'Réinitialiser le mot de passe'
                            : 'Envoyer le code',
                        loading: busy,
                        onPressed: _codeSent ? _reset : _sendCode,
                      ),
                    ),
                    if (_codeSent)
                      TextButton(
                        onPressed: busy || _resendIn > 0 ? null : _sendCode,
                        child: Text(
                          _resendIn > 0
                              ? 'Renvoyer le code (${_resendIn}s)'
                              : 'Renvoyer le code',
                        ),
                      ),
                    TextButton(
                      onPressed: busy ? null : () => context.go('/login'),
                      child: const Text('Retour à la connexion'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resetFields(bool busy) => Form(
    key: _resetForm,
    autovalidateMode: _submitted
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_demoCode != null)
          Container(
            key: const ValueKey('reset-demo-code'),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Aucun e-mail envoyé : EmailJS n’est pas configuré '
              '(config/api-keys.json). Code de test : $_demoCode',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink),
            ),
          ),
        TextFormField(
          key: const ValueKey('reset-code'),
          controller: _code,
          enabled: !busy,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 10,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: 'Code à 6 chiffres',
            counterText: '',
            prefixIcon: const Icon(Icons.pin_outlined),
            errorText: _errorField == 'code' ? _error : null,
            errorMaxLines: 3,
          ),
          validator: (v) => v == null || v.length != 6
              ? 'Saisissez le code à 6 chiffres reçu par e-mail.'
              : null,
        ),
        const SizedBox(height: 16),
        AppTextField(
          key: const ValueKey('reset-password'),
          label: 'Nouveau mot de passe',
          controller: _password,
          validator: FormValidators.password,
          obscureText: _hidePassword,
          prefixIcon: Icons.lock_outline,
          enabled: !busy,
          errorText: _errorField == 'password' ? _error : null,
          suffixIcon: IconButton(
            tooltip: _hidePassword
                ? 'Afficher le mot de passe'
                : 'Masquer le mot de passe',
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
            icon: Icon(
              _hidePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
        PasswordRulesChecklist(controller: _password),
        AppTextField(
          key: const ValueKey('reset-confirmation'),
          label: 'Confirmer le mot de passe',
          controller: _confirmation,
          validator: (v) => FormValidators.confirmation(v, _password.text),
          obscureText: _hidePassword,
          prefixIcon: Icons.lock_reset_outlined,
          enabled: !busy,
        ),
      ],
    ),
  );
}
