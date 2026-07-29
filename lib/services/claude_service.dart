import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/agent_response.dart';
import '../system_prompt.dart';
import 'api_key_service.dart';

/// Calls the Claude API directly (not claude.ai) and parses the JSON
/// response into an AgentResponse. Reads the API key from ApiKeyService
/// (this browser's localStorage) rather than a compile-time --dart-define,
/// since this build is meant to be hosted publicly -- see ApiKeyService.
class ClaudeService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-5';

  /// [forcedAgent], if set (e.g. 'PRANA', 'SOCRATES'), is a hint from the
  /// agent-picker Drawer that the user deliberately chose that agent this
  /// turn. It's threaded into the user message rather than forking the
  /// system prompt, so there's still just one prompt to maintain -- and
  /// SENTINEL's crisis check (part of that one prompt, plus the separate
  /// deterministic CrisisBackstop that runs before this is ever called)
  /// still applies no matter what's picked.
  Future<AgentResponse> send(String userInput, {String? forcedAgent}) async {
    final apiKey = ApiKeyService.get();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('No API key saved. Set it from the key icon in the app bar.');
    }

    final messageContent = forcedAgent == null
        ? userInput
        : '[The user has explicitly chosen the $forcedAgent agent for this '
            'turn from a menu. Honor that choice and route directly to it, '
            'unless SENTINEL crisis criteria are met, in which case SENTINEL '
            'still takes priority as usual.]\n\n$userInput';

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        'system': cognitiveArchitectSystemPrompt,
        'messages': [
          {'role': 'user', 'content': messageContent}
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Claude API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>;
    final textBlock = content.firstWhere(
      (block) => block['type'] == 'text',
      orElse: () => throw Exception(
        'No text block in Claude response: ${response.body}',
      ),
    );
    final text = textBlock['text'] as String;
    final parsed = jsonDecode(text) as Map<String, dynamic>;
    return AgentResponse.fromJson(parsed);
  }
}
