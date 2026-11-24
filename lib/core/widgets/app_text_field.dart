import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.controller,
    this.validator,
    this.suffixIcon,
    this.prefixIcon,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.autofillHints,
  });
  final String label;
  final bool obscureText, enabled;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;

  /// Optional leading icon (null keeps the previous look on other screens).
  final IconData? prefixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      onChanged: onChanged,
      autofillHints: autofillHints,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autocorrect: !obscureText && keyboardType != TextInputType.emailAddress,
      enableSuggestions: !obscureText,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        errorText: errorText,
        errorMaxLines: 3,
      ),
    ),
  );
}
