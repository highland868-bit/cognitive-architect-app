import 'package:flutter/material.dart';
import '../services/conversation_log_service.dart';
import 'agent_drawer.dart';

/// Renders one topic's-worth-of-context turn as its user/assistant bubble
/// pair. Shared by HistoryScreen (every turn, grouped by topic) and
/// HomeScreen (the current topic's recent scrollback), so both look and
/// label agents identically.
class ConversationTurnTile extends StatelessWidget {
  const ConversationTurnTile({super.key, required this.turn});

  final ConversationTurn turn;

  static String labelFor(String? agent) {
    if (agent == null) return 'Agent';
    if (agent == 'SENTINEL') return 'Safety check-in';
    final match = agentOptions.where((a) => a.id == agent);
    return match.isNotEmpty ? match.first.label : agent;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (turn.user != null)
            ChatBubble(role: 'You', text: turn.user!.text, timestamp: turn.user!.timestamp, alignRight: true),
          if (turn.assistant != null)
            ChatBubble(
              role: labelFor(turn.assistant!.agent),
              text: turn.assistant!.text,
              timestamp: turn.assistant!.timestamp,
              alignRight: false,
            ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
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
            SelectableText(text),
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
