import 'dart:convert';

import 'package:animora/features/auth/models/auth_requests.dart';
import 'package:animora/features/auth/services/password_reset_mailer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

EmailCodeTicket _ticket({
  EmailCodePurpose purpose = EmailCodePurpose.verifyEmail,
}) => EmailCodeTicket(
  email: 'lina@example.test',
  firstName: 'Lina',
  code: '482913',
  expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
  purpose: purpose,
);

EmailJsPasswordResetMailer _mailer(MockClient client) =>
    EmailJsPasswordResetMailer(
      client: client,
      serviceId: 'service_test',
      templateId: 'template_test',
      publicKey: 'PUBLIC_test',
      privateKey: 'PRIVATE_test',
    );

Matcher _message(String part) => throwsA(
  isA<AuthFailure>().having((e) => e.message, 'message', contains(part)),
);

void main() {
  test('Request matches the EmailJS REST API', () async {
    late http.Request sent;
    await _mailer(
      MockClient((r) async {
        sent = r;
        return http.Response('OK', 200);
      }),
    ).send(_ticket());
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'https://api.emailjs.com/api/v1.0/email/send');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['service_id'], 'service_test');
    expect(body['template_id'], 'template_test');
    expect(body['user_id'], 'PUBLIC_test');
    expect(body['accessToken'], 'PRIVATE_test');
    final params = body['template_params'] as Map<String, dynamic>;
    for (final key in [
      'to_email',
      'to_name',
      'subject',
      'message',
      'code',
      'expires_minutes',
    ]) {
      expect(params[key], isA<String>(), reason: key);
    }
    expect(params['to_email'], 'lina@example.test');
    expect(params['code'], '482913');
    expect(params['subject'], contains('vérifiez'));
  });

  test('Missing keys: precise message, no HTTP call', () async {
    final mailer = EmailJsPasswordResetMailer(
      client: MockClient((_) async => fail('no request expected')),
      serviceId: '',
      templateId: '',
      publicKey: '',
    );
    expect(mailer.configured, isFalse);
    await expectLater(
      mailer.send(_ticket()),
      _message('Clés EmailJS absentes'),
    );
  });

  test('Each EmailJS error gets a precise French message', () async {
    final cases = {
      (403, 'API access from non-browser environments is currently disabled'):
          'non-browser',
      (400, 'The Public Key is invalid'): 'Clé publique',
      (403, 'The Private Key is invalid'): 'Clé privée',
      (400, 'The template ID is invalid'): 'Modèle EmailJS invalide',
      (400, 'The service ID is invalid'): 'Service EmailJS invalide',
      (422, 'The recipients address is empty'): '{{to_email}}',
      (429, 'Too Many Requests'): 'Limite',
      (503, 'Service Unavailable'): 'indisponible',
    };
    for (final MapEntry(key: (status, body), value: expected)
        in cases.entries) {
      await expectLater(
        _mailer(MockClient((_) async => http.Response(body, status)))
            .send(_ticket()),
        _message(expected),
        reason: body,
      );
    }
  });

  test('No network: precise message', () async {
    await expectLater(
      _mailer(MockClient((_) async => throw http.ClientException('offline')))
          .send(_ticket(purpose: EmailCodePurpose.resetPassword)),
      _message('Pas de connexion Internet'),
    );
  });

  test('Errors never expose the keys or the code', () async {
    try {
      await _mailer(
        MockClient(
          (_) async =>
              http.Response('bad PUBLIC_test PRIVATE_test 482913', 400),
        ),
      ).send(_ticket());
      fail('should throw');
    } on AuthFailure catch (e) {
      final text = '${e.message} ${e.diagnostic}';
      for (final secret in ['PUBLIC_test', 'PRIVATE_test', '482913']) {
        expect(text.contains(secret), isFalse, reason: secret);
      }
    }
  });
}
