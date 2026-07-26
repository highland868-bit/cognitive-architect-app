import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Appends one entry per turn to local, on-device storage (SharedPreferences,
/// which backs onto localStorage on web and native prefs storage on
/// mobile/desktop -- chosen over path_provider/dart:io File so this works
/// on the web target, since browsers have no filesystem access).
/// No viewer UI yet (see README "Known gaps") -- this just makes sure the
/// data exists to build one on top of later.
class TraitLogService {
  static const _key = 'trait_log_entries';

  Future<void> append(TraitLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_key) ?? [];
    entries.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_key, entries);
  }

  Future<List<TraitLogEntry>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_key) ?? [];
    return entries
        .map((e) => TraitLogEntry.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }
}
