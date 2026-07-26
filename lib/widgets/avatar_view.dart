import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Maps the model's avatar_state onto one of the 4 Lottie files decided
/// in the master plan's LOTTIE ASSETS section. THINKING and SPEAKING
/// share character.json with IDLE -- the TTS audio itself signals
/// "speaking," so no separate clip is needed for that distinction.
class AvatarView extends StatelessWidget {
  final String avatarState;

  const AvatarView({super.key, required this.avatarState});

  String get _asset {
    switch (avatarState) {
      case 'BREATHING':
        return 'assets/animations/breathing.json';
      case 'REFLECTIVE':
      case 'GROUNDING':
        return 'assets/animations/reflective.json';
      case 'CRISIS':
        return 'assets/animations/crisis.json';
      case 'IDLE':
      case 'THINKING':
      case 'SPEAKING':
      default:
        return 'assets/animations/character.json';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(_asset, repeat: true);
  }
}
