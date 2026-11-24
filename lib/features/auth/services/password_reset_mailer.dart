import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_requests.dart';

/// Sends the password reset code by e-mail.
abstract interface class PasswordResetMailer {
  /// False when no e-mail service is configured (development mode).
  bool get configured;

  Future<void> send(EmailCodeTicket ticket);
}

/// flutter run \
///   --dart-define=EMAILJS_SERVICE_ID=service_xxx \
///   --dart-define=EMAILJS_TEMPLATE_ID=template_xxx \
///   --dart-define=EMAILJS_PUBLIC_KEY=xxxx \
///   --dart-define=EMAILJS_PRIVATE_KEY=xxxx
/// ```
/// The EmailJS template receives `to_email`, `to_name`, `code`,
/// `expires_minutes`, `app_name`, `subject` and `message` (so one template
/// serves both sign-up verification and password reset).
/// `EMAILJS_VERIFY_TEMPLATE_ID` optionally selects another template for
/// the sign-up verification e-mail.
class EmailJsPasswordResetMailer implements PasswordResetMailer {
  EmailJsPasswordResetMailer({
    http.Client? client,
    this.serviceId = const String.fromEnvironment('EMAILJS_SERVICE_ID'),
    this.templateId = const String.fromEnvironment('EMAILJS_TEMPLATE_ID'),
    this.publicKey = const String.fromEnvironment('EMAILJS_PUBLIC_KEY'),
    this.privateKey = const String.fromEnvironment('EMAILJS_PRIVATE_KEY'),
    this.verifyTemplateId = const String.fromEnvironment(
      'EMAILJS_VERIFY_TEMPLATE_ID',
    ),
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  static final endpoint = Uri.parse(
    'https://api.emailjs.com/api/v1.0/email/send',
  );
  final http.Client _client;
  final String serviceId, templateId, publicKey, privateKey;
  final String verifyTemplateId;
  final Duration timeout;

  @override
  bool get configured =>
      serviceId.isNotEmpty && templateId.isNotEmpty && publicKey.isNotEmpty;

  @override
  Future<void> send(EmailCodeTicket ticket) async {
    final verify = ticket.purpose == EmailCodePurpose.verifyEmail;
    if (!configured) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Clés EmailJS absentes : lancez l’app avec --dart-define-from-file=config/api-keys.json.',
        diagnostic: 'MAIL_NOT_CONFIGURED',
      );
    }
    final minutes = ticket.expiresAt
        .difference(DateTime.now().toUtc())
        .inMinutes
        .clamp(1, 60);
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': serviceId,
              'template_id': verify && verifyTemplateId.isNotEmpty
                  ? verifyTemplateId
                  : templateId,
              'user_id': publicKey,
              if (privateKey.isNotEmpty) 'accessToken': privateKey,
              'template_params': {
                'to_email': ticket.email,
                'to_name': ticket.firstName,
                'code': ticket.code,
                'expires_minutes': '$minutes',
                'app_name': 'Animora',
                'subject': verify
                    ? 'Animora – vérifiez votre adresse e-mail'
                    : 'Animora – réinitialisation du mot de passe',
                'message': verify
                    ? 'Bienvenue sur Animora ! Saisissez ce code dans l’application pour confirmer votre adresse e-mail.'
                    : 'Vous avez demandé à réinitialiser votre mot de passe. Saisissez ce code dans l’application.',
              },
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      _debugLog('timeout');
      throw const AuthFailure(
        AuthFailureCode.storage,
        'EmailJS ne répond pas (délai dépassé). Vérifiez votre connexion et réessayez.',
        diagnostic: 'MAIL_TIMEOUT',
      );
    } catch (error) {
      _debugLog('réseau : ${error.runtimeType}');
      throw const AuthFailure(
        AuthFailureCode.storage,
        'Pas de connexion Internet : l’e-mail n’a pas pu être envoyé.',
        diagnostic: 'MAIL_NETWORK',
      );
    }
    if (response.statusCode != 200) {
      final detail = _sanitize(response.body, ticket);
      _debugLog('HTTP ${response.statusCode} : $detail');
      throw AuthFailure(
        AuthFailureCode.storage,
        emailJsErrorMessage(response.statusCode, response.body),
        diagnostic: 'MAIL_HTTP_${response.statusCode}',
      );
    }
    _debugLog('HTTP 200 : e-mail accepté par EmailJS');
  }

  /// Removes anything secret from an EmailJS answer before logging it.
  String _sanitize(String body, EmailCodeTicket ticket) {
    var out = body.length > 300 ? body.substring(0, 300) : body;
    for (final secret in [publicKey, privateKey, ticket.code, ticket.email]) {
      if (secret.isNotEmpty) out = out.replaceAll(secret, '***');
    }
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Debug builds only; never the keys nor the verification code.
  static void _debugLog(String message) {
    if (kDebugMode) debugPrint('EMAILJS $message');
  }
}

/// User-facing message for an EmailJS HTTP error (French, actionable).
String emailJsErrorMessage(int status, String body) {
  final b = body.toLowerCase();
  if (b.contains('non-browser')) {
    return 'EmailJS refuse les applications mobiles : activez « Allow EmailJS API '
        'for non-browser applications » (Account → Security) puis enregistrez.';
  }
  if (status >= 500) {
    return 'EmailJS est momentanément indisponible. Réessayez plus tard.';
  }
  if (status == 429) {
    return 'Limite d’envoi EmailJS atteinte. Réessayez dans quelques minutes.';
  }
  if (b.contains('public key') || b.contains('user_id')) {
    return 'Clé publique EmailJS invalide : vérifiez EMAILJS_PUBLIC_KEY.';
  }
  if (b.contains('private key') || b.contains('accesstoken')) {
    return 'Clé privée EmailJS invalide : vérifiez EMAILJS_PRIVATE_KEY.';
  }
  if (b.contains('template id') || b.contains('template_id')) {
    return 'Modèle EmailJS invalide : vérifiez EMAILJS_TEMPLATE_ID.';
  }
  if (b.contains('service id') ||
      b.contains('service_id') ||
      b.contains('gmail') ||
      b.contains('outlook')) {
    return 'Service EmailJS invalide ou déconnecté : vérifiez EMAILJS_SERVICE_ID '
        'et la connexion du service (Gmail…) dans EmailJS.';
  }
  if (b.contains('recipient')) {
    return 'Destinataire vide : dans le modèle EmailJS, « To Email » doit être {{to_email}}.';
  }
  if (status == 401 || status == 403) {
    return 'Accès refusé par EmailJS : vérifiez les clés et les options de sécurité du compte.';
  }
  return 'EmailJS a refusé l’envoi (erreur $status).';
}
