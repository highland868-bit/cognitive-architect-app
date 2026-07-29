import 'package:flutter/material.dart';
import '../models/agent_response.dart';
import '../services/claude_service.dart';
import '../services/crisis_backstop.dart';
import '../services/tts_service.dart';
import '../services/trait_log_service.dart';
import '../widgets/agent_drawer.dart';
import '../widgets/avatar_view.dart';
import '../widgets/breathing_pacer.dart';
import 'api_key_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _claude = ClaudeService();
  final _tts = TtsService();
  final _traitLog = TraitLogService();

  AgentResponse? _lastResponse;
  bool _loading = false;
  String? _crisisMessage;
  String? _selectedAgent;

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    // Deterministic safety net runs first, independent of the model.
    if (CrisisBackstop.check(input)) {
      setState(() {
        _crisisMessage = CrisisBackstop.resourceMessage;
        _lastResponse = null;
      });
      await _tts.speak(CrisisBackstop.resourceMessage);
      _controller.clear();
      return;
    }

    setState(() {
      _loading = true;
      _crisisMessage = null;
    });

    try {
      final result = await _claude.send(input, forcedAgent: _selectedAgent);

      if (result.crisisFlag) {
        setState(() {
          _crisisMessage = CrisisBackstop.resourceMessage;
          _lastResponse = null;
        });
        await _tts.speak(CrisisBackstop.resourceMessage);
      } else {
        setState(() => _lastResponse = result);
        await _tts.speak(result.responseText);
        await _traitLog.append(TraitLogEntry(
          timestamp: DateTime.now(),
          agent: result.agent,
          traitTarget: result.traitTarget,
          technique: result.technique,
          logEntry: result.logEntry,
        ));
      }
    } catch (e) {
      setState(() => _crisisMessage = 'Something went wrong: $e');
    } finally {
      setState(() => _loading = false);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final response = _lastResponse;
    final modeLabel = _selectedAgent == null
        ? 'Auto'
        : agentOptions.firstWhere((a) => a.id == _selectedAgent).label;
    return Scaffold(
      drawer: AgentDrawer(
        selectedAgent: _selectedAgent,
        onSelect: (agent) {
          setState(() => _selectedAgent = agent);
          Navigator.of(context).pop();
        },
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cognitive Architect'),
            Text(
              'Mode: $modeLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Update API key',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ApiKeyScreen(onSaved: () => Navigator.of(context).pop()),
              ));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _crisisMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _crisisMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : response == null
                        ? const AvatarView(avatarState: 'IDLE')
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (response.avatarState == 'BREATHING')
                                BreathingPacer(pattern: response.breathPattern)
                              else
                                AvatarView(avatarState: response.avatarState),
                              const SizedBox(height: 16),
                              Text(response.responseText,
                                  textAlign: TextAlign.center),
                            ],
                          ),
              ),
            ),
            if (_loading) const CircularProgressIndicator(),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Journal entry or voice-note transcript...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
