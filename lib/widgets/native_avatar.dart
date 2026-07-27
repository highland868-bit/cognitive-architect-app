import 'package:flutter/material.dart';

/// The consistent, code-drawn avatar used for every state except BREATHING
/// (which uses the real "Breathe Babo" Lottie clip instead -- see
/// BreathingPacer). One widget, parameterized by mood, keeps every other
/// state visually part of the same system rather than separate assets.
class NativeAvatar extends StatefulWidget {
  final String avatarState;

  const NativeAvatar({super.key, required this.avatarState});

  @override
  State<NativeAvatar> createState() => _NativeAvatarState();
}

class _Mood {
  final Color color;
  final Duration pulseDuration;
  final double pulseDepth;
  final IconData? icon;
  const _Mood(this.color, this.pulseDuration, this.pulseDepth, this.icon);
}

// Matches the blue used in the "Breathe Babo" Lottie clip, so the
// BREATHING state and every native-drawn state read as one character.
const _brandBlue = Color(0xFF2E4EDD);

_Mood _moodFor(String avatarState) {
  switch (avatarState) {
    case 'THINKING':
      return const _Mood(_brandBlue, Duration(milliseconds: 1400), 0.06, Icons.more_horiz);
    case 'SPEAKING':
      return const _Mood(_brandBlue, Duration(milliseconds: 700), 0.10, Icons.graphic_eq);
    case 'REFLECTIVE':
    case 'GROUNDING':
      return const _Mood(Color(0xFF6B5B95), Duration(milliseconds: 2600), 0.05, null);
    case 'CRISIS':
      return const _Mood(Color(0xFFD98E3F), Duration(milliseconds: 2200), 0.04, Icons.favorite_border);
    case 'IDLE':
    default:
      return const _Mood(_brandBlue, Duration(milliseconds: 2200), 0.05, null);
  }
}

class _NativeAvatarState extends State<NativeAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _moodFor(widget.avatarState).pulseDuration)
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant NativeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarState != widget.avatarState) {
      _controller.duration = _moodFor(widget.avatarState).pulseDuration;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood = _moodFor(widget.avatarState);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 - mood.pulseDepth + (mood.pulseDepth * 2 * _controller.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mood.color,
              boxShadow: [
                BoxShadow(
                  color: mood.color.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: mood.icon == null ? null : Icon(mood.icon, color: Colors.white, size: 40),
          ),
        );
      },
    );
  }
}
