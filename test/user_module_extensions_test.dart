import 'dart:convert';

import 'package:animora/core/ml/on_device_vision.dart';
import 'package:animora/core/utils/form_validators.dart';
import 'package:animora/features/auth/data/demo_accounts.dart';
import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/repositories/local_auth_repository.dart';
import 'package:animora/features/auth/services/password_hasher.dart';
import 'package:animora/features/auth/services/password_reset_mailer.dart';
import 'package:animora/features/auth/services/professional_card_reader.dart';
import 'package:animora/features/auth/state/auth_session.dart';
import 'package:animora/features/users/services/city_search_api.dart';
import 'package:animora/features/users/services/profile_photo_picker.dart';
import 'package:animora/features/users/widgets/user_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_test_support.dart';

class _FakeVision implements OnDeviceVision {
  _FakeVision({this.faces});
  final int? faces;

  @override
  Future<int?> countFaces(String imagePath) async => faces;
  @override
  Future<String?> readText(String imagePath) async => null;
}

class _RecordingMailer implements PasswordResetMailer {
  final sent = <PasswordResetTicket>[];
  @override
  bool get configured => true;
  @override
  Future<void> send(PasswordResetTicket ticket) async => sent.add(ticket);
}

void main() {
  setUpAll(seedDatabase);
  final citizenEmail = DemoAccounts.users.first.email;

  group('Mot de passe oublié', () {
    test('unknown e-mail gets no code; known e-mail gets 6 digits', () async {
      final repo = await testRepository();
      addTearDown(repo.dispose);
      expect(await repo.createPasswordResetCode('nobody@example.test'), isNull);
      final ticket = await repo.createPasswordResetCode(' $citizenEmail ');
      expect(ticket, isNotNull);
      expect(ticket!.code, matches(RegExp(r'^\d{6}$')));
    });

    test(
      'correct code resets the password once; old one stops working',
      () async {
        final repo = await testRepository();
        addTearDown(repo.dispose);
        final ticket = (await repo.createPasswordResetCode(citizenEmail))!;
        await expectLater(
          repo.resetPasswordWithCode(
            citizenEmail,
            '000000' == ticket.code ? '111111' : '000000',
            'NouveauMdp2026!',
          ),
          throwsA(isA<AuthFailure>().having((e) => e.field, 'field', 'code')),
        );
        await repo.resetPasswordWithCode(
          citizenEmail,
          ticket.code,
          'NouveauMdp2026!',
        );
        expect(
          (await repo.login(citizenEmail, 'NouveauMdp2026!')).email,
          citizenEmail,
        );
        await repo.logout();
        await expectLater(
          repo.login(citizenEmail, DemoAccounts.password),
          throwsA(isA<AuthFailure>()),
        );
        // Single use.
        await expectLater(
          repo.resetPasswordWithCode(citizenEmail, ticket.code, 'Autre2026xx!'),
          throwsA(isA<AuthFailure>()),
        );
      },
    );

    test('code expires and too many wrong codes invalidate it', () async {
      var now = DateTime.utc(2026, 11, 10, 12);
      final repo = LocalAuthRepository(
        storage: MemoryAuthStorage(await seedDatabase()),
        hasher: const PasswordHasher(iterations: 10000),
        clock: () => now,
      );
      addTearDown(repo.dispose);
      await repo.initialize();
      final expired = (await repo.createPasswordResetCode(citizenEmail))!;
      now = now.add(const Duration(minutes: 11));
      await expectLater(
        repo.resetPasswordWithCode(citizenEmail, expired.code, 'Nouveau2026x!'),
        throwsA(isA<AuthFailure>()),
      );
      final ticket = (await repo.createPasswordResetCode(citizenEmail))!;
      final wrong = ticket.code == '999999' ? '888888' : '999999';
      for (var i = 0; i < LocalAuthRepository.maxResetAttempts; i++) {
        await expectLater(
          repo.resetPasswordWithCode(citizenEmail, wrong, 'Nouveau2026x!'),
          throwsA(isA<AuthFailure>()),
        );
      }
      await expectLater(
        repo.resetPasswordWithCode(citizenEmail, ticket.code, 'Nouveau2026x!'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('session sends the code through the configured mailer', () async {
      final repo = await testRepository();
      final mailer = _RecordingMailer();
      final session = AuthSession(repo, mailer: mailer);
      addTearDown(session.dispose);
      await session.initialize();
      expect(await session.requestPasswordReset(citizenEmail), isNull);
      expect(mailer.sent.single.email, citizenEmail);
      expect(await session.requestPasswordReset('x@example.test'), isNull);
      expect(mailer.sent, hasLength(1));
    });

    test('EmailJS mailer posts the template parameters', () async {
      late Map<String, dynamic> body;
      final mailer = EmailJsPasswordResetMailer(
        serviceId: 's',
        templateId: 't',
        publicKey: 'p',
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('OK', 200);
        }),
      );
      await mailer.send(
        PasswordResetTicket(
          email: 'a@b.tn',
          firstName: 'Amine',
          code: '123456',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        ),
      );
      expect(body['service_id'], 's');
      expect(body['template_params']['code'], '123456');
      expect(body['template_params']['to_email'], 'a@b.tn');
    });
  });

  group('Vérification e-mail à l’inscription', () {
    RegisterRequest req(String email) => RegisterRequest(
      firstName: 'Lina',
      lastName: 'Test',
      email: email,
      phone: '+216 20 555 666',
      city: 'Tunis',
      password: 'Secret2026!',
      profile: DemoAccounts.users.first.profile,
    );

    test('no account until the e-mailed code is confirmed', () async {
      final repo = await testRepository();
      addTearDown(repo.dispose);
      final ticket = await repo.createEmailVerificationCode(
        req('lina@example.test'),
      );
      expect(ticket.purpose, EmailCodePurpose.verifyEmail);
      await expectLater(
        repo.login('lina@example.test', 'Secret2026!'),
        throwsA(isA<AuthFailure>()),
      );
      final wrong = ticket.code == '000000' ? '111111' : '000000';
      await expectLater(
        repo.registerWithEmailCode(req('lina@example.test'), wrong),
        throwsA(isA<AuthFailure>().having((e) => e.field, 'field', 'code')),
      );
      final user = await repo.registerWithEmailCode(
        req('lina@example.test'),
        ticket.code,
      );
      expect(user.email, 'lina@example.test');
      expect(
        (await repo.login('lina@example.test', 'Secret2026!')).id,
        user.id,
      );
      await repo.logout();
      // A code cannot create a second account.
      await expectLater(
        repo.registerWithEmailCode(req('lina@example.test'), ticket.code),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('duplicate e-mail is refused before any code is sent', () async {
      final repo = await testRepository();
      addTearDown(repo.dispose);
      await expectLater(
        repo.createEmailVerificationCode(req(citizenEmail)),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.duplicateEmail,
          ),
        ),
      );
    });

    test('session e-mails the verification code', () async {
      final repo = await testRepository();
      final mailer = _RecordingMailer();
      final session = AuthSession(repo, mailer: mailer);
      addTearDown(session.dispose);
      await session.initialize();
      expect(
        await session.sendRegistrationCode(req('new@example.test')),
        isNull,
      );
      expect(mailer.sent.single.purpose, EmailCodePurpose.verifyEmail);
      await session.registerWithEmailCode(
        req('new@example.test'),
        mailer.sent.single.code,
      );
      expect(session.currentUser, isNull);
    });
  });

  group('ML Kit', () {
    test(
      'profile photo needs exactly one face; skipped when unavailable',
      () async {
        await ProfilePhotoPicker(vision: _FakeVision(faces: 1))
            .checkSingleFace('x');
        await ProfilePhotoPicker(vision: _FakeVision()).checkSingleFace('x');
        for (final faces in [0, 2]) {
          await expectLater(
            ProfilePhotoPicker(vision: _FakeVision(faces: faces))
                .checkSingleFace('x'),
            throwsA(isA<AuthFailure>()),
          );
        }
      },
    );

    test('OCR extraction finds the labelled card number', () {
      expect(
        extractProfessionalCardNumber(
          'RÉPUBLIQUE TUNISIENNE\nConseil de l’Ordre des Médecins Vétérinaires\n'
          'Dr Ali Ben Salah\nN° d’inscription : 2457\nDélivrée le 12/03/2021',
        ),
        '2457',
      );
      expect(
        extractProfessionalCardNumber('Matricule: VET-0189 Tunis'),
        'VET-0189',
      );
      expect(
        extractProfessionalCardNumber(
          'Carte professionnelle\n01/02/2020\nCNOV 55821',
        ),
        '55821',
      );
      expect(extractProfessionalCardNumber('Aucun chiffre ici'), isNull);
    });

    test('professional card validator', () {
      expect(FormValidators.professionalCard('2457'), isNull);
      expect(FormValidators.professionalCard('VET-0189'), isNull);
      expect(FormValidators.professionalCard(''), isNotNull);
      expect(FormValidators.professionalCard('AB'), isNotNull);
      expect(FormValidators.professionalCard('ABCDEF'), isNotNull);
    });

    test('veterinarian registration stores the card number', () async {
      final repo = await testRepository();
      addTearDown(repo.dispose);
      final request = RegisterRequest(
        firstName: 'Sana',
        lastName: 'Vet',
        email: 'sana.vet@example.test',
        phone: '+216 20 111 222',
        city: 'Sousse',
        password: 'Secret2026!',
        profile: DemoAccounts.users
            .firstWhere((u) => u.profile.name == 'veterinarian')
            .profile,
        professionalCardNumber: ' vet-2026-7 ',
      );
      final user = await repo.register(request);
      expect(user.professionalCardNumber, 'VET-2026-7');
    });
  });

  group('APIs gratuites', () {
    test('DiceBear avatar uses the opaque id, never the e-mail', () {
      final url = diceBearAvatarUrl('abc123');
      expect(url.host, 'api.dicebear.com');
      expect(url.queryParameters['seed'], 'abc123');
    });

    test('Photon suggestions are parsed, deduplicated and cached', () async {
      var calls = 0;
      final api = CitySearchApi(
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'photon.komoot.io');
          expect(request.url.queryParameters['q'], 'Sou');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'features': [
                  for (var i = 0; i < 2; i++)
                    {
                      'properties': {
                        'name': 'Sousse',
                        'state': 'Gouvernorat de Sousse',
                        'country': 'Tunisie',
                      },
                    },
                ],
              }),
            ),
            200,
          );
        }),
      );
      final results = await api.search('Sou');
      expect(results.single.name, 'Sousse');
      expect(results.single.details, 'Gouvernorat de Sousse, Tunisie');
      await api.search('sou');
      expect(calls, 1);
      expect(await api.search('S'), isEmpty);
    });

    test('Photon failure returns no suggestion', () async {
      final api = CitySearchApi(
        client: MockClient((_) async => http.Response('down', 503)),
      );
      expect(await api.search('Tunis'), isEmpty);
    });
  });
}
