/// Deterministic, keyword-based crisis check — the primary safety net,
/// not a convenience. Per the master plan's SENTINEL implementation
/// note: this must run independent of the model call, so it still works
/// even if the API is unreachable or the model fails to flag something.
///
/// This list is a starting point, not exhaustive. Review and expand it
/// periodically; a keyword check will always have false negatives.
class CrisisBackstop {
  static const List<String> _flagPhrases = [
    'kill myself',
    'end my life',
    'suicide',
    'suicidal',
    "don't want to be here",
    'not worth living',
    'want to die',
    'hurt myself',
    'self harm',
    'self-harm',
    'no reason to go on',
    'better off dead',
  ];

  /// Returns true if the input contains language that should hard-stop
  /// the normal agent pipeline, regardless of what the model returns.
  static bool check(String input) {
    final lower = input.toLowerCase();
    return _flagPhrases.any((phrase) => lower.contains(phrase));
  }

  static const String resourceMessage =
      "This sounds serious, and I don't want to run a breathing drill or "
      "a reframe past you right now. If you're in the US, the 988 Suicide "
      "& Crisis Lifeline (call or text 988) is available 24/7. Outside "
      "the US, please look up your local crisis line. Consider reaching "
      "a person you trust, or emergency services, right now.";
}
