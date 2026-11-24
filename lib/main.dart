import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/auth/services/password_reset_mailer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // Says whether the keys were received (--dart-define-from-file); never
    // prints the keys themselves.
    final mailer = EmailJsPasswordResetMailer();
    debugPrint(
      'EMAILJS configuré : ${mailer.configured ? 'oui' : 'NON (clés absentes)'}'
      ' · clé privée : ${mailer.privateKey.isEmpty ? 'absente' : 'présente'}',
    );
  }
  runApp(const AnimoraApp());
}
