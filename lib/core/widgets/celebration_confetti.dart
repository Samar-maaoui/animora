import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Rain of confetti over [child] (local package, no network), played once
/// when [play] is true — e.g. right after the e-mail is verified.
class CelebrationConfetti extends StatefulWidget {
  const CelebrationConfetti({super.key, required this.child, this.play = true});
  final Widget child;
  final bool play;
  @override
  State<CelebrationConfetti> createState() => _CelebrationConfettiState();
}

class _CelebrationConfettiState extends State<CelebrationConfetti> {
  final _controller = ConfettiController(
    duration: const Duration(milliseconds: 2500),
  );

  /// The confetti layer is removed once the rain is over (frees the ticker).
  bool _finished = false;
  Timer? _cleanup;

  @override
  void initState() {
    super.initState();
    if (widget.play) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !MediaQuery.disableAnimationsOf(context)) {
          _controller.play();
          _cleanup = Timer(const Duration(seconds: 6), () {
            if (mounted) setState(() => _finished = true);
          });
        } else if (mounted) {
          setState(() => _finished = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _cleanup?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (widget.play && !_finished)
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _controller,
              blastDirectionality: BlastDirectionality.explosive,
              blastDirection: pi / 2,
              emissionFrequency: 0.06,
              numberOfParticles: 18,
              maxBlastForce: 22,
              minBlastForce: 8,
              gravity: 0.25,
              colors: const [
                AppColors.primary,
                AppColors.primaryDark,
                AppColors.adoption,
                AppColors.reports,
                AppColors.events,
                AppColors.donations,
                Color(0xFFFFD43B),
              ],
            ),
          ),
        ),
    ],
  );
}
