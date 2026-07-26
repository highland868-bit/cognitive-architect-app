import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const CognitiveArchitectApp());
}

class CognitiveArchitectApp extends StatelessWidget {
  const CognitiveArchitectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognitive Architect',
      theme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
