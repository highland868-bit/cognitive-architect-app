import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_key_service.dart';

/// Entry point (first-run, or later editing) for the user's own Anthropic
/// API key. Saved only to this browser's localStorage -- see
/// ApiKeyService for why this must never be compiled into the build.
class ApiKeyScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const ApiKeyScreen({super.key, required this.onSaved});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _controller = TextEditingController(text: ApiKeyService.get() ?? '');
  bool _obscure = true;

  void _save() {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    ApiKeyService.save(key);
    widget.onSaved();
  }

  // iOS Safari's native long-press-to-paste gesture is unreliable over
  // Flutter web's canvas-rendered text fields, so this reads the clipboard
  // directly via Flutter's own API as a reliable fallback.
  Future<void> _paste() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData('text/plain');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read clipboard -- try pasting manually instead.')),
        );
      }
      return;
    }
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    setState(() => _controller.text = text.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set your Anthropic API key')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This app calls the Claude API directly from your browser. '
              'Your key is stored only in this browser\'s local storage -- '
              'it goes straight to Anthropic and is never part of the '
              'hosted files, so it stays private even though this page '
              'is publicly hosted.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'API key',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      tooltip: 'Paste',
                      onPressed: _paste,
                    ),
                    IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ],
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
