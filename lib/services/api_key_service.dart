// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is used deliberately: this project targets web only, and
// dart:html ships with the Dart SDK itself rather than needing a pub
// package fetch (see trait_log_service.dart for the same reasoning).
import 'dart:html' as html;

/// Stores the user's own Anthropic API key in this browser's localStorage,
/// entered once via ApiKeyScreen. Deliberately never compiled into the
/// build via --dart-define: this build is meant to be hosted publicly
/// (e.g. GitHub Pages), and on a free plan that hosting is always
/// publicly reachable by URL even from a private repo -- so the key must
/// live only in the user's own browser, never in the served files.
class ApiKeyService {
  static const _key = 'anthropic_api_key';

  static String? get() => html.window.localStorage[_key];

  static bool get hasKey => (get() ?? '').isNotEmpty;

  static void save(String key) {
    html.window.localStorage[_key] = key.trim();
  }

  static void clear() {
    html.window.localStorage.remove(_key);
  }
}
