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
  // Only set for assistant entries from an actual model reply -- lets the
  // home screen restore the same avatar/breathing visual when switching
  // back into a topic, not just the words.
  final String? avatarState;
  final String? breathPattern;

  ConversationEntry({
    required this.timestamp,
    required this.role,
    required this.text,
    this.agent,
    this.avatarState,
    this.breathPattern,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'role': role,
        'text': text,
        'agent': agent,
        'avatar_state': avatarState,
        'breath_pattern': breathPattern,
      };

  factory ConversationEntry.fromJson(Map<String, dynamic> j) => ConversationEntry(
        timestamp: DateTime.parse(j['timestamp'] as String),
        role: j['role'] as String,
        text: j['text'] as String,
        agent: j['agent'] as String?,
        avatarState: j['avatar_state'] as String?,
        breathPattern: j['breath_pattern'] as String?,
      );
}

/// A user message paired with the reply that followed it (if any), tagged
/// with the agent that answered -- shared by the History viewer (grouping
/// by topic) and ClaudeService (loading a topic's prior turns as context
/// so picking an agent from the drawer can continue that thread).
class ConversationTurn {
  final ConversationEntry? user;
  final ConversationEntry? assistant;

  ConversationTurn({this.user, this.assistant});

  String? get agent => assistant?.agent;
  DateTime get timestamp => (assistant ?? user)!.timestamp;
}

class ConversationLogService {
  static const _key = 'conversation_log';

  /// How many past turns of a topic to replay as context when continuing
  /// it -- enough for real continuity without letting the request grow
  /// unbounded as a topic accumulates history over weeks.
  static const contextLimit = 8;

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

  /// Loads the most recent turns previously answered by [agent], oldest
  /// first, ready to hand to ClaudeService as conversation context.
  Future<List<ConversationTurn>> turnsForAgent(String agent) async {
    final turns = pairTurns(await readAll()).where((t) => t.agent == agent).toList();
    if (turns.length <= contextLimit) return turns;
    return turns.sublist(turns.length - contextLimit);
  }

  List<ConversationTurn> pairTurns(List<ConversationEntry> entries) {
    final turns = <ConversationTurn>[];
    var i = 0;
    while (i < entries.length) {
      final entry = entries[i];
      if (entry.role == 'user') {
        final next = i + 1 < entries.length ? entries[i + 1] : null;
        if (next != null && next.role == 'assistant') {
          turns.add(ConversationTurn(user: entry, assistant: next));
          i += 2;
        } else {
          turns.add(ConversationTurn(user: entry));
          i += 1;
        }
      } else {
        // Orphaned assistant entry (shouldn't normally happen) -- keep it
        // visible rather than silently dropping it.
        turns.add(ConversationTurn(assistant: entry));
        i += 1;
      }
    }
    return turns;
  }

  List<String> _readRaw() {
    final raw = html.window.localStorage[_key];
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }
}
