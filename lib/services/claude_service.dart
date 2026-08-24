import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/agent_response.dart';
import '../system_prompt.dart';
import 'api_key_service.dart';
import 'conversation_log_service.dart';

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
  /// [history], if given, is that topic's prior turns (oldest first) --
  /// replayed as real conversation context so picking an agent from the
  /// drawer continues that thread instead of starting fresh each time.
  /// Each assistant turn is replayed as its plain response_text, not the
  /// raw structured JSON it originally returned -- the model only needs
  /// the substance of what it said before, not its own past envelope.
  Future<AgentResponse> send(
    String userInput, {
    String? forcedAgent,
    List<ConversationTurn> history = const [],
  }) async {
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

    final messages = <Map<String, String>>[];
    for (final turn in history) {
      if (turn.user != null) {
        messages.add({'role': 'user', 'content': turn.user!.text});
      }
      if (turn.assistant != null) {
        messages.add({'role': 'assistant', 'content': turn.assistant!.text});
      }
    }
    messages.add({'role': 'user', 'content': messageContent});

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
        'messages': messages,
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
    return AgentResponse.fromJson(_parseAgentJson(text));
  }

  /// The system prompt demands "ONLY a valid JSON object, no surrounding
  /// prose" -- but the model occasionally breaks that contract anyway and
  /// answers in plain, empathetic prose instead (seen most on emotionally
  /// weighted input). A raw jsonDecode there used to crash the whole turn
  /// with a FormatException and lose the reply entirely. Recover instead:
  /// try strict JSON, then a JSON object embedded in surrounding text
  /// (e.g. wrapped in a markdown code fence), then fall back to using the
  /// model's own words directly as the response text.
  ///
  /// That prose fallback has a failure mode of its own, though: a reply
  /// that *was* attempting JSON but got cut off mid-object (network
  /// hiccup, truncation) also fails both parse attempts, and isn't
  /// prose -- it's a broken JSON fragment like `{"agent": "PSYCHE", "br`.
  /// Displaying that raw to the user is worse than a clear error, so text
  /// that starts with `{` and still doesn't parse is treated as a broken
  /// reply, not chattiness, and gets an honest placeholder instead.
  Map<String, dynamic> _parseAgentJson(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end > start) {
        final candidate = text.substring(start, end + 1);
        try {
          return jsonDecode(candidate) as Map<String, dynamic>;
        } catch (_) {
          // The dominant real cause, not just truncation: the model
          // routinely writes response_text as genuine multi-paragraph
          // prose with real newlines, instead of escaping them as \n
          // within the JSON string -- which is invalid JSON even though
          // the object is otherwise complete. Repair rather than give up.
          try {
            return jsonDecode(_escapeControlCharsInStrings(candidate)) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
      if (text.trim().startsWith('{')) {
        return {
          'response_text': "That reply didn't come through cleanly -- try sending it again.",
        };
      }
      return {'response_text': text.trim()};
    }
  }

  /// Escapes literal newline/tab/carriage-return characters that appear
  /// *inside a JSON string value* (illegal per the JSON spec) into their
  /// proper \n/\t/\r escape sequences, while leaving structural
  /// whitespace between tokens -- e.g. the model's own pretty-printed
  /// indentation outside strings -- untouched. Tracks string-boundary
  /// state char by char so it doesn't touch anything outside a string.
  String _escapeControlCharsInStrings(String text) {
    final buffer = StringBuffer();
    var inString = false;
    var escaped = false;
    for (final ch in text.split('')) {
      if (inString) {
        if (escaped) {
          buffer.write(ch);
          escaped = false;
        } else if (ch == r'\') {
          buffer.write(ch);
          escaped = true;
        } else if (ch == '"') {
          buffer.write(ch);
          inString = false;
        } else if (ch == '\n') {
          buffer.write(r'\n');
        } else if (ch == '\r') {
          buffer.write(r'\r');
        } else if (ch == '\t') {
          buffer.write(r'\t');
        } else {
          buffer.write(ch);
        }
      } else {
        if (ch == '"') inString = true;
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }
}
