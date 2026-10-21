class HabitCompletion {
  final String id;
  final String habitId;
  final String completionDate; // YYYY-MM-DD
  final DateTime completedAt;

  const HabitCompletion({
    required this.id,
    required this.habitId,
    required this.completionDate,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'completion_date': completionDate,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  factory HabitCompletion.fromMap(Map<String, dynamic> map) {
    return HabitCompletion(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      completionDate: map['completion_date'] as String,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }
}
