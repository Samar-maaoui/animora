import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/animora_logo.dart';
import '../../../core/widgets/app_button.dart';
import '../state/auth_session.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AnimoraLogo(height: 280),
                const SizedBox(height: 16),
                const Text(
                  'Un petit geste. Une vie qui change.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (session.initializationError == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Vérification de votre session…'),
                ] else ...[
                  Text(
                    session.initializationError!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (session.initializationDiagnostic != null)
                    SelectableText(
                      session.initializationDiagnostic!,
                      key: const ValueKey('auth-diagnostic'),
                    ),
                  AppButton(
                    label: 'Réessayer',
                    onPressed: session.retryInitialization,
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
