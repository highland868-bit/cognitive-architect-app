import 'package:flutter/material.dart';
import '../services/conversation_log_service.dart';
import '../widgets/agent_drawer.dart';
import '../widgets/conversation_turn_tile.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _log = ConversationLogService();
  late final Future<List<ConversationEntry>> _entries = _log.readAll();

  /// Groups turns by drawer topic, ordered by which topic was most
  /// recently active.
  List<MapEntry<String?, List<ConversationTurn>>> _groupByAgent(List<ConversationTurn> turns) {
    final groups = <String?, List<ConversationTurn>>{};
    for (final turn in turns) {
      groups.putIfAbsent(turn.agent, () => []).add(turn);
    }
    final result = groups.entries.toList()
      ..sort((a, b) {
        final aLatest = a.value.map((t) => t.timestamp).reduce((x, y) => x.isAfter(y) ? x : y);
        final bLatest = b.value.map((t) => t.timestamp).reduce((x, y) => x.isAfter(y) ? x : y);
        return bLatest.compareTo(aLatest);
      });
    return result;
  }

  String _groupLabel(String? agent) {
    if (agent == null) return 'Unsent / other';
    if (agent == 'SENTINEL') return 'Safety check-in';
    final match = agentOptions.where((a) => a.id == agent);
    return match.isNotEmpty ? match.first.label : agent;
  }

  IconData _groupIcon(String? agent) {
    if (agent == null) return Icons.help_outline;
    if (agent == 'SENTINEL') return Icons.shield_outlined;
    final match = agentOptions.where((a) => a.id == agent);
    return match.isNotEmpty ? match.first.icon : Icons.chat_bubble_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation History')),
      body: FutureBuilder<List<ConversationEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }
          final groups = _groupByAgent(_log.pairTurns(entries));
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final group = groups[i];
              return ExpansionTile(
                initiallyExpanded: i == 0,
                leading: Icon(_groupIcon(group.key)),
                title: Text(_groupLabel(group.key)),
                subtitle: Text(
                  '${group.value.length} exchange${group.value.length == 1 ? '' : 's'}',
                ),
                children: [
                  for (final turn in group.value.reversed) ConversationTurnTile(turn: turn),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

