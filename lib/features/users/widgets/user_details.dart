import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../models/user.dart';
import '../services/member_identity.dart';

/// Decodes a stored `data:image/...;base64,` photo; null if absent/invalid.
ImageProvider? profileImage(String? photo) {
  if (photo == null) return null;
  final comma = photo.indexOf(',');
  if (!photo.startsWith('data:image/') || comma < 0) return null;
  try {
    return MemoryImage(base64Decode(photo.substring(comma + 1)));
  } on FormatException {
    return null;
  }
}

/// Illustrated avatar from DiceBear (free, no key) for accounts without a
/// photo. The seed is the public member number: no name, e-mail or internal
/// id is sent. Kept short because the same URL goes into the member QR code.
Uri diceBearAvatarUrl(String seed, {int size = 128}) =>
    Uri.https('api.dicebear.com', '/9.x/thumbs/png', {
      'seed': seed,
      'size': '$size',
      'backgroundColor': 'ffe9d2',
      'shapeColor': 'f7941d',
    });

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 44,
    this.useDiceBear = true,
  });
  final User user;
  final double radius;

  /// Disable to always show initials (offline-only contexts, tests).
  final bool useDiceBear;

  Widget _initials(BuildContext context) => Center(
    child: Text(
      '${user.firstName.isEmpty ? '' : user.firstName[0]}${user.lastName.isEmpty ? '' : user.lastName[0]}',
      style:
          (radius >= 40
                  ? Theme.of(context).textTheme.headlineMedium
                  : Theme.of(context).textTheme.titleMedium)
              ?.copyWith(color: AppColors.primary),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final image = profileImage(user.photo);
    if (image != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryLight,
        backgroundImage: image,
      );
    }
    final pixels = (radius * 2 * MediaQuery.devicePixelRatioOf(context))
        .clamp(64, 256)
        .round();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: !useDiceBear
          ? _initials(context)
          : ClipOval(
              child: Image.network(
                diceBearAvatarUrl(
                  publicAvatarSeed(user),
                  size: pixels,
                ).toString(),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                semanticLabel: 'Avatar de ${user.fullName}',
                // Offline or blocked: fall back to the initials.
                errorBuilder: (context, error, stack) => _initials(context),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : _initials(context),
              ),
            ),
    );
  }
}

class UserDetails extends StatelessWidget {
  const UserDetails({super.key, required this.user, this.onAvatarTap});
  final User user;

  /// When set, the avatar gets a camera badge and becomes tappable.
  final VoidCallback? onAvatarTap;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (onAvatarTap == null)
        UserAvatar(user: user)
      else
        Semantics(
          button: true,
          label: 'Changer la photo de profil',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAvatarTap,
            child: Stack(
              children: [
                UserAvatar(user: user),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.primary,
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 20),
      Text(
        user.fullName,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('E-mail'),
              subtitle: Text(user.email),
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Téléphone'),
              subtitle: Text(user.phone ?? 'Non renseigné'),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Ville'),
              subtitle: Text(user.city),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Profil'),
              subtitle: Text(user.profile.label),
            ),
            if (user.professionalCardNumber != null)
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('N° carte professionnelle'),
                subtitle: Text(user.professionalCardNumber!),
              ),
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Statut'),
              subtitle: Text(user.status.label),
            ),
          ],
        ),
      ),
    ],
  );
}
