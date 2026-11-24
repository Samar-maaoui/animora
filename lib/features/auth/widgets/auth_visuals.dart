import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Dog + cat header of the sign-in / sign-up screens.
class AuthPetsHeader extends StatelessWidget {
  const AuthPetsHeader({super.key});

  static Widget _photo(String asset, double radius) => Container(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Color(0x22162A46),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: CircleAvatar(
      radius: radius + 5,
      backgroundColor: AppColors.surface,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryLight,
        backgroundImage: AssetImage(asset),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      height: 210,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryLight, AppColors.background],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative paws in the theme colour.
          for (final (Alignment a, double size, double turns) in const [
            (Alignment(-0.85, -0.55), 26.0, -0.08),
            (Alignment(0.88, -0.35), 22.0, 0.1),
            (Alignment(-0.7, 0.75), 18.0, 0.05),
            (Alignment(0.75, 0.8), 20.0, -0.1),
          ])
            Align(
              alignment: a,
              child: RotationTransition(
                turns: AlwaysStoppedAnimation(turns),
                child: Icon(
                  Icons.pets,
                  size: size,
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
            ),
          SizedBox(
            width: 230,
            height: 160,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  bottom: 6,
                  child: _photo('assets/images/animals/cat.jpg', 58),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _photo('assets/images/animals/dog.jpg', 70),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Pill switch « Connexion | Inscription » (each side is a route).
class AuthModeToggle extends StatelessWidget {
  const AuthModeToggle({
    super.key,
    required this.register,
    required this.onChanged,
  });
  final bool register;

  /// Receives true for "Inscription"; null disables the toggle.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget side(String label, bool isRegister) {
      final selected = register == isRegister;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: selected || onChanged == null
                ? null
                : () => onChanged!(isRegister),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: register ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Row(children: [side('Connexion', false), side('Inscription', true)]),
        ],
      ),
    );
  }
}

/// « ——— ou ——— » separator.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1.2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1.2)),
      ],
    ),
  );
}

/// Filled, borderless fields used only on the auth screens.
ThemeData authFieldsTheme(ThemeData base) {
  OutlineInputBorder border(Color color, [double width = 0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: width == 0
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
  return base.copyWith(
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: AppColors.fieldFill,
      prefixIconColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      disabledBorder: border(Colors.transparent),
      focusedBorder: border(AppColors.primary, 1.6),
      errorBorder: border(base.colorScheme.error, 1.2),
      focusedErrorBorder: border(base.colorScheme.error, 1.6),
    ),
  );
}
