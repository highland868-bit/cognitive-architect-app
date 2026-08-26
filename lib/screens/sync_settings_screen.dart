import 'package:flutter/material.dart';
import '../services/conversation_log_service.dart';
import '../services/sync_service.dart';
import '../services/user_profile_service.dart';

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
  final _profileService = UserProfileService();
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
      if (remote == null && _sync.lastError != null) {
        // pull() failed outright (network/parse/auth) rather than there
        // genuinely being nothing to pull yet -- surface that distinctly,
        // since silently falling back to local-only here is exactly what
        // made this kind of failure invisible before.
        setState(() => _status = 'Sync ID: ${_sync.docId}. Pull failed: ${_sync.lastError}');
        return;
      }
      final mergedEntries =
          remote == null ? await _log.readAll() : await _log.mergeWithRemote(remote.entries);
      final mergedProfile = remote == null
          ? await _profileService.read()
          : await _profileService.mergeWithRemote(remote.profile);
      await _sync.push(mergedEntries, mergedProfile);
      final pushError = _sync.lastError;
      setState(() => _status = pushError != null
          ? 'Pulled OK (${mergedEntries.length} total), but push failed: $pushError'
          : 'Linked. ${mergedEntries.length} messages synced. Sync ID: ${_sync.docId} '
              '-- this should match exactly on every linked device.');
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
              // Explicit, not left to platform defaults: the passphrase is
              // hashed byte-for-byte into the Firestore doc path, so any
              // difference between devices in auto-capitalization or
              // autocorrect -- a very real risk on mobile keyboards --
              // silently points them at two different documents.
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: _busy ? const CircularProgressIndicator() : const Text('Save & sync now'),
            ),
            if (SyncService.isConfigured) ...[
              const SizedBox(height: 12),
              Text(
                'Current sync ID: ${_sync.docId} -- compare this on each '
                'device to confirm they\'re actually linked to the same data.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
