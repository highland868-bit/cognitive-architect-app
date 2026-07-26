import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around the OS's own TTS engine (AVSpeechSynthesizer on
/// iOS, TextToSpeech on Android via flutter_tts) -- on-device, free, and
/// keeps journal-derived text from leaving the device for voice
/// synthesis, per the master plan's tech-stack decision.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  TtsService() {
    _tts.setSpeechRate(0.42); // slower, calmer pacing than the OS default
    _tts.setPitch(0.9);
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
