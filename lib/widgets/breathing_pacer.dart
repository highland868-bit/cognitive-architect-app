import 'package:flutter/material.dart';

/// Native, deterministic breath pacer. Per the master plan: pacing must
/// never be driven by model-generated text timing. This widget owns the
/// actual inhale/hold/exhale counts, keyed off breath_pattern from the
/// agent response, and shows only the phase label -- no avatar clip (see
/// home_screen.dart, which keeps the avatar to the opening screen only).
class BreathingPacer extends StatefulWidget {
  final String pattern; // '478' | '436' | 'box'

  const BreathingPacer({super.key, required this.pattern});

  @override
  State<BreathingPacer> createState() => _BreathingPacerState();
}

class _Phase {
  final String label;
  final int seconds;
  const _Phase(this.label, this.seconds);
}

class _BreathingPacerState extends State<BreathingPacer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _phaseIndex = 0;

  List<_Phase> get _phases {
    switch (widget.pattern) {
      case '478':
        return const [
          _Phase('Inhale', 4),
          _Phase('Hold', 7),
          _Phase('Exhale', 8),
        ];
      case '436':
        return const [
          _Phase('Inhale', 4),
          _Phase('Hold', 3),
          _Phase('Exhale', 6),
        ];
      case 'box':
      default:
        return const [
          _Phase('Inhale', 4),
          _Phase('Hold', 4),
          _Phase('Exhale', 4),
          _Phase('Hold', 4),
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _runPhase();
  }

  void _runPhase() {
    final phase = _phases[_phaseIndex];
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: phase.seconds),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _phaseIndex = (_phaseIndex + 1) % _phases.length);
        _controller.dispose();
        _runPhase();
      }
    });
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phases[_phaseIndex];
    return Text(phase.label, style: const TextStyle(fontSize: 20));
  }
}
