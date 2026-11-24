import 'package:flutter/material.dart';

import 'animora_logo.dart';

/// A taller header reserves room for the complete image, including its subtitle.
class AnimoraLogoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AnimoraLogoAppBar({super.key, this.actions, this.height = 128});

  final List<Widget>? actions;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: preferredSize.height,
    centerTitle: true,
    title: Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: AnimoraLogo(height: height - 16),
    ),
    actions: actions,
  );
}
