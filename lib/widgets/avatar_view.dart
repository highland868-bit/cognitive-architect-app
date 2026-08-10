import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Renders the model's avatar_state. BREATHING never reaches this widget --
/// home_screen routes that state to BreathingPacer directly, which plays
/// this same "Breathe Babo" clip alongside its own phase timer. Every
/// other state shows the clip too now, so the avatar looks the same
/// character throughout the app rather than switching to a separate
/// code-drawn shape outside of breathing exercises.
class AvatarView extends StatelessWidget {
  final String avatarState;

  const AvatarView({super.key, required this.avatarState});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 200,
      child: Lottie.asset('assets/animations/breathing.json', repeat: true, fit: BoxFit.contain),
    );
  }
}
