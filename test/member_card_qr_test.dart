import 'dart:convert';

import 'package:animora/core/enums/account_status.dart';
import 'package:animora/core/enums/user_profile.dart';
import 'package:animora/features/users/models/user.dart';
import 'package:animora/features/users/services/member_card_payload.dart';
import 'package:animora/features/users/services/member_identity.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = 'https://exemple.github.io/animora-carte/';

final _user = User(
  id: 'f3a9c2e17b4d4e0a',
  firstName: 'Inès',
  lastName: 'Ben Ammar',
  email: 'ines.secret@example.test',
  phone: '+216 98 765 432',
  photo: 'data:image/png;base64,AAAA',
  city: 'Sousse',
  profile: UserProfile.veterinarian,
  status: AccountStatus.active,
  createdAt: DateTime.utc(2026, 3, 4, 15),
  professionalCardNumber: 'CNOV-4521',
);

void main() {
  group('Payload', () {
    test('encode → decode round trip, accents included', () {
      final data = MemberCardData.fromUser(_user);
      final back = MemberCardData.decode(data.encode());
      expect(back.firstName, 'Inès');
      expect(back.lastName, 'Ben Ammar');
      expect(back.profile, 'Vétérinaire');
      expect(back.status, 'Actif');
      expect(back.memberNumber, memberNumber(_user));
      expect(back.joinedOn, '2026-03-04');
      expect(back.joinedOnLabel, '04/03/2026');
      expect(back.city, 'Sousse');
      expect(back.avatarUrl, startsWith('https://api.dicebear.com/'));
    });

    test('base64url without padding (safe in a URL fragment)', () {
      final encoded = MemberCardData.fromUser(_user).encode();
      expect(encoded, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('tampered or foreign payloads are rejected', () {
      expect(
        () => MemberCardData.decode('pas-du-base64!!'),
        throwsFormatException,
      );
      String enc(Map<String, Object> m) =>
          base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
      final good = MemberCardData.fromUser(_user).toJson();
      expect(
        () => MemberCardData.decode(enc({...good, 'v': 2})),
        throwsFormatException,
      );
      expect(
        () => MemberCardData.decode(enc({...good, 'n': '42'})),
        throwsFormatException,
      );
      expect(
        () => MemberCardData.decode(enc({...good, 'f': 'x' * 200})),
        throwsFormatException,
      );
      // An avatar outside DiceBear is dropped, not displayed.
      final evil = MemberCardData.decode(
        enc({...good, 'a': 'https://tracker.example/pixel.png'}),
      );
      expect(evil.avatarUrl, isEmpty);
    });
  });

  group('URL du QR', () {
    test('no e-mail, phone, internal id, photo or card number', () {
      final url = memberCardUrl(_user, baseUrl: _base)!.toString();
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(url.split('#').last)),
      );
      for (final secret in [
        _user.email,
        _user.phone!,
        '98 765',
        _user.id,
        _user.photo!,
        'CNOV-4521',
        'password',
        'token',
      ]) {
        expect(url.contains(secret), isFalse, reason: secret);
        expect(decoded.contains(secret), isFalse, reason: secret);
      }
    });

    test('data only in the fragment (never sent to the server)', () {
      final uri = memberCardUrl(_user, baseUrl: _base)!;
      expect(uri.scheme, 'https');
      expect(uri.host, 'exemple.github.io');
      expect(uri.path, '/animora-carte/');
      expect(uri.query, isEmpty);
      expect(uri.fragment, isNotEmpty);
    });

    test('fallback without MEMBER_CARD_BASE_URL (or non-HTTPS)', () {
      for (final base in ['', 'http://exemple.org/', 'pas une url']) {
        expect(memberCardUrl(_user, baseUrl: base), isNull, reason: base);
        expect(
          memberQrContent(_user, baseUrl: base),
          'ANIMORA|MEMBRE|${memberNumber(_user)}',
        );
      }
      expect(memberQrContent(_user, baseUrl: _base), startsWith(_base));
    });

    test('member number is a one-way fingerprint (stable, no id)', () {
      expect(memberNumber(_user), matches(RegExp(r'^ANI-[0-9A-F]{8}$')));
      expect(memberNumber(_user), memberNumber(_user));
      expect(memberNumber(_user).contains(_user.id.toUpperCase()), isFalse);
    });
  });
}
