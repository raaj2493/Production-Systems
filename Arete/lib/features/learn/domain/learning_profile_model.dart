import 'dart:convert';

class LearningProfile {
  final String id;
  final String primaryGoal;
  final String targetHorizon;
  final String careerTitle;
  final List<String> careerEmphasis;
  final List<String> knownSkills;
  final List<String> learningSkills;
  final List<String> plannedSkills;
  final String learningStyle;
  final String theoryPracticeRatio;
  final List<String> learningWorkflow;
  final List<String> learningPreferences;
  final List<String> hackathonRhythm;
  final DateTime updatedAt;

  const LearningProfile({
    this.id = 'user_profile',
    required this.primaryGoal,
    required this.targetHorizon,
    required this.careerTitle,
    this.careerEmphasis = const [],
    this.knownSkills = const [],
    this.learningSkills = const [],
    this.plannedSkills = const [],
    required this.learningStyle,
    required this.theoryPracticeRatio,
    this.learningWorkflow = const [],
    this.learningPreferences = const [],
    this.hackathonRhythm = const [],
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'primary_goal': primaryGoal,
      'target_horizon': targetHorizon,
      'career_title': careerTitle,
      'career_emphasis': jsonEncode(careerEmphasis),
      'known_skills': jsonEncode(knownSkills),
      'learning_skills': jsonEncode(learningSkills),
      'planned_skills': jsonEncode(plannedSkills),
      'learning_style': learningStyle,
      'theory_practice_ratio': theoryPracticeRatio,
      'learning_workflow': jsonEncode(learningWorkflow),
      'learning_preferences': jsonEncode(learningPreferences),
      'hackathon_rhythm': jsonEncode(hackathonRhythm),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LearningProfile.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val is String && val.isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    return LearningProfile(
      id: map['id'] as String? ?? 'user_profile',
      primaryGoal: map['primary_goal'] as String? ?? '',
      targetHorizon: map['target_horizon'] as String? ?? '',
      careerTitle: map['career_title'] as String? ?? '',
      careerEmphasis: parseList(map['career_emphasis']),
      knownSkills: parseList(map['known_skills']),
      learningSkills: parseList(map['learning_skills']),
      plannedSkills: parseList(map['planned_skills']),
      learningStyle: map['learning_style'] as String? ?? '',
      theoryPracticeRatio: map['theory_practice_ratio'] as String? ?? '',
      learningWorkflow: parseList(map['learning_workflow']),
      learningPreferences: parseList(map['learning_preferences']),
      hackathonRhythm: parseList(map['hackathon_rhythm']),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
