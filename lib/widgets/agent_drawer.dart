import 'package:flutter/material.dart';

/// The five agents from the master plan's DECISION ENGINE that a user can
/// deliberately pick, instead of always letting PSYCHE auto-route. SENTINEL
/// is deliberately excluded -- it's a background safety check that always
/// runs regardless of what's picked here, never a mode to select into.
class AgentOption {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  const AgentOption(this.id, this.label, this.description, this.icon);
}

const agentOptions = [
  AgentOption(
    'PSYCHE',
    'Check-in',
    'Not sure what you need -- read the moment and route from there',
    Icons.psychology_outlined,
  ),
  AgentOption(
    'PRANA',
    'Somatic Reset',
    'Breathing or grounding for acute stress, anger, overwhelm',
    Icons.air,
  ),
  AgentOption(
    'SOCRATES',
    'Challenge a Thought',
    'Test a distorted or catastrophizing thought (CBT)',
    Icons.help_outline,
  ),
  AgentOption(
    'DEFUSE',
    'Untangle a Loop',
    'Defuse a sticky or intrusive thought (ACT)',
    Icons.link_off,
  ),
  AgentOption(
    'MARCUS',
    'Stoic Reframe',
    'Re-anchor on what\'s actually in your control',
    Icons.balance,
  ),
];

/// Side menu for picking an agent. Selecting one is a hint threaded into
/// the same API call (see ClaudeService.send's forcedAgent parameter) --
/// there is still only one system prompt, not five.
class AgentDrawer extends StatelessWidget {
  final String? selectedAgent;
  final ValueChanged<String?> onSelect;

  const AgentDrawer({super.key, required this.selectedAgent, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('Choose an approach', style: TextStyle(fontSize: 20)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Auto'),
            subtitle: const Text('Let it read the moment and route for you'),
            selected: selectedAgent == null,
            onTap: () => onSelect(null),
          ),
          const Divider(height: 1),
          for (final option in agentOptions)
            ListTile(
              leading: Icon(option.icon),
              title: Text(option.label),
              subtitle: Text(option.description),
              selected: selectedAgent == option.id,
              onTap: () => onSelect(option.id),
            ),
        ],
      ),
    );
  }
}
