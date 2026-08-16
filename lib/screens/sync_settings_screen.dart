import 'package:flutter/material.dart';
import '../services/conversation_log_service.dart';
import '../services/sync_service.dart';

/// Enter the same passphrase on every device to link them -- it's never
/// sent anywhere itself, only used locally to derive the (obscured, not
/// truly secret) Firestore document path this device reads and writes.
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final _controller = TextEditingController(text: SyncService.passphrase ?? '');
  final _sync = SyncService();
  final _log = ConversationLogService();
  bool _busy = false;
  String? _status;

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    SyncService.setPassphrase(value);
    try {
      final remote = await _sync.pull();
      final merged = remote == null ? await _log.readAll() : await _log.mergeWithRemote(remote);
      await _sync.push(merged);
      setState(() => _status = 'Linked. ${merged.length} messages synced.');
    } catch (e) {
      setState(() => _status = 'Saved locally, but sync failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync across devices')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the same passphrase on every device to link their chat '
              'history together. Anyone who has this exact phrase and knows '
              'where to look could read the linked data -- pick something '
              'only you would guess, not a real password you reuse.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Sync passphrase',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save & sync now'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!),
            ],
          ],
        ),
      ),
    );
  }
}
