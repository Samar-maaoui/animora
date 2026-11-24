import '../../../core/widgets/app_notification.dart';
import '../../../core/widgets/guarded_form.dart';
import '../../../core/widgets/navigation_app_bar.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/models/auth_requests.dart';
import '../../auth/state/auth_session.dart';
import '../widgets/city_autocomplete_field.dart';
import '../widgets/city_map_picker.dart';
import '../widgets/locate_city_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _firstName, _lastName, _phone, _city;
  String? _error;
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthSession>().currentUser!;
    _firstName = TextEditingController(text: user.firstName);
    _lastName = TextEditingController(text: user.lastName);
    _phone = TextEditingController(text: user.phone);
    _city = TextEditingController(text: user.city);
  }

  @override
  void dispose() {
    for (final controller in [_firstName, _lastName, _phone, _city]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      await context.read<AuthSession>().updateProfile(
        ProfileUpdate(
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
          city: _city.text,
        ),
      );
      if (mounted) {
        AppNotification.success(context, 'Profil mis à jour.');
        GuardedForm.savedGo(context, '/profile');
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Modifier le profil')),
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
                    label: 'Prénom',
                    controller: _firstName,
                    validator: FormValidators.requiredText,
                    enabled: !session.busy,
                  ),
                  AppTextField(
                    label: 'Nom',
                    controller: _lastName,
                    validator: FormValidators.requiredText,
                    enabled: !session.busy,
                  ),
                  AppTextField(
                    label: 'Téléphone',
                    controller: _phone,
                    validator: FormValidators.phone,
                    keyboardType: TextInputType.phone,
                    enabled: !session.busy,
                  ),
                  CityAutocompleteField(
                    controller: _city,
                    validator: FormValidators.requiredText,
                    enabled: !session.busy,
                    suffixIcon: LocateCityButton(
                      controller: _city,
                      enabled: !session.busy,
                    ),
                  ),
                  // Map: touch to move the pin, see the place, use it.
                  CityMapPicker(
                    controller: _city,
                    enabled: !session.busy,
                    autoLocate: false,
                  ),
                  const Text(
                    'L’e-mail et le type de profil ne sont pas modifiables ici.',
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) Text(_error!),
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
