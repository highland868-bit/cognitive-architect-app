// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is used deliberately: this project targets web only, and
// dart:html ships with the Dart SDK itself rather than needing a pub
// package fetch (see api_key_service.dart for the same reasoning).
import 'dart:html' as html;

/// Whether TTS should speak at all, and which of the OS's own voices to
/// use. Persisted the same way as the API key so the choice survives a
/// page reload.
class VoicePrefService {
  static const _enabledKey = 'voice_enabled';
  static const _voiceNameKey = 'voice_name';
  static const _voiceLocaleKey = 'voice_locale';

  static bool get() {
    final raw = html.window.localStorage[_enabledKey];
    return raw == null ? true : raw == 'true';
  }

  static void set(bool enabled) {
    html.window.localStorage[_enabledKey] = enabled.toString();
  }

  /// Returns {'name': ..., 'locale': ...} in the shape flutter_tts'
  /// setVoice expects, or null if the user hasn't picked one yet (OS
  /// default applies).
  static Map<String, String>? getSelectedVoice() {
    final name = html.window.localStorage[_voiceNameKey];
    final locale = html.window.localStorage[_voiceLocaleKey];
    if (name == null || locale == null) return null;
    return {'name': name, 'locale': locale};
  }

  static void setSelectedVoice(String name, String locale) {
    html.window.localStorage[_voiceNameKey] = name;
    html.window.localStorage[_voiceLocaleKey] = locale;
  }
}
