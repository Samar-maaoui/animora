abstract final class FormValidators {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty
      ? 'Ce champ est obligatoire.'
      : null;
  static String? email(String? value) {
    if (requiredText(value) != null) return 'L’e-mail est obligatoire.';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
        ? null
        : 'Saisissez une adresse e-mail valide.';
  }

  static String? phone(String? value) {
    if (requiredText(value) != null) return 'Le téléphone est obligatoire.';
    final normalized = value!.replaceAll(RegExp(r'[\s().-]'), '');
    return RegExp(r'^\+?[0-9]{8,15}$').hasMatch(normalized)
        ? null
        : 'Saisissez 8 à 15 chiffres, avec un + facultatif.';
  }

  static final passwordRules = <(String, bool Function(String))>[
    ('Au moins 8 caractères', (v) => v.length >= 8),
    ('Une majuscule (A-Z)', (v) => RegExp(r'[A-Z]').hasMatch(v)),
    ('Un chiffre (0-9)', (v) => RegExp(r'[0-9]').hasMatch(v)),
    ('Un symbole (!@#\$%…)', (v) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(v)),
  ];

  static String? password(String? value) {
    final v = value ?? '';
    final missing = [
      for (final (label, ok) in passwordRules)
        if (!ok(v)) label.toLowerCase(),
    ];
    return missing.isEmpty
        ? null
        : 'Mot de passe trop faible : il manque ${missing.join(', ')}.';
  }

  static String? newPassword(String? value, String currentPassword) {
    final error = password(value);
    if (error != null) return error;
    return value == currentPassword
        ? 'Le nouveau mot de passe doit être différent de l’ancien.'
        : null;
  }

  static String? confirmation(String? value, String password) =>
      value == password && value != null && value.isNotEmpty
      ? null
      : 'Les mots de passe doivent être identiques.';

  /// Veterinarian professional card / Order registration number:
  /// 3 to 20 letters, digits, « / » or « - », with at least 3 digits.
  static String? professionalCard(String? value) {
    if (requiredText(value) != null) {
      return 'Le numéro de carte professionnelle est obligatoire.';
    }
    final v = value!.trim().toUpperCase();
    return RegExp(r'^[A-Z0-9/-]{3,20}$').hasMatch(v) &&
            RegExp(r'[0-9]').allMatches(v).length >= 3
        ? null
        : 'Numéro invalide (3 à 20 caractères, au moins 3 chiffres).';
  }
}
