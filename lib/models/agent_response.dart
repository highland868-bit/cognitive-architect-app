/// Mirrors the JSON schema defined in the master plan's RESPONSE FORMAT
/// section (v4). Keep these two in sync if the schema changes.
class AgentResponse {
  final String agent;
  final String avatarState;
  final String breathPattern;
  final String technique;
  final bool crisisFlag;
  final String traitTarget;
  final String responseText;
  final String logEntry;

  AgentResponse({
    required this.agent,
    required this.avatarState,
    required this.breathPattern,
    required this.technique,
    required this.crisisFlag,
    required this.traitTarget,
    required this.responseText,
    required this.logEntry,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    return AgentResponse(
      agent: json['agent'] as String? ?? 'PSYCHE',
      avatarState: json['avatar_state'] as String? ?? 'IDLE',
      breathPattern: json['breath_pattern'] as String? ?? 'none',
      technique: json['technique'] as String? ?? 'none',
      crisisFlag: json['crisis_flag'] as bool? ?? false,
      traitTarget: json['trait_target'] as String? ?? 'none',
      responseText: json['response_text'] as String? ?? '',
      logEntry: json['log_entry'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'agent': agent,
        'avatar_state': avatarState,
        'breath_pattern': breathPattern,
        'technique': technique,
        'crisis_flag': crisisFlag,
        'trait_target': traitTarget,
        'response_text': responseText,
        'log_entry': logEntry,
      };
}
