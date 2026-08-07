// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is used deliberately: this project targets web only, and
// dart:html ships with the Dart SDK itself rather than needing a pub
// package fetch (see trait_log_service.dart for the same reasoning).
import 'dart:convert';
import 'dart:html' as html;

/// One turn of the actual conversation -- what the user typed, or what an
/// agent replied. Separate from TraitLogService, which stores a structured
/// trait-tracking summary rather than the exchange itself. This is what
/// the history viewer screen reads.
class ConversationEntry {
  final DateTime timestamp;
  final String role; // 'user' or 'assistant'
  final String text;
  final String? agent; // which agent replied; null for user entries

  ConversationEntry({
    required this.timestamp,
    required this.role,
    required this.text,
    this.agent,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'role': role,
        'text': text,
        'agent': agent,
      };

  factory ConversationEntry.fromJson(Map<String, dynamic> j) => ConversationEntry(
        timestamp: DateTime.parse(j['timestamp'] as String),
        role: j['role'] as String,
        text: j['text'] as String,
        agent: j['agent'] as String?,
      );
}

class ConversationLogService {
  static const _key = 'conversation_log';

  Future<void> append(ConversationEntry entry) async {
    final entries = _readRaw();
    entries.add(jsonEncode(entry.toJson()));
    html.window.localStorage[_key] = jsonEncode(entries);
  }

  Future<List<ConversationEntry>> readAll() async {
    return _readRaw()
        .map((e) => ConversationEntry.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  List<String> _readRaw() {
    final raw = html.window.localStorage[_key];
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }
}
