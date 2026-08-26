// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// dart:html is used deliberately: this project targets web only (see
// conversation_log_service.dart for the same reasoning).
import 'dart:convert';
import 'dart:html' as html;

/// One thing Claude noticed worth remembering -- part of the rolling,
/// capped list, distinct from user-curated Core facts. Never written to
/// Core directly; the user has to promote it first.
class ProfileNote {
  final String text;
  final DateTime timestamp;

  ProfileNote({required this.text, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ProfileNote.fromJson(Map<String, dynamic> j) => ProfileNote(
        text: j['text'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}

/// Core: stable facts the user has written or approved -- included in
/// every call to Claude regardless of agent/topic, never auto-evicted,
/// never written to directly by the model. Notes: things Claude noticed
/// along the way, capped and FIFO-evicted as new ones come in.
class UserProfile {
  final List<String> core;
  final List<ProfileNote> notes;

  UserProfile({required this.core, required this.notes});

  static UserProfile empty() => UserProfile(core: [], notes: []);

  Map<String, dynamic> toJson() => {
        'core': core,
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        core: (j['core'] as List<dynamic>? ?? const []).cast<String>(),
        notes: (j['notes'] as List<dynamic>? ?? const [])
            .map((n) => ProfileNote.fromJson(n as Map<String, dynamic>))
            .toList(),
      );
}

class UserProfileService {
  static const _key = 'user_profile';

  /// Small enough that both Core and Notes together stay cheap to include
  /// in every single call, regardless of which agent or topic.
  static const notesCap = 20;

  Future<UserProfile> read() async {
    final raw = html.window.localStorage[_key];
    if (raw == null) return UserProfile.empty();
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _write(UserProfile profile) async {
    html.window.localStorage[_key] = jsonEncode(profile.toJson());
  }

  Future<void> addCore(String text) async {
    final p = await read();
    await _write(UserProfile(core: [...p.core, text], notes: p.notes));
  }

  Future<void> editCore(int index, String text) async {
    final p = await read();
    if (index < 0 || index >= p.core.length) return;
    final updated = [...p.core];
    updated[index] = text;
    await _write(UserProfile(core: updated, notes: p.notes));
  }

  Future<void> removeCore(int index) async {
    final p = await read();
    if (index < 0 || index >= p.core.length) return;
    final updated = [...p.core]..removeAt(index);
    await _write(UserProfile(core: updated, notes: p.notes));
  }

  Future<void> addNote(String text) async {
    final p = await read();
    final updated = [...p.notes, ProfileNote(text: text, timestamp: DateTime.now())]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final capped =
        updated.length > notesCap ? updated.sublist(updated.length - notesCap) : updated;
    await _write(UserProfile(core: p.core, notes: capped));
  }

  Future<void> editNote(int index, String text) async {
    final p = await read();
    if (index < 0 || index >= p.notes.length) return;
    final updated = [...p.notes];
    updated[index] = ProfileNote(text: text, timestamp: updated[index].timestamp);
    await _write(UserProfile(core: p.core, notes: updated));
  }

  Future<void> removeNote(int index) async {
    final p = await read();
    if (index < 0 || index >= p.notes.length) return;
    final updated = [...p.notes]..removeAt(index);
    await _write(UserProfile(core: p.core, notes: updated));
  }

  /// Moves a Note into Core permanently -- the only way anything the
  /// model noticed becomes part of the never-evicted section, and it
  /// requires this explicit user action.
  Future<void> promoteNoteToCore(int index) async {
    final p = await read();
    if (index < 0 || index >= p.notes.length) return;
    final note = p.notes[index];
    final updatedNotes = [...p.notes]..removeAt(index);
    await _write(UserProfile(core: [...p.core, note.text], notes: updatedNotes));
  }

  /// Merges a remote profile into the local one -- Core is unioned by
  /// exact text (deduped), Notes unioned by text+timestamp and re-capped
  /// to the most recent [notesCap] afterward. Re-reads local immediately
  /// before writing, same race-safety pattern as
  /// ConversationLogService.mergeWithRemote.
  Future<UserProfile> mergeWithRemote(UserProfile remote) async {
    final local = await read();
    final core = <String>{...local.core, ...remote.core};
    final noteMap = <String, ProfileNote>{};
    for (final n in [...local.notes, ...remote.notes]) {
      noteMap['${n.timestamp.toIso8601String()}|${n.text}'] = n;
    }
    final justBeforeWrite = await read();
    core.addAll(justBeforeWrite.core);
    for (final n in justBeforeWrite.notes) {
      noteMap['${n.timestamp.toIso8601String()}|${n.text}'] = n;
    }
    var notes = noteMap.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (notes.length > notesCap) {
      notes = notes.sublist(notes.length - notesCap);
    }
    final result = UserProfile(core: core.toList(), notes: notes);
    await _write(result);
    return result;
  }
}
