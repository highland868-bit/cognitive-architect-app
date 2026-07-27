import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/api_key_screen.dart';
import 'services/api_key_service.dart';

void main() {
  runApp(const CognitiveArchitectApp());
}

class CognitiveArchitectApp extends StatefulWidget {
  const CognitiveArchitectApp({super.key});

  @override
  State<CognitiveArchitectApp> createState() => _CognitiveArchitectAppState();
}

class _CognitiveArchitectAppState extends State<CognitiveArchitectApp> {
  bool _hasKey = ApiKeyService.hasKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognitive Architect',
      theme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
      ),
      home: _hasKey
          ? const HomeScreen()
          : ApiKeyScreen(onSaved: () => setState(() => _hasKey = true)),
    );
  }
}
