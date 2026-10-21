enum FocusSessionType {
  focus,
  shortBreak,
  longBreak;

  String get displayName {
    switch (this) {
      case FocusSessionType.focus:
        return 'Focus';
      case FocusSessionType.shortBreak:
        return 'Short Break';
      case FocusSessionType.longBreak:
        return 'Long Break';
    }
  }

  static FocusSessionType fromString(String val) {
    switch (val) {
      case 'short_break':
        return FocusSessionType.shortBreak;
      case 'long_break':
        return FocusSessionType.longBreak;
      case 'focus':
      default:
        return FocusSessionType.focus;
    }
  }

  String get dbValue {
    switch (this) {
      case FocusSessionType.focus:
        return 'focus';
      case FocusSessionType.shortBreak:
        return 'short_break';
      case FocusSessionType.longBreak:
        return 'long_break';
    }
  }
}

class FocusSession {
  final String id;
  final String? taskId;
  final String? goalId;
  final FocusSessionType sessionType;
  final int durationSeconds;
  final int completedSeconds;
  final bool isCompleted;
  final bool shieldEnabled;
  final bool strictMode;
  final int interruptionsCount;
  final DateTime startedAt;
  final DateTime endedAt;

  // Joined metadata
  final String? taskTitle;
  final String? goalTitle;

  const FocusSession({
    required this.id,
    this.taskId,
    this.goalId,
    required this.sessionType,
    required this.durationSeconds,
    required this.completedSeconds,
    this.isCompleted = true,
    this.shieldEnabled = false,
    this.strictMode = false,
    this.interruptionsCount = 0,
    required this.startedAt,
    required this.endedAt,
    this.taskTitle,
    this.goalTitle,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'goal_id': goalId,
      'session_type': sessionType.dbValue,
      'duration_seconds': durationSeconds,
      'completed_seconds': completedSeconds,
      'is_completed': isCompleted ? 1 : 0,
      'shield_enabled': shieldEnabled ? 1 : 0,
      'strict_mode': strictMode ? 1 : 0,
      'interruptions_count': interruptionsCount,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
    };
  }

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'] as String,
      taskId: map['task_id'] as String?,
      goalId: map['goal_id'] as String?,
      sessionType: FocusSessionType.fromString(map['session_type'] as String),
      durationSeconds: (map['duration_seconds'] as num).toInt(),
      completedSeconds: (map['completed_seconds'] as num).toInt(),
      isCompleted: (map['is_completed'] as int? ?? 1) == 1,
      shieldEnabled: (map['shield_enabled'] as int? ?? 0) == 1,
      strictMode: (map['strict_mode'] as int? ?? 0) == 1,
      interruptionsCount: (map['interruptions_count'] as num? ?? 0).toInt(),
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: DateTime.parse(map['ended_at'] as String),
      taskTitle: map['task_title'] as String?,
      goalTitle: map['goal_title'] as String?,
    );
  }
}
