import 'package:flutter/material.dart';
import '../services/tts_service.dart';

const _sampleText = "This is what your check-ins will sound like.";

/// Lets the user browse whatever voices the OS already has installed --
/// iOS's downloadable Enhanced/Premium voices sound noticeably more
/// natural than the default, and this is free, on-device, no new
/// dependency. Filtered to English so it isn't a wall of every locale.
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key, required this.tts});

  final TtsService tts;

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  late final Future<List<Map<String, String>>> _voices = _loadVoices();
  String? _selectedName;

  Future<List<Map<String, String>>> _loadVoices() async {
    final all = await widget.tts.getVoices();
    final english = all.where((v) => (v['locale'] ?? '').toLowerCase().startsWith('en')).toList();
    english.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return english.isNotEmpty ? english : all;
  }

  Future<void> _select(Map<String, String> voice) async {
    final name = voice['name'];
    final locale = voice['locale'];
    if (name == null || locale == null) return;
    await widget.tts.setVoice(name, locale);
    setState(() => _selectedName = name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a voice')),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _voices,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final voices = snapshot.data!;
          if (voices.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No voices reported by this browser/OS. On iPhone, try adding '
                  'a voice under Settings > Accessibility > Spoken Content > '
                  'Voices first.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: voices.length,
            itemBuilder: (context, i) {
              final voice = voices[i];
              final name = voice['name'] ?? 'Unknown';
              final selected = name == _selectedName;
              return ListTile(
                title: Text(name),
                subtitle: Text(voice['locale'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Preview',
                  onPressed: () async {
                    await _select(voice);
                    await widget.tts.speak(_sampleText);
                  },
                ),
                selected: selected,
                leading: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
                onTap: () => _select(voice),
              );
            },
          );
        },
      ),
    );
  }
}
