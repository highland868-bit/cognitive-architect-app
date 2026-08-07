// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is used deliberately: this project targets web only, and
// dart:html ships with the Dart SDK itself rather than needing a pub
// package fetch (see api_key_service.dart for the same reasoning).
import 'dart:html' as html;

/// Whether TTS should speak at all. Persisted the same way as the API key
/// so the choice survives a page reload.
class VoicePrefService {
  static const _key = 'voice_enabled';

  static bool get() {
    final raw = html.window.localStorage[_key];
    return raw == null ? true : raw == 'true';
  }

  static void set(bool enabled) {
    html.window.localStorage[_key] = enabled.toString();
  }
}
