class Note {
  final String id;
  final String title;
  final String body;
  final bool isPinned;
  final String? goalId;
  final String? resourceId;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined metadata
  final String? goalTitle;
  final String? resourceTitle;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    this.isPinned = false,
    this.goalId,
    this.resourceId,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.goalTitle,
    this.resourceTitle,
  });

  Note copyWith({
    String? id,
    String? title,
    String? body,
    bool? isPinned,
    String? goalId,
    String? resourceId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? goalTitle,
    String? resourceTitle,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      isPinned: isPinned ?? this.isPinned,
      goalId: goalId ?? this.goalId,
      resourceId: resourceId ?? this.resourceId,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      goalTitle: goalTitle ?? this.goalTitle,
      resourceTitle: resourceTitle ?? this.resourceTitle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'is_pinned': isPinned ? 1 : 0,
      'goal_id': goalId,
      'resource_id': resourceId,
      'tags': tags.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final tagsStr = map['tags'] as String? ?? '';
    final parsedTags = tagsStr.isNotEmpty
        ? tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];

    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      goalId: map['goal_id'] as String?,
      resourceId: map['resource_id'] as String?,
      tags: parsedTags,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      goalTitle: map['goal_title'] as String?,
      resourceTitle: map['resource_title'] as String?,
    );
  }
}
