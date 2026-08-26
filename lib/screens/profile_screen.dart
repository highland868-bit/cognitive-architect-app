import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';

/// Core: stable facts the user writes or approves, never auto-evicted,
/// never written to by Claude directly. Notes: things Claude noticed
/// along the way -- capped, oldest dropped as new ones arrive -- which
/// the user can edit, delete, or pin permanently into Core.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = UserProfileService();
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _service.read();
    if (mounted) setState(() => _profile = p);
  }

  Future<String?> _promptText(String title, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCore() async {
    final text = await _promptText('Add a core fact');
    if (text == null || text.isEmpty) return;
    await _service.addCore(text);
    await _load();
  }

  Future<void> _editCore(int i) async {
    final text = await _promptText('Edit', initial: _profile!.core[i]);
    if (text == null || text.isEmpty) return;
    await _service.editCore(i, text);
    await _load();
  }

  Future<void> _removeCore(int i) async {
    await _service.removeCore(i);
    await _load();
  }

  Future<void> _editNote(int i) async {
    final text = await _promptText('Edit', initial: _profile!.notes[i].text);
    if (text == null || text.isEmpty) return;
    await _service.editNote(i, text);
    await _load();
  }

  Future<void> _removeNote(int i) async {
    await _service.removeNote(i);
    await _load();
  }

  Future<void> _promoteNote(int i) async {
    await _service.promoteNoteToCore(i);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Your Profile')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Core', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Add a core fact',
                      onPressed: _addCore,
                    ),
                  ],
                ),
                Text(
                  "Stable facts you've written or approved. Claude never adds "
                  "here directly -- write one yourself, or pin one from Notes below.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (profile.core.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nothing here yet.'),
                  ),
                for (var i = 0; i < profile.core.length; i++)
                  Card(
                    child: ListTile(
                      title: Text(profile.core[i]),
                      onTap: () => _editCore(i),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                        onPressed: () => _removeCore(i),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  "Things Claude has noticed along the way. Oldest drop off once "
                  "this fills up -- pin one to Core to keep it permanently.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (profile.notes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nothing noticed yet.'),
                  ),
                for (var i = profile.notes.length - 1; i >= 0; i--)
                  Card(
                    child: ListTile(
                      title: Text(profile.notes[i].text),
                      onTap: () => _editNote(i),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.push_pin_outlined),
                            tooltip: 'Pin to Core',
                            onPressed: () => _promoteNote(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove',
                            onPressed: () => _removeNote(i),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
