import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr/qr.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/navigation_app_bar.dart';
import '../../auth/state/auth_session.dart';
import '../services/member_card_payload.dart';
import '../widgets/user_details.dart';

export '../services/member_identity.dart' show memberNumber;

/// QR code image from QR Server (api.qrserver.com, free, no key). Only used
/// when no card URL is configured: QR Server receives the QR content.
Uri qrServerUrl(String data, {int size = 300}) =>
    Uri.https('api.qrserver.com', '/v1/create-qr-code/', {
      'size': '${size}x$size',
      'data': data,
      'margin': '8',
      'color': '1F1A17',
      'bgcolor': 'FFFFFF',
      'format': 'png',
    });

class MemberCardScreen extends StatelessWidget {
  const MemberCardScreen({
    super.key,
    this.baseUrl = memberCardBaseUrlFromConfig,
  });

  /// Injectable for tests (defaults to MEMBER_CARD_BASE_URL).
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthSession>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final webUrl = memberCardUrl(user, baseUrl: baseUrl);
    final qr = memberQrContent(user, baseUrl: baseUrl);
    return Scaffold(
      appBar: NavigationAppBar(title: const Text('Ma carte de membre')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                MemberCard(
                  data: MemberCardData.fromUser(user),
                  avatar: UserAvatar(user: user, radius: 38),
                  qr: MemberQr(content: qr, local: webUrl != null),
                ),
                const SizedBox(height: 16),
                Text(
                  webUrl != null
                      ? 'Scannez le QR avec l’appareil photo de n’importe quel téléphone : '
                            'la carte s’ouvre dans le navigateur. Il ne contient ni e-mail, '
                            'ni téléphone, ni identifiant interne.'
                      : 'Présentez cette carte lors des événements Animora. '
                            'Pour qu’un scan ouvre la carte dans un navigateur, '
                            'configurez MEMBER_CARD_BASE_URL.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                if (webUrl != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Voir la carte Web'),
                    onPressed: () =>
                        launchUrl(webUrl, mode: LaunchMode.externalApplication),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// QR of the card. [local] = drawn on the device (nothing sent anywhere);
/// otherwise QR Server, with a local drawing as offline fallback.
class MemberQr extends StatelessWidget {
  const MemberQr({super.key, required this.content, required this.local});
  final String content;
  final bool local;

  Widget _image(double size) => local
      ? CustomPaint(size: Size.square(size), painter: LocalQrPainter(content))
      : Image.network(
          qrServerUrl(content).toString(),
          key: const ValueKey('member-qr'),
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => CustomPaint(
            size: Size.square(size),
            painter: LocalQrPainter(content),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'QR code de la carte. Touchez pour l’agrandir.',
    child: GestureDetector(
      key: const ValueKey('member-qr-box'),
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(dimension: 280, child: _image(280)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Container(
        width: 124,
        height: 124,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _image(112),
        ),
      ),
    ),
  );
}

/// QR drawn locally with the `qr` package (no network).
class LocalQrPainter extends CustomPainter {
  LocalQrPainter(String data)
    : image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L),
      );
  final QrImage image;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final cell = size.shortestSide / (image.moduleCount + 4);
    final ink = Paint()
      ..color = AppColors.ink
      ..isAntiAlias = false;
    for (var row = 0; row < image.moduleCount; row++) {
      for (var col = 0; col < image.moduleCount; col++) {
        if (image.isDark(row, col)) {
          canvas.drawRect(
            Rect.fromLTWH((col + 2) * cell, (row + 2) * cell, cell, cell),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(LocalQrPainter old) => old.image != image;
}

/// The member card itself, built from PUBLIC data only.
class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.data,
    required this.avatar,
    this.qr,
  });
  final MemberCardData data;
  final Widget avatar;
  final Widget? qr;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        'Carte de membre Animora de ${data.fullName}, ${data.profile}, '
        '${data.status}, membre depuis le ${data.joinedOnLabel}, '
        'numéro ${data.memberNumber}${data.city.isEmpty ? '' : ', ${data.city}'}',
    child: Container(
      key: const ValueKey('member-card'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA940), AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40E07B00),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          for (final (Alignment a, double s) in const [
            (Alignment(1.1, -1.1), 120.0),
            (Alignment(-1.15, 1.2), 90.0),
          ])
            Align(
              alignment: a,
              child: Icon(
                Icons.pets,
                size: s,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pets, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Animora',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'CARTE DE MEMBRE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: avatar,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                data.profile,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 10,
                          children: [
                            _Field(
                              label: 'Membre depuis',
                              value: data.joinedOnLabel,
                            ),
                            _Field(
                              label: 'N° membre',
                              value: data.memberNumber,
                            ),
                            _Field(label: 'Statut', value: data.status),
                            if (data.city.isNotEmpty)
                              _Field(label: 'Ville', value: data.city),
                          ],
                        ),
                      ),
                      if (qr != null) ...[const SizedBox(width: 10), qr!],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    ],
  );
}
