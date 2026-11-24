import 'package:flutter/material.dart';

/// Displays the original artwork unchanged. Never crop, recolor or redraw it.
class AnimoraLogo extends StatelessWidget {
  const AnimoraLogo({super.key, this.width = 420, this.height = 240});

  static const assetPath = 'assets/images/animora_logo.png';
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Animora — Application mobile de protection et d’adoption des animaux',
      // The original file is supplied by the owner; do not invent a replacement.
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: Text('Logo officiel à ajouter', textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}
