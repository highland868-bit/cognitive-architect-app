# Cognitive Architect (personal build)

Personal breathwork + CBT/ACT/Stoic reflection companion. See the master
plan doc (cognitive_architect_system_prompt_v2.md) for the full
architecture and the reasoning behind each decision -- this README is
just setup steps.

## Setup

1. Install the Flutter SDK (flutter.dev) if you haven't already, and run
   `flutter doctor` to confirm your setup.
2. From this folder, run `flutter pub get`.
3. `assets/animations/breathing.json` is the real "Breathe Babo" Lottie
   clip, used only for the BREATHING state (see Structure below). Every
   other avatar state is drawn natively in code -- no other Lottie files
   are needed.
4. Get an Anthropic API key from console.anthropic.com. This app calls
   the Claude API directly (not claude.ai), so usage is billed per the
   API's current pricing -- for personal journaling volume this should
   be low, but worth checking current rates before heavy use.
5. Run the app with your key passed in, never hardcoded or committed:
   ```
   flutter run --dart-define=ANTHROPIC_API_KEY=your_key_here
   ```

## Structure

- `lib/system_prompt.dart` -- the full v4 system prompt from the master
  plan, embedded as a constant. Keep in sync manually if the doc changes.
- `lib/services/crisis_backstop.dart` -- deterministic keyword safety
  net. **Expand this list.** It's a starting point, not exhaustive, and
  is the backstop that runs even if the model call fails or SENTINEL
  misses something.
- `lib/services/claude_service.dart` -- calls the Claude API, parses the
  JSON response.
- `lib/services/tts_service.dart` -- on-device text-to-speech.
- `lib/services/trait_log_service.dart` -- appends each turn to a local
  trait log stored via dart:html's localStorage (this project targets
  web only, so no separate pub package is needed for this).
- `lib/widgets/native_avatar.dart` -- the single, code-drawn "mood"
  avatar used for every avatar_state except BREATHING. One widget,
  parameterized by state, so the visual language stays consistent
  without needing a separate asset per state.
- `lib/widgets/avatar_view.dart` -- thin wrapper around NativeAvatar.
- `lib/widgets/breathing_pacer.dart` -- native, deterministic
  breath-count pacer; this is the actual timer. The "Breathe Babo"
  Lottie clip plays alongside it as mood/visual only, looping
  independently -- it never drives the timing.
- `lib/screens/home_screen.dart` -- ties it all together: text input,
  crisis backstop check, Claude call, avatar/pacer display, TTS, logging.
- `lib/main.dart` -- entry point.

## Known gaps / next steps

- Trait log has no viewer UI yet -- currently just accumulates in
  browser localStorage. A simple screen to chart trait_target frequency
  over time would be the next high-value addition.
- No voice-note input (speech-to-text) -- text only for now. The
  `speech_to_text` package would be the natural add.
- Crisis backstop keyword list is a starting point; review and expand it
  periodically -- it will always have false negatives as a plain keyword
  match.
- No automated tests yet.
- This was scaffolded by hand (no Flutter SDK available in the
  environment that generated it), so run `flutter pub get` and `flutter
  analyze` first thing to catch anything that needs adjusting for your
  exact Flutter/Dart version.
