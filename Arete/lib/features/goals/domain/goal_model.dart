class Goal {
  final String id;
  final String title;
  final String? description;
  final String? color;
  final DateTime? targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed metrics from associated tasks
  final int totalTasks;
  final int completedTasks;

  int get totalTaskCount => totalTasks;
  int get completedTaskCount => completedTasks;

  const Goal({
    required this.id,
    required this.title,
    this.description,
    this.color,
    this.targetDate,
    required this.createdAt,
    required this.updatedAt,
    this.totalTasks = 0,
    this.completedTasks = 0,
  });

  double get progressRatio =>
      totalTasks > 0 ? (completedTasks / totalTasks).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => totalTasks > 0 && completedTasks >= totalTasks;

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    String? color,
    DateTime? targetDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalTasks,
    int? completedTasks,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'color': color,
      'target_date': targetDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map, {int totalTasks = 0, int completedTasks = 0}) {
    return Goal(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      color: map['color'] as String?,
      targetDate: map['target_date'] != null
          ? DateTime.tryParse(map['target_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      totalTasks: totalTasks,
      completedTasks: completedTasks,
    );
  }
}
