import 'package:flutter_tts/flutter_tts.dart';
import 'voice_pref_service.dart';

/// Thin wrapper around the OS's own TTS engine (AVSpeechSynthesizer on
/// iOS, TextToSpeech on Android via flutter_tts) -- on-device, free, and
/// keeps journal-derived text from leaving the device for voice
/// synthesis, per the master plan's tech-stack decision.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  TtsService() {
    _tts.setSpeechRate(0.42); // slower, calmer pacing than the OS default
    _tts.setPitch(0.9);
    final saved = VoicePrefService.getSelectedVoice();
    if (saved != null) _tts.setVoice(saved);
  }

  /// The OS's own installed voices, e.g. iOS's downloadable
  /// Enhanced/Premium voices under Settings > Accessibility > Spoken
  /// Content -- each device has its own list, so this has to be queried
  /// live rather than hardcoded.
  Future<List<Map<String, String>>> getVoices() async {
    final raw = await _tts.getVoices;
    return (raw as List<dynamic>)
        .map((v) => (v as Map).map((k, val) => MapEntry(k.toString(), val.toString())))
        .toList();
  }

  Future<void> setVoice(String name, String locale) async {
    await _tts.setVoice({'name': name, 'locale': locale});
    VoicePrefService.setSelectedVoice(name, locale);
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
