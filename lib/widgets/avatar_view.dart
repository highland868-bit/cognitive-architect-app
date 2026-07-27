import 'package:flutter/material.dart';
import 'native_avatar.dart';

/// Renders the model's avatar_state. BREATHING never reaches this widget --
/// home_screen routes that state to BreathingPacer (the real "Breathe Babo"
/// Lottie clip) directly. Everything else is the native, code-drawn avatar.
class AvatarView extends StatelessWidget {
  final String avatarState;

  const AvatarView({super.key, required this.avatarState});

  @override
  Widget build(BuildContext context) {
    return NativeAvatar(avatarState: avatarState);
  }
}
