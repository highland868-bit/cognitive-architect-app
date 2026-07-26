import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

/// Appends one line of JSON per turn to a local file, on-device only.
/// No viewer UI yet (see README "Known gaps") -- this just makes sure the
/// data exists to build one on top of later.
class TraitLogService {
  Future<File> _logFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/trait_log.jsonl');
  }

  Future<void> append(TraitLogEntry entry) async {
    final file = await _logFile();
    await file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<List<TraitLogEntry>> readAll() async {
    final file = await _logFile();
    if (!await file.exists()) return [];
    final lines = await file.readAsLines();
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => TraitLogEntry.fromJson(
            jsonDecode(l) as Map<String, dynamic>))
        .toList();
  }
}
