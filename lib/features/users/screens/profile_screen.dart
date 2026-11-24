import '../../../core/widgets/app_notification.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/navigation_app_bar.dart';
import '../../auth/state/auth_session.dart';
import '../services/profile_photo_picker.dart';
import '../widgets/user_details.dart';

enum _PhotoAction { camera, gallery, remove }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.photoPicker});

  /// Injectable for tests.
  final ProfilePhotoPicker? photoPicker;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _error;
  bool _biometricAvailable = false, _biometricEnabled = false;
  late final ProfilePhotoPicker _picker =
      widget.photoPicker ?? ProfilePhotoPicker();

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final session = context.read<AuthSession>();
    try {
      final available = await session.biometrics.isAvailable();
      final enabled =
          available && await session.biometricEnabledForCurrentUser();
      if (mounted) {
        setState(() {
          _biometricAvailable = available;
          _biometricEnabled = enabled;
        });
      }
    } catch (_) {
      // Biometrics are optional: the profile stays usable without them.
    }
  }

  Future<void> _guard(Future<void> Function() action, {String? success}) async {
    setState(() => _error = null);
    try {
      await action();
      if (success != null && mounted) {
        AppNotification.success(context, success);
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    }
  }

  Future<void> _changePhoto(bool hasPhoto) async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, _PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(context, _PhotoAction.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer la photo'),
                onTap: () => Navigator.pop(context, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final session = context.read<AuthSession>();
    await _guard(() async {
      if (action == _PhotoAction.remove) {
        await session.updateProfilePhoto(null);
        return;
      }
      final photo = await _picker.pick(
        action == _PhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      );
      if (photo != null) await session.updateProfilePhoto(photo);
    });
  }

  Future<void> _toggleBiometrics(bool enable) async {
    final session = context.read<AuthSession>();
    await _guard(
      () async {
        enable
            ? await session.enableBiometrics()
            : await session.disableBiometrics();
        if (mounted) setState(() => _biometricEnabled = enable);
      },
      success: enable
          ? 'Connexion biométrique activée sur cet appareil.'
          : 'Connexion biométrique désactivée.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final user = session.currentUser;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Mon profil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              UserDetails(
                user: user,
                onAvatarTap: session.busy
                    ? null
                    : () => _changePhoto(user.photo != null),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    if (_biometricAvailable)
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Connexion par empreinte / visage'),
                        subtitle: const Text(
                          'Se connecter sans mot de passe sur cet appareil.',
                        ),
                        value: _biometricEnabled,
                        onChanged: session.busy ? null : _toggleBiometrics,
                      ),
                    ListTile(
                      key: const ValueKey('member-card-tile'),
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Ma carte de membre'),
                      subtitle: const Text(
                        'Photo, profil, date d’inscription et QR code',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !session.busy,
                      onTap: () => context.push('/profile/card'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_outlined),
                      title: const Text('Changer le mot de passe'),
                      trailing: const Icon(Icons.chevron_right),
                      enabled: !session.busy,
                      onTap: () => context.push('/profile/password'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null)
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
                label: 'Modifier le profil',
                onPressed: session.busy
                    ? null
                    : () => context.push('/profile/edit'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: session.busy ? null : () => _guard(session.logout),
                child: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
