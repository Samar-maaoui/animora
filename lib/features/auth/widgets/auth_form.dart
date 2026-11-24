import '../../../core/widgets/celebration_confetti.dart';
import '../../../core/widgets/password_rules_checklist.dart';
import '../../../core/widgets/app_notification.dart';
import '../../users/widgets/country_picker.dart';
import '../../users/services/countries_api.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/animora_logo_app_bar.dart';
import '../models/auth_requests.dart';
import '../services/auth_diagnostics.dart';
import '../services/account_policy.dart';
import '../services/professional_card_reader.dart';
import '../../users/widgets/city_autocomplete_field.dart';
import '../state/auth_session.dart';
import '../../users/widgets/city_map_picker.dart';
import 'auth_visuals.dart';
import 'email_code_dialog.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    this.register = false,
    this.notice,
    this.celebrate = false,
    this.noticeIsPending = false,
  });

  /// Orange « waiting for an administrator » notice instead of green.
  final bool noticeIsPending;
  final bool register;

  /// Confetti rain (account just created after e-mail verification).
  final bool celebrate;
  final String? notice;
  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    for (final key in [
      'firstName',
      'lastName',
      'email',
      'phone',
      'city',
      'password',
      'confirmation',
      'professionalCard',
    ])
      key: TextEditingController(),
  };
  String _dial = '+216';
  UserProfile? _profile;
  bool _hidePassword = true, _hideConfirmation = true;

  /// Fields are only validated after the first submit attempt: tapping an
  /// empty field (focus, autofill, keyboard) must not paint it red.
  bool _submitted = false;
  String? _error, _errorField;
  String? _errorDiagnostic;

  bool _scanningCard = false;
  late final _cardReader = ProfessionalCardReader();

  /// Account enrolled for biometric login on this device (login mode only).
  String? _biometricEmail;
  TextEditingController _c(String key) => _controllers[key]!;

  @override
  void initState() {
    super.initState();
    if (!widget.register) _loadBiometricAccount();
  }

  Future<void> _loadBiometricAccount() async {
    try {
      final email = await context.read<AuthSession>().biometricAccount();
      if (mounted) setState(() => _biometricEmail = email);
    } catch (_) {
      // Optional feature: the password form still works.
    }
  }

  Future<void> _biometricLogin() async {
    setState(() {
      _error = null;
      _errorField = null;
      _errorDiagnostic = null;
    });
    try {
      final done = await context.read<AuthSession>().loginWithBiometrics();
      if (!done && mounted) {
        setState(
          () => _error =
              'Vérification annulée. Réessayez ou utilisez votre mot de passe.',
        );
      }
      // On success go_router redirects from the shared session.
    } catch (error) {
      if (mounted) {
        setState(() {
          final failure = error is AuthFailure
              ? error
              : unknownAuthFailure(error);
          _error = authErrorMessage(failure);
          _errorDiagnostic = failure.diagnostic;
        });
      }
    }
  }

  void _clearError(String _) {
    if (_error != null) {
      setState(() {
        _error = null;
        _errorField = null;
        _errorDiagnostic = null;
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _errorField = null;
      _errorDiagnostic = null;
    });
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    final session = context.read<AuthSession>();
    try {
      if (widget.register) {
        final request = RegisterRequest(
          firstName: _c('firstName').text,
          lastName: _c('lastName').text,
          email: _c('email').text,
          phone: internationalPhone(_c('phone').text, _dial),
          city: _c('city').text,
          password: _c('password').text,
          profile: _profile!,
          professionalCardNumber: _profile == UserProfile.veterinarian
              ? _c('professionalCard').text
              : null,
        );
        // 1. Validate + send the verification code by e-mail.
        final demoCode = await session.sendRegistrationCode(request);
        if (!mounted) return;
        // 2. The account is created only after the code is confirmed.
        final verified = await showEmailCodeDialog(
          context,
          email: request.email.trim().toLowerCase(),
          demoCode: demoCode,
          onVerify: (code) => session.registerWithEmailCode(request, code),
          onResend: () => session.sendRegistrationCode(request),
        );
        if (verified && mounted) {
          // Veterinarian, foster family, pet-sitter: the account exists but
          // stays PENDING until an administrator validates it.
          final needsApproval =
              AccountPolicy.initialStatus(request.profile) ==
              AccountStatus.pending;
          context.go(
            needsApproval
                ? '/login?awaiting=${request.profile.name}'
                : '/login?registered=1',
          );
        }
      } else {
        await session.login(_c('email').text, _c('password').text);
        // go_router reacts to the single shared session and selects the status screen.
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          final failure = error is AuthFailure
              ? error
              : unknownAuthFailure(error);
          _error = authErrorMessage(failure);
          _errorField = failure.field;
          _errorDiagnostic = failure.diagnostic;
        });
      }
    }
  }

  /// Photographs the professional card and reads its number (ML Kit OCR).
  Future<void> _scanCard() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Photographier la carte'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir une photo de la carte'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _scanningCard = true;
      _error = null;
      _errorField = null;
    });
    try {
      final number = await _cardReader.scan(source);
      if (number != null && mounted) {
        _c('professionalCard').text = number;
        AppNotification.info(
          context,
          'Numéro lu : $number. Vérifiez-le avant de valider.',
          title: 'Carte scannée',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(error);
          _errorField = error is AuthFailure ? error.field : null;
        });
      }
    } finally {
      if (mounted) setState(() => _scanningCard = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label,
    String? Function(String?) validator, {
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    IconData? icon,
  }) => AppTextField(
    key: ValueKey(key),
    label: label,
    controller: _c(key),
    validator: validator,
    keyboardType: keyboardType,
    obscureText: obscure,
    suffixIcon: suffix,
    prefixIcon: icon,
    errorText: _errorField == key ? _error : null,
    enabled: !context.read<AuthSession>().busy,
    onChanged: _clearError,
  );

  Widget _visibility({
    required bool hidden,
    required String what,
    required VoidCallback toggle,
    required bool busy,
  }) => IconButton(
    tooltip: hidden ? 'Afficher $what' : 'Masquer $what',
    onPressed: busy ? null : toggle,
    icon: Icon(
      hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final register = widget.register;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      // Official logo kept (group rule), compact so the pets header fits.
      appBar: AnimoraLogoAppBar(height: keyboardOpen ? 56 : 72),
      body: CelebrationConfetti(
        play: widget.celebrate,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (!keyboardOpen) const AuthPetsHeader(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Theme(
                        data: authFieldsTheme(Theme.of(context)),
                        child: Form(
                          key: _form,
                          autovalidateMode: _submitted
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AuthModeToggle(
                                register: register,
                                onChanged: session.busy
                                    ? null
                                    : (toRegister) => context.go(
                                        toRegister ? '/register' : '/login',
                                      ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                register
                                    ? 'Inscrivez-vous pour continuer'
                                    : 'Connectez-vous pour continuer',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 22),
                              if (widget.notice != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: widget.noticeIsPending
                                        ? AppColors.primaryLight
                                        : AppColors.greenLight,
                                    borderRadius: BorderRadius.circular(14),
                                    border: widget.noticeIsPending
                                        ? Border.all(color: AppColors.primary)
                                        : null,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (widget.noticeIsPending) ...[
                                        const Icon(
                                          Icons.hourglass_top_rounded,
                                          color: AppColors.primaryDark,
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: Text(
                                          widget.notice!,
                                          key: ValueKey(
                                            widget.noticeIsPending
                                                ? 'registration-pending'
                                                : 'registration-success',
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (register) ...[
                                _field(
                                  'firstName',
                                  'Prénom',
                                  FormValidators.requiredText,
                                  icon: Icons.person_outline,
                                ),
                                _field(
                                  'lastName',
                                  'Nom',
                                  FormValidators.requiredText,
                                  icon: Icons.badge_outlined,
                                ),
                              ],
                              _field(
                                'email',
                                'Adresse e-mail',
                                FormValidators.email,
                                keyboardType: TextInputType.emailAddress,
                                icon: Icons.mail_outline,
                              ),
                              if (register) ...[
                                CountryPicker(
                                  onDial: (v) => setState(() => _dial = v),
                                ),
                                const SizedBox(height: 8),
                                _field(
                                  'phone',
                                  'Téléphone',
                                  FormValidators.phone,
                                  keyboardType: TextInputType.phone,
                                  icon: Icons.phone_outlined,
                                ),
                                CityAutocompleteField(
                                  controller: _c('city'),
                                  validator: FormValidators.requiredText,
                                  prefixIcon: Icons.location_on_outlined,
                                  enabled: !session.busy,
                                  errorText: _errorField == 'city'
                                      ? _error
                                      : null,
                                  onChanged: _clearError,
                                ),
                                // OpenStreetMap: locates, drops a pin and
                                // fills the city automatically.
                                CityMapPicker(
                                  controller: _c('city'),
                                  enabled: !session.busy,
                                  onCity: _clearError,
                                ),
                              ],
                              _field(
                                'password',
                                'Mot de passe',
                                register
                                    ? FormValidators.password
                                    : FormValidators.requiredText,
                                obscure: _hidePassword,
                                icon: Icons.lock_outline,
                                suffix: _visibility(
                                  hidden: _hidePassword,
                                  what: 'le mot de passe',
                                  busy: session.busy,
                                  toggle: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                ),
                              ),
                              if (register)
                                PasswordRulesChecklist(
                                  controller: _c('password'),
                                ),
                              if (register) ...[
                                _field(
                                  'confirmation',
                                  'Confirmer le mot de passe',
                                  (value) => FormValidators.confirmation(
                                    value,
                                    _c('password').text,
                                  ),
                                  obscure: _hideConfirmation,
                                  icon: Icons.lock_reset_outlined,
                                  suffix: _visibility(
                                    hidden: _hideConfirmation,
                                    what: 'la confirmation',
                                    busy: session.busy,
                                    toggle: () => setState(
                                      () => _hideConfirmation =
                                          !_hideConfirmation,
                                    ),
                                  ),
                                ),
                                DropdownButtonFormField<UserProfile>(
                                  key: const ValueKey('profile'),
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Type de profil',
                                    prefixIcon: const Icon(Icons.pets_outlined),
                                    errorText: _errorField == 'profile'
                                        ? _error
                                        : null,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  items: [
                                    for (final profile
                                        in AccountPolicy.publicProfiles)
                                      DropdownMenuItem(
                                        value: profile,
                                        child: Text(profile.label),
                                      ),
                                  ],
                                  onChanged: session.busy
                                      ? null
                                      : (value) => setState(() {
                                          _profile = value;
                                          _error = null;
                                          _errorDiagnostic = null;
                                        }),
                                  validator: (value) => value == null
                                      ? 'Choisissez un profil.'
                                      : null,
                                ),
                                if (_profile == UserProfile.veterinarian) ...[
                                  const SizedBox(height: 16),
                                  _field(
                                    'professionalCard',
                                    'N° de carte professionnelle',
                                    FormValidators.professionalCard,
                                    icon: Icons.badge_outlined,
                                    suffix: !ProfessionalCardReader.available
                                        ? null
                                        : _scanningCard
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox.square(
                                              dimension: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : IconButton(
                                            key: const ValueKey('scan-card'),
                                            tooltip: 'Scanner la carte professionnelle',
                                            icon: const Icon(
                                              Icons.document_scanner_outlined,
                                            ),
                                            onPressed: session.busy
                                                ? null
                                                : _scanCard,
                                          ),
                                  ),
                                  Text(
                                    ProfessionalCardReader.available
                                        ? 'Touchez l’icône de scan : le numéro est lu automatiquement sur la photo de votre carte. L’administrateur le vérifie avant de valider le compte.'
                                        : 'Saisissez le numéro de votre carte professionnelle. L’administrateur le vérifie avant de valider le compte.',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                const Text(
                                  'Les comptes vétérinaire, famille d’accueil et pet-sitter nécessitent une validation.',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (!register)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    key: const ValueKey('forgot-password'),
                                    onPressed: session.busy
                                        ? null
                                        : () {
                                            final email = _c('email').text
                                                .trim();
                                            context.go(
                                              email.isEmpty
                                                  ? '/forgot-password'
                                                  : Uri(
                                                      path: '/forgot-password',
                                                      queryParameters: {
                                                        'email': email,
                                                      },
                                                    ).toString(),
                                            );
                                          },
                                    child: const Text('Mot de passe oublié ?'),
                                  ),
                                ),
                              if (_error != null && _errorField == null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_errorDiagnostic != null)
                                SelectableText(_errorDiagnostic!),
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 54,
                                child: AppButton(
                                  label: register
                                      ? 'Créer mon compte'
                                      : 'Se connecter',
                                  loading: session.busy,
                                  onPressed: _submit,
                                ),
                              ),
                              if (!register && _biometricEmail != null) ...[
                                const AuthDivider(
                                  label: 'ou connectez-vous avec',
                                ),
                                Center(
                                  child: Semantics(
                                    button: true,
                                    label:
                                        'Continuer avec la biométrie, $_biometricEmail',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: session.busy
                                          ? null
                                          : _biometricLogin,
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.fingerprint,
                                          size: 38,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _biometricEmail!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    register
                                        ? 'Déjà un compte ?'
                                        : 'Nouveau sur Animora ?',
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: session.busy
                                        ? null
                                        : () => context.go(
                                            register ? '/login' : '/register',
                                          ),
                                    child: Text(
                                      register
                                          ? 'Se connecter'
                                          : 'Créer un compte',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Version de développement · Comptes conservés uniquement sur cet appareil. Utilisez des données fictives.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
