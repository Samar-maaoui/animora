import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../state/auth_session.dart';

/// « Vérifiez votre e-mail » : 6-digit code input with resend.
/// Returns true once [onVerify] succeeded.
Future<bool> showEmailCodeDialog(
  BuildContext context, {
  required String email,
  required String? demoCode,
  required Future<void> Function(String code) onVerify,
  required Future<String?> Function() onResend,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmailCodeDialog(
        email: email,
        demoCode: demoCode,
        onVerify: onVerify,
        onResend: onResend,
      ),
    ) ??
    false;

class _EmailCodeDialog extends StatefulWidget {
  const _EmailCodeDialog({
    required this.email,
    required this.demoCode,
    required this.onVerify,
    required this.onResend,
  });
  final String email;
  final String? demoCode;
  final Future<void> Function(String code) onVerify;
  final Future<String?> Function() onResend;
  @override
  State<_EmailCodeDialog> createState() => _EmailCodeDialogState();
}

class _EmailCodeDialogState extends State<_EmailCodeDialog> {
  final _code = TextEditingController();
  late String? _demoCode = widget.demoCode;
  String? _error;
  bool _busy = false;
  int _resendIn = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    _resendIn = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Saisissez les 6 chiffres reçus par e-mail.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onVerify(_code.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final demo = await widget.onResend();
      if (!mounted) return;
      setState(() {
        _demoCode = demo;
        _code.clear();
      });
      _startCooldown();
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    icon: Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.mark_email_unread_outlined,
        color: AppColors.primary,
        size: 32,
      ),
    ),
    title: const Text('Vérifiez votre e-mail', textAlign: TextAlign.center),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Un code à 6 chiffres a été envoyé à\n${widget.email}\n'
          'Il est valable 10 minutes.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (_demoCode != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('verify-demo-code'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Aucun e-mail envoyé : EmailJS n’est pas configuré (config/api-keys.json). Code de test : $_demoCode',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.ink),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('verify-code'),
          controller: _code,
          enabled: !_busy,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _verify(),
          style: const TextStyle(
            fontSize: 26,
            letterSpacing: 12,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            errorText: _error,
            errorMaxLines: 3,
          ),
        ),
        TextButton(
          onPressed: _busy || _resendIn > 0 ? null : _resend,
          child: Text(
            _resendIn > 0
                ? 'Renvoyer le code (${_resendIn}s)'
                : 'Renvoyer le code',
          ),
        ),
      ],
    ),
    actionsAlignment: MainAxisAlignment.spaceBetween,
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context, false),
        child: const Text('Modifier mes infos'),
      ),
      FilledButton(
        key: const ValueKey('verify-submit'),
        onPressed: _busy ? null : _verify,
        child: _busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Vérifier'),
      ),
    ],
  );
}
