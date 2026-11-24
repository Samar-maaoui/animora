import 'dart:convert';

import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../models/user.dart';
import '../widgets/user_details.dart' show diceBearAvatarUrl;
import 'member_identity.dart' as identity;

/// Public data shown on a member card. It deliberately has NO e-mail,
/// phone, internal id, password, token or real photo.
class MemberCardData {
  const MemberCardData({
    required this.firstName,
    required this.lastName,
    required this.profile,
    required this.status,
    required this.memberNumber,
    required this.joinedOn,
    required this.city,
    required this.avatarUrl,
  });

  final String firstName, lastName, profile, status, memberNumber;

  /// Date only, `YYYY-MM-DD`.
  final String joinedOn;
  final String city;

  /// DiceBear avatar URL (https://api.dicebear.com/… only).
  final String avatarUrl;

  String get fullName => '$firstName $lastName'.trim();

  factory MemberCardData.fromUser(User user) {
    final d = user.createdAt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return MemberCardData(
      firstName: user.firstName,
      lastName: user.lastName,
      profile: user.profile.label,
      status: user.status.label,
      memberNumber: identity.memberNumber(user),
      joinedOn: '${d.year}-${two(d.month)}-${two(d.day)}',
      city: user.city,
      avatarUrl: diceBearAvatarUrl(identity.publicAvatarSeed(user)).toString(),
    );
  }

  /// `DD/MM/YYYY` for display.
  String get joinedOnLabel {
    final p = joinedOn.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : joinedOn;
  }

  /// Short keys keep the QR code small.
  Map<String, Object> toJson() => {
    'v': 1,
    'f': firstName,
    'l': lastName,
    'p': profile,
    's': status,
    'n': memberNumber,
    'd': joinedOn,
    'c': city,
    'a': avatarUrl,
  };

  /// JSON → UTF-8 → base64url without padding (safe in a URL fragment).
  String encode() =>
      base64Url.encode(utf8.encode(jsonEncode(toJson()))).replaceAll('=', '');

  static const _maxText = 80;
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _number = RegExp(r'^ANI-[0-9A-F]{8}$');

  /// Strict decoding of a payload produced by [encode]. Throws
  /// [FormatException] for anything else (tampered or foreign QR).
  static MemberCardData decode(String payload) {
    final Object? json;
    try {
      final padded = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      json = jsonDecode(utf8.decode(base64Url.decode(padded)));
    } catch (_) {
      throw const FormatException('Carte illisible.');
    }
    if (json is! Map || json['v'] != 1) {
      throw const FormatException('Format de carte inconnu.');
    }
    final map = json;
    String text(String key, {bool required = true}) {
      final value = map[key];
      if (value is! String ||
          value.length > _maxText ||
          (required && value.trim().isEmpty)) {
        throw FormatException('Champ « $key » invalide.');
      }
      return value.trim();
    }

    final avatar = map['a'];
    final data = MemberCardData(
      firstName: text('f'),
      lastName: text('l', required: false),
      profile: text('p'),
      status: text('s'),
      memberNumber: text('n'),
      joinedOn: text('d'),
      city: text('c', required: false),
      avatarUrl: avatar is String && isAllowedAvatarUrl(avatar) ? avatar : '',
    );
    if (!_number.hasMatch(data.memberNumber) ||
        !_date.hasMatch(data.joinedOn)) {
      throw const FormatException('Numéro ou date invalide.');
    }
    return data;
  }
}

/// Only DiceBear avatars may be displayed from a scanned card.
bool isAllowedAvatarUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'api.dicebear.com' &&
      url.length <= 300;
}

/// Base URL of the static card page (GitHub Pages / Netlify), read from
/// `MEMBER_CARD_BASE_URL` in config/api-keys.json. Empty → feature off.
const memberCardBaseUrlFromConfig = String.fromEnvironment(
  'MEMBER_CARD_BASE_URL',
);

/// `https://…/#<payload>` or null when no valid HTTPS base URL is set.
/// The fragment (after #) is never sent to the web server.
Uri? memberCardUrl(User user, {String baseUrl = memberCardBaseUrlFromConfig}) {
  final base = Uri.tryParse(baseUrl.trim());
  if (base == null || base.scheme != 'https' || base.host.isEmpty) return null;
  return base.replace(fragment: MemberCardData.fromUser(user).encode());
}

/// QR content: the card URL, or (without base URL) the previous short
/// identifier « ANIMORA|MEMBRE|ANI-XXXXXXXX ».
String memberQrContent(
  User user, {
  String baseUrl = memberCardBaseUrlFromConfig,
}) =>
    memberCardUrl(user, baseUrl: baseUrl)?.toString() ??
    'ANIMORA|MEMBRE|${identity.memberNumber(user)}';
