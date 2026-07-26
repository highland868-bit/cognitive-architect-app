import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/agent_response.dart';
import '../system_prompt.dart';

/// Calls the Claude API directly (not claude.ai) and parses the JSON
/// response into an AgentResponse. Requires ANTHROPIC_API_KEY to be
/// passed at build/run time -- see README for --dart-define usage.
/// Never hardcode the key here.
class ClaudeService {
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-5';

  Future<AgentResponse> send(String userInput) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'ANTHROPIC_API_KEY not set. Run with '
        '--dart-define=ANTHROPIC_API_KEY=your_key',
      );
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'content-type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 1024,
        'system': cognitiveArchitectSystemPrompt,
        'messages': [
          {'role': 'user', 'content': userInput}
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
