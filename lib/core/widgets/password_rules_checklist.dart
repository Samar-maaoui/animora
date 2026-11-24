import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../utils/form_validators.dart';

/// Live checklist under a « new password » field: each rule turns green
/// as soon as it is satisfied.
class PasswordRulesChecklist extends StatelessWidget {
  const PasswordRulesChecklist({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14, top: 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (label, ok) in FormValidators.passwordRules)
                _Rule(label: label, ok: ok(value.text)),
            ],
          ),
        ),
      );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.ok});
  final String label;
  final bool ok;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label : ${ok ? 'respecté' : 'manquant'}',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              key: ValueKey(ok),
              size: 16,
              color: ok ? AppColors.adoption : AppColors.muted,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: ok ? AppColors.ink : AppColors.muted,
                fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
