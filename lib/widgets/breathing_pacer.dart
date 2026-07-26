import 'package:flutter/material.dart';

/// Native, deterministic breath pacer. Per the master plan: pacing must
/// never be driven by model-generated text timing. This widget owns the
/// actual inhale/hold/exhale counts, keyed off breath_pattern from the
/// agent response; the Lottie clip playing alongside it is mood, not the
/// timer.
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
    final isInhale = phase.label == 'Inhale';
    final isExhale = phase.label == 'Exhale';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double scale;
            if (isInhale) {
              scale = 0.6 + 0.4 * _controller.value;
            } else if (isExhale) {
              scale = 1.0 - 0.4 * _controller.value;
            } else {
              scale = 1.0; // hold
            }
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueGrey.withOpacity(0.4),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(phase.label, style: const TextStyle(fontSize: 20)),
      ],
    );
  }
}
