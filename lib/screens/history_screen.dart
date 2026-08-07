import 'package:flutter/material.dart';
import '../services/conversation_log_service.dart';
import '../widgets/agent_drawer.dart';

/// One user message paired with the reply that followed it (if any),
/// tagged with the agent that actually answered -- this is what lets the
/// history screen group turns by drawer topic instead of one flat list.
class _Turn {
  final ConversationEntry user;
  final ConversationEntry? assistant;
  final String? agent;

  _Turn({required this.user, this.assistant, this.agent});

  DateTime get timestamp => (assistant ?? user).timestamp;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _log = ConversationLogService();
  late final Future<List<ConversationEntry>> _entries = _log.readAll();

  List<_Turn> _pairTurns(List<ConversationEntry> entries) {
    final turns = <_Turn>[];
    var i = 0;
    while (i < entries.length) {
      final entry = entries[i];
      if (entry.role == 'user') {
        final next = i + 1 < entries.length ? entries[i + 1] : null;
        if (next != null && next.role == 'assistant') {
          turns.add(_Turn(user: entry, assistant: next, agent: next.agent));
          i += 2;
        } else {
          turns.add(_Turn(user: entry));
          i += 1;
        }
      } else {
        // Orphaned assistant entry (shouldn't normally happen) -- keep it
        // visible rather than silently dropping it.
        turns.add(_Turn(user: entry, agent: entry.agent));
        i += 1;
      }
    }
    return turns;
  }

  /// Groups turns by drawer topic, ordered by which topic was most
  /// recently active.
  List<MapEntry<String?, List<_Turn>>> _groupByAgent(List<_Turn> turns) {
    final groups = <String?, List<_Turn>>{};
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
          final groups = _groupByAgent(_pairTurns(entries));
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
                  for (final turn in group.value.reversed) _TurnTile(turn: turn),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TurnTile extends StatelessWidget {
  const _TurnTile({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bubble(role: 'You', text: turn.user.text, timestamp: turn.user.timestamp, alignRight: true),
          if (turn.assistant != null)
            _Bubble(
              role: _labelFor(turn.assistant!.agent),
              text: turn.assistant!.text,
              timestamp: turn.assistant!.timestamp,
              alignRight: false,
            ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  String _labelFor(String? agent) {
    if (agent == null) return 'Agent';
    if (agent == 'SENTINEL') return 'Safety check-in';
    final match = agentOptions.where((a) => a.id == agent);
    return match.isNotEmpty ? match.first.label : agent;
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.role,
    required this.text,
    required this.timestamp,
    required this.alignRight,
  });

  final String role;
  final String text;
  final DateTime timestamp;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: alignRight ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(role, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(text),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.month}/${local.day} ${two(local.hour)}:${two(local.minute)}';
  }
}
