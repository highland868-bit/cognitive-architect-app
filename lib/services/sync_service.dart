// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is used deliberately: this project targets web only (see
// api_key_service.dart for the same reasoning).
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'conversation_log_service.dart';

/// Syncs conversation_log across devices via Firestore's REST API, using
/// plain HTTP (package:http, already a dependency) rather than the
/// firebase_core/cloud_firestore packages -- avoids both a new pub-package
/// fetch (see the pub-cache visibility bug noted elsewhere in this
/// project's history) and the npm/JS SDK, which doesn't apply here since
/// this isn't a JS project.
///
/// Auth is anonymous (no email/password screen) -- the Firestore rule
/// this project uses is `allow read, write: if request.auth != null`,
/// so any authenticated caller can read/write any doc in the collection.
/// The only real protection is that the document path is derived from a
/// passphrase only the user knows -- obscurity, not real access control.
/// Fine for a personal project, not for anything sensitive at scale.
class SyncService {
  // Firebase web config is meant to be public (unlike the Anthropic key --
  // see api_key_service.dart) -- security lives in Firestore rules, not
  // in hiding this.
  static const _apiKey = 'AIzaSyDNq1Ppa59kEQ_IDD2B74lCbtoHQINnI1w';
  static const _projectId = 'self-counselling-cdf75';

  static const _passphraseKey = 'sync_passphrase';
  static const _idTokenKey = 'sync_id_token';
  static const _refreshTokenKey = 'sync_refresh_token';

  static String? get passphrase => html.window.localStorage[_passphraseKey];

  static void setPassphrase(String value) {
    html.window.localStorage[_passphraseKey] = value.trim();
  }

  static void clearPassphrase() => html.window.localStorage.remove(_passphraseKey);

  static bool get isConfigured => (passphrase ?? '').isNotEmpty;

  /// Non-cryptographic (djb2) but non-trivially-reversible, and safe under
  /// dart2js's JS-number arithmetic (kept well under 2^53 at every step,
  /// unlike a 64-bit hash, which silently loses precision when compiled
  /// to JS). Good enough to obscure a Firestore doc path for this use
  /// case -- not a substitute for real auth.
  String _hash(String input) {
    var hash = 5381;
    for (final unit in input.codeUnits) {
      hash = ((hash * 33) + unit) & 0x7FFFFFFF;
    }
    return hash.toRadixString(36);
  }

  String get _docId => _hash(passphrase ?? '');

  /// Exposed so the settings screen can display it -- comparing this
  /// short code between two devices is a much faster way to confirm
  /// they're actually linked to the same cloud document than
  /// re-typing the passphrase and hoping it matched.
  String get docId => _docId;

  Uri get _docUri => Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/sync_conversation_log/$_docId',
      );

  Future<String> _signUpAnonymously() async {
    final resp = await http.post(
      Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey'),
      body: jsonEncode({'returnSecureToken': true}),
    );
    if (resp.statusCode != 200) {
      throw Exception('Sync sign-in failed: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    html.window.localStorage[_idTokenKey] = data['idToken'] as String;
    html.window.localStorage[_refreshTokenKey] = data['refreshToken'] as String;
    return data['idToken'] as String;
  }

  Future<String> _ensureAuth() async {
    final existing = html.window.localStorage[_idTokenKey];
    if (existing != null) return existing;
    return _signUpAnonymously();
  }

  Future<String> _refreshAuth() async {
    final refreshToken = html.window.localStorage[_refreshTokenKey];
    if (refreshToken == null) return _signUpAnonymously();
    final resp = await http.post(
      Uri.parse('https://securetoken.googleapis.com/v1/token?key=$_apiKey'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=$refreshToken',
    );
    if (resp.statusCode != 200) {
      html.window.localStorage.remove(_idTokenKey);
      html.window.localStorage.remove(_refreshTokenKey);
      return _signUpAnonymously();
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    html.window.localStorage[_idTokenKey] = data['id_token'] as String;
    html.window.localStorage[_refreshTokenKey] = data['refresh_token'] as String;
    return data['id_token'] as String;
  }

  /// Pushes the full local conversation log to Firestore as one document,
  /// overwriting whatever was there. Best-effort -- errors are swallowed
  /// so a flaky connection never blocks the app, which keeps working
  /// offline-first on local storage regardless.
  Future<void> push(List<ConversationEntry> entries) async {
    if (!isConfigured) return;
    try {
      final body = jsonEncode({
        'fields': {
          'data': {'stringValue': jsonEncode(entries.map((e) => e.toJson()).toList())},
          'updatedAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
        },
      });
      final token = await _ensureAuth();
      var resp = await http.patch(_docUri, headers: {'authorization': 'Bearer $token'}, body: body);
      if (resp.statusCode == 401) {
        final fresh = await _refreshAuth();
        resp = await http.patch(_docUri, headers: {'authorization': 'Bearer $fresh'}, body: body);
      }
    } catch (_) {
      // best-effort; local storage already has this data regardless
    }
  }

  /// Fetches the cloud copy, or null if nothing's been synced yet, sync
  /// isn't configured, or the request fails for any reason.
  Future<List<ConversationEntry>?> pull() async {
    if (!isConfigured) return null;
    try {
      final token = await _ensureAuth();
      var resp = await http.get(_docUri, headers: {'authorization': 'Bearer $token'});
      if (resp.statusCode == 401) {
        final fresh = await _refreshAuth();
        resp = await http.get(_docUri, headers: {'authorization': 'Bearer $fresh'});
      }
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = data['fields']?['data']?['stringValue'] as String?;
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ConversationEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }
}
