import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

/// First screen for visitors (no session): big title, pet picture and a
/// « Commencer » pill button leading to the sign-in screen.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  /// Optional transparent cut-out (like the mock-up). Falls back to the
  /// bundled cat photo when the file is not provided.
  static const cutoutAsset = 'assets/images/welcome_cat.png';
  static const photoAsset = 'assets/images/animals/cat.jpg';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 640;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 20, 0),
                  child: _Title(compact: compact),
                ),
                const Expanded(child: _PetPicture()),
                const _BottomPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: compact ? 32 : 38,
      height: 1.1,
      fontWeight: FontWeight.bold,
      color: AppColors.ink,
    );
    return Stack(
      children: [
        Semantics(
          header: true,
          label: 'Trouvez votre compagnon idéal',
          child: ExcludeSemantics(
            // Scales down on narrow phones instead of overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trouvez votre', style: style),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('compagnon', style: style),
                      const SizedBox(width: 10),
                      const _PetPill(),
                    ],
                  ),
                  Text('idéal', style: style),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 4,
          child: Transform.rotate(
            angle: -0.35,
            child: Icon(
              Icons.pets,
              size: compact ? 34 : 44,
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small rounded picture next to the title, like the mock-up.
class _PetPill extends StatelessWidget {
  const _PetPill();

  @override
  Widget build(BuildContext context) => Container(
    width: 78,
    height: 40,
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(22),
      image: const DecorationImage(
        image: AssetImage(WelcomeScreen.photoAsset),
        fit: BoxFit.cover,
        alignment: Alignment(0, -0.4),
      ),
    ),
  );
}

class _PetPicture extends StatelessWidget {
  const _PetPicture();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Decorative paws scattered in the background.
        for (final (Alignment a, double size, double turns) in const [
          (Alignment(0.88, -0.85), 30.0, 0.08),
          (Alignment(-0.9, 0.1), 22.0, -0.1),
          (Alignment(0.92, 0.35), 18.0, 0.12),
        ])
          Align(
            alignment: a,
            child: RotationTransition(
              turns: AlwaysStoppedAnimation(turns),
              child: Icon(
                Icons.pets,
                size: size,
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
          ),
        // Soft orange halo behind the animal.
        Align(
          alignment: const Alignment(0, 0.4),
          child: FractionallySizedBox(
            widthFactor: 0.82,
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.28),
                      AppColors.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
          child: Image.asset(
            WelcomeScreen.cutoutAsset,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            errorBuilder: (context, error, stack) => _ArchPhoto(),
          ),
        ),
      ],
    ),
  );
}

/// Photo fallback: arch-shaped frame resting on the white panel.
class _ArchPhoto extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: AspectRatio(
      aspectRatio: 0.82,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(400)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33F7941D),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(400)),
          child: Image.asset(
            WelcomeScreen.photoAsset,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.2),
          ),
        ),
      ),
    ),
  );
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(28, 28, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Trouvez le compagnon\nqui vous ressemble',
            style: TextStyle(
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adoption, signalements, soins et bénévolat : '
            'tout pour le bien-être animal.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const _PageDots(),
              const Spacer(),
              _StartButton(onPressed: () => context.go('/login')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      children: [
        Container(
          width: 22,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        for (var i = 0; i < 2; i++)
          Container(
            margin: const EdgeInsets.only(left: 5),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.border,
              shape: BoxShape.circle,
            ),
          ),
      ],
    ),
  );
}

/// Orange pill with a black paw bubble on the left, as on the mock-up.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Commencer',
    child: Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        key: const ValueKey('welcome-start'),
        borderRadius: BorderRadius.circular(40),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 26, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pets, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const ExcludeSemantics(
                child: Text(
                  'Commencer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
