class Task {
  final String id;
  final String? goalId;
  final String title;
  final String? description;
  final String? dueDate; // YYYY-MM-DD
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isDailyTarget;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined metadata
  final String? goalTitle;
  final String? goalColor;

  const Task({
    required this.id,
    this.goalId,
    required this.title,
    this.description,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.isDailyTarget = false,
    required this.createdAt,
    required this.updatedAt,
    this.goalTitle,
    this.goalColor,
  });

  Task copyWith({
    String? id,
    String? goalId,
    String? title,
    String? description,
    String? dueDate,
    bool? isCompleted,
    DateTime? completedAt,
    bool? isDailyTarget,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? goalTitle,
    String? goalColor,
  }) {
    return Task(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      isDailyTarget: isDailyTarget ?? this.isDailyTarget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      goalTitle: goalTitle ?? this.goalTitle,
      goalColor: goalColor ?? this.goalColor,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'title': title,
      'description': description,
      'due_date': dueDate,
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'is_daily_target': isDailyTarget ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      goalId: map['goal_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: map['due_date'] as String?,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      isDailyTarget: (map['is_daily_target'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      goalTitle: map['goal_title'] as String?,
      goalColor: map['goal_color'] as String?,
    );
  }
}
