import 'dart:async';
import 'package:flutter/material.dart';
import '../models/agent_response.dart';
import '../services/claude_service.dart';
import '../services/conversation_log_service.dart';
import '../services/crisis_backstop.dart';
import '../services/sync_service.dart';
import '../services/tts_service.dart';
import '../services/trait_log_service.dart';
import '../services/voice_pref_service.dart';
import '../widgets/agent_drawer.dart';
import '../widgets/avatar_view.dart';
import '../widgets/breathing_pacer.dart';
import 'api_key_screen.dart';
import 'history_screen.dart';
import 'sync_settings_screen.dart';
import 'voice_settings_screen.dart';

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
  final _conversationLog = ConversationLogService();
  final _sync = SyncService();

  AgentResponse? _lastResponse;
  bool _loading = false;
  String? _crisisMessage;
  String? _lastUserText;
  DateTime? _lastTimestamp;
  String? _selectedAgent;
  bool _voiceEnabled = VoicePrefService.get();
  bool _syncing = false;

  String? get _displayText => _crisisMessage ?? _lastResponse?.responseText;

  String _formatTimestamp(DateTime t) {
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.month}/${local.day} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _syncOnStartup();
  }

  /// Pulls whatever the cloud has, merges it with what's already local
  /// (never destructive -- entries only ever combine, never overwrite),
  /// and pushes the merged result back so both devices converge. No-op
  /// if sync hasn't been set up. Best-effort: SyncService swallows its
  /// own errors, so this never blocks the app from working offline.
  Future<void> _syncOnStartup() async {
    final remote = await _sync.pull();
    if (remote == null) return;
    await _conversationLog.mergeWithRemote(remote);
    await _syncPush(); // routed through the same chain as post-turn pushes
  }

  // Chains pushes so they always complete in the order they were queued --
  // otherwise sending several messages quickly fires several background
  // pushes that can finish out of order, and an earlier one (with fewer
  // entries) landing last would leave the cloud copy smaller than what's
  // actually on this device.
  Future<void> _pushChain = Future.value();

  Future<void> _syncPush() {
    _pushChain = _pushChain.then((_) async {
      await _sync.push(await _conversationLog.readAll());
    });
    return _pushChain;
  }

  /// Manual pull-merge-push, since sync otherwise only pulls on app
  /// launch -- the other device's messages don't show up here until
  /// then. Also re-displays the current topic in case sync just brought
  /// in a newer exchange than what's on screen.
  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await _syncOnStartup();
      if (_selectedAgent != null) await _switchTopic(_selectedAgent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synced')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Switching topics shows that topic's own last exchange if it has one,
  /// rather than always resetting to idle -- otherwise every topic looked
  /// "gone" the moment you left it, even though it was safe in storage.
  Future<void> _switchTopic(String? agent) async {
    setState(() {
      _selectedAgent = agent;
      _lastResponse = null;
      _crisisMessage = null;
      _lastUserText = null;
      _lastTimestamp = null;
    });
    if (agent == null) return; // Auto mode: always a fresh check-in.

    final turns = await _conversationLog.turnsForAgent(agent);
    final lastTurn = turns.isEmpty ? null : turns.last;
    final lastReply = lastTurn?.assistant;
    if (lastReply == null) return;
    if (!mounted || _selectedAgent != agent) return; // user moved on already

    setState(() {
      _lastUserText = lastTurn?.user?.text;
      _lastTimestamp = lastTurn?.user?.timestamp ?? lastReply.timestamp;
      _lastResponse = AgentResponse(
        agent: agent,
        avatarState: lastReply.avatarState ?? 'IDLE',
        breathPattern: lastReply.breathPattern ?? 'none',
        technique: 'none',
        crisisFlag: false,
        traitTarget: 'none',
        responseText: lastReply.text,
        logEntry: '',
      );
    });
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    final sentAt = DateTime.now();

    await _conversationLog.append(
      ConversationEntry(timestamp: sentAt, role: 'user', text: input),
    );

    // Deterministic safety net runs first, independent of the model.
    if (CrisisBackstop.check(input)) {
      setState(() {
        _crisisMessage = CrisisBackstop.resourceMessage;
        _lastResponse = null;
        _lastUserText = input;
        _lastTimestamp = sentAt;
      });
      await _conversationLog.append(ConversationEntry(
        timestamp: DateTime.now(),
        role: 'assistant',
        text: CrisisBackstop.resourceMessage,
        agent: 'SENTINEL',
      ));
      unawaited(_syncPush());
      _controller.clear();
      return;
    }

    setState(() {
      _loading = true;
      _crisisMessage = null;
    });

    try {
      // Auto mode stays a fresh, read-the-moment check-in every time; a
      // deliberately chosen agent continues that topic's prior turns.
      final history = _selectedAgent == null
          ? const <ConversationTurn>[]
          : await _conversationLog.turnsForAgent(_selectedAgent!);
      final result = await _claude.send(input, forcedAgent: _selectedAgent, history: history);

      if (result.crisisFlag) {
        setState(() {
          _crisisMessage = CrisisBackstop.resourceMessage;
          _lastResponse = null;
          _lastUserText = input;
          _lastTimestamp = sentAt;
        });
        await _conversationLog.append(ConversationEntry(
          timestamp: DateTime.now(),
          role: 'assistant',
          text: CrisisBackstop.resourceMessage,
          agent: 'SENTINEL',
        ));
        unawaited(_syncPush());
      } else {
        setState(() {
          _lastResponse = result;
          _lastUserText = input;
          _lastTimestamp = sentAt;
        });
        // Keyed by the topic the user actually picked, when they picked
        // one -- not by whatever agent the model itself self-reported,
        // which the model doesn't always echo back exactly, and a
        // mismatch would silently break the next turn's history lookup
        // in ConversationLogService.turnsForAgent. Auto mode has no user
        // pick to anchor to, so it still uses the model's own routing.
        await _conversationLog.append(ConversationEntry(
          timestamp: DateTime.now(),
          role: 'assistant',
          text: result.responseText,
          agent: _selectedAgent ?? result.agent,
          avatarState: result.avatarState,
          breathPattern: result.breathPattern,
        ));
        await _traitLog.append(TraitLogEntry(
          timestamp: DateTime.now(),
          agent: result.agent,
          traitTarget: result.traitTarget,
          technique: result.technique,
          logEntry: result.logEntry,
        ));
        unawaited(_syncPush());
      }
      // Only clear the input once the message actually made it out --
      // on failure below, leave it in the box so the user can just hit
      // Send again instead of having to retype or copy it from history.
      _controller.clear();
    } catch (e) {
      setState(() {
        _crisisMessage = 'Something went wrong: $e';
        _lastUserText = input;
        _lastTimestamp = sentAt;
      });
    } finally {
      setState(() => _loading = false);
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
          Navigator.of(context).pop();
          _switchTopic(agent);
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
            icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: _voiceEnabled ? 'Voice on' : 'Voice off',
            onPressed: () {
              setState(() => _voiceEnabled = !_voiceEnabled);
              VoicePrefService.set(_voiceEnabled);
            },
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            tooltip: 'Choose voice',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VoiceSettingsScreen(tts: _tts),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Conversation history',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const HistoryScreen(),
              ));
            },
          ),
          GestureDetector(
            onLongPress: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SyncSettingsScreen(),
              ));
            },
            child: IconButton(
              icon: _syncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(SyncService.isConfigured ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined),
              tooltip: SyncService.isConfigured
                  ? 'Tap to sync now, hold to change passphrase'
                  : 'Set up sync across devices',
              onPressed: () {
                if (SyncService.isConfigured) {
                  _syncNow();
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SyncSettingsScreen(),
                  ));
                }
              },
            ),
          ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Centers short replies, but scrolls instead of
                  // overflowing once the avatar/breathing pacer plus
                  // response text is taller than the available space.
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_lastUserText != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SelectableText(
                                      _lastUserText!,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    if (_lastTimestamp != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _formatTimestamp(_lastTimestamp!),
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Theme.of(context).colorScheme.outline,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            _crisisMessage != null
                                ? Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: SelectableText(
                                      _crisisMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  )
                                : response == null
                                    ? const AvatarView(avatarState: 'IDLE')
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (response.avatarState == 'BREATHING')
                                              BreathingPacer(pattern: response.breathPattern)
                                            else
                                              AvatarView(avatarState: response.avatarState),
                                            const SizedBox(height: 16),
                                            SelectableText(response.responseText,
                                                textAlign: TextAlign.center),
                                          ],
                                        ),
                                      ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Manual tap rather than auto-play: iOS Safari only allows
            // speech synthesis triggered directly by a user gesture, and
            // the reply text above always arrives after an async network
            // call, which no longer counts as one.
            if (_voiceEnabled && _displayText != null)
              TextButton.icon(
                onPressed: () => _tts.speak(_displayText!),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
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
