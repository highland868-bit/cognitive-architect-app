// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is used deliberately: this project targets web only, and
// dart:html ships with the Dart SDK itself rather than needing a pub
// package fetch (see README/commit history for why that matters here).
import 'dart:convert';
import 'dart:html' as html;

/// One row of the persistent trait log. This is what turns "systematically
/// build four traits" from a slogan into something reviewable weekly or
/// monthly, per the master plan's v4 rationale for the trait_target/
/// log_entry fields.
class TraitLogEntry {
  final DateTime timestamp;
  final String agent;
  final String traitTarget;
  final String technique;
  final String logEntry;

  TraitLogEntry({
    required this.timestamp,
    required this.agent,
    required this.traitTarget,
    required this.technique,
    required this.logEntry,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'agent': agent,
        'trait_target': traitTarget,
        'technique': technique,
        'log_entry': logEntry,
      };

  factory TraitLogEntry.fromJson(Map<String, dynamic> j) => TraitLogEntry(
        timestamp: DateTime.parse(j['timestamp'] as String),
        agent: j['agent'] as String,
        traitTarget: j['trait_target'] as String,
        technique: j['technique'] as String,
        logEntry: j['log_entry'] as String,
      );
}

/// Appends one entry per turn to the browser's localStorage via dart:html --
/// this project targets web only (see README), and dart:html ships with the
/// Dart SDK itself rather than needing a separate pub package fetch.
/// No viewer UI yet (see README "Known gaps") -- this just makes sure the
/// data exists to build one on top of later.
class TraitLogService {
  static const _key = 'trait_log_entries';

  Future<void> append(TraitLogEntry entry) async {
    final entries = _readRaw();
    entries.add(jsonEncode(entry.toJson()));
    html.window.localStorage[_key] = jsonEncode(entries);
  }

  Future<List<TraitLogEntry>> readAll() async {
    return _readRaw()
        .map((e) => TraitLogEntry.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  List<String> _readRaw() {
    final raw = html.window.localStorage[_key];
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }
}
