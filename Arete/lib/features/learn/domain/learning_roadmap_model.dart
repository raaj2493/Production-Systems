import 'dart:convert';

class LearningRoadmap {
  final String id;
  final String categoryId;
  final String title;
  final String? description;
  final String status;
  final String? primaryLanguage;
  final List<String> learningRules;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined phases & topics
  final List<RoadmapPhase> phases;
  final String? categoryTitle;
  final int totalTopicsCount;
  final int completedTopicsCount;

  const LearningRoadmap({
    required this.id,
    required this.categoryId,
    required this.title,
    this.description,
    this.status = 'not_started',
    this.primaryLanguage,
    this.learningRules = const [],
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.phases = const [],
    this.categoryTitle,
    this.totalTopicsCount = 0,
    this.completedTopicsCount = 0,
  });

  int get totalTopics {
    if (phases.isNotEmpty) {
      return phases.fold(0, (sum, p) => sum + p.topics.length);
    }
    return totalTopicsCount;
  }

  int get completedTopics {
    if (phases.isNotEmpty) {
      return phases.fold(0, (sum, p) => sum + p.completedTopics);
    }
    return completedTopicsCount;
  }

  double get progressRatio =>
      totalTopics > 0 ? (completedTopics / totalTopics).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => totalTopics > 0 && completedTopics >= totalTopics;

  LearningRoadmap copyWith({
    String? id,
    String? categoryId,
    String? title,
    String? description,
    String? status,
    String? primaryLanguage,
    List<String>? learningRules,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<RoadmapPhase>? phases,
    String? categoryTitle,
    int? totalTopicsCount,
    int? completedTopicsCount,
  }) {
    return LearningRoadmap(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      learningRules: learningRules ?? this.learningRules,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      phases: phases ?? this.phases,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      totalTopicsCount: totalTopicsCount ?? this.totalTopicsCount,
      completedTopicsCount: completedTopicsCount ?? this.completedTopicsCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'status': status,
      'primary_language': primaryLanguage,
      'learning_rules': jsonEncode(learningRules),
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LearningRoadmap.fromMap(
    Map<String, dynamic> map, {
    List<RoadmapPhase> phases = const [],
    String? categoryTitle,
    int totalTopicsCount = 0,
    int completedTopicsCount = 0,
  }) {
    List<String> rules = [];
    final rulesRaw = map['learning_rules'];
    if (rulesRaw is String && rulesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(rulesRaw);
        if (decoded is List) {
          rules = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return LearningRoadmap(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'not_started',
      primaryLanguage: map['primary_language'] as String?,
      learningRules: rules,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
      phases: phases,
      categoryTitle: categoryTitle ?? (map['category_title'] as String?),
      totalTopicsCount: totalTopicsCount,
      completedTopicsCount: completedTopicsCount,
    );
  }
}

class RoadmapPhase {
  final String id;
  final String roadmapId;
  final String title;
  final int phaseOrder;
  final DateTime createdAt;
  final List<RoadmapTopic> topics;

  const RoadmapPhase({
    required this.id,
    required this.roadmapId,
    required this.title,
    required this.phaseOrder,
    required this.createdAt,
    this.topics = const [],
  });

  int get completedTopics => topics.where((t) => t.isCompleted).length;
  bool get isCompleted => topics.isNotEmpty && completedTopics >= topics.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roadmap_id': roadmapId,
      'title': title,
      'phase_order': phaseOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RoadmapPhase.fromMap(Map<String, dynamic> map, {List<RoadmapTopic> topics = const []}) {
    return RoadmapPhase(
      id: map['id'] as String,
      roadmapId: map['roadmap_id'] as String,
      title: map['title'] as String,
      phaseOrder: (map['phase_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      topics: topics,
    );
  }
}

class RoadmapTopic {
  final String id;
  final String phaseId;
  final String roadmapId;
  final String title;
  final int topicOrder;
  final bool isCompleted;
  final String? notes;
  final DateTime? completedAt;

  const RoadmapTopic({
    required this.id,
    required this.phaseId,
    required this.roadmapId,
    required this.title,
    required this.topicOrder,
    this.isCompleted = false,
    this.notes,
    this.completedAt,
  });

  RoadmapTopic copyWith({
    String? id,
    String? phaseId,
    String? roadmapId,
    String? title,
    int? topicOrder,
    bool? isCompleted,
    String? notes,
    DateTime? completedAt,
  }) {
    return RoadmapTopic(
      id: id ?? this.id,
      phaseId: phaseId ?? this.phaseId,
      roadmapId: roadmapId ?? this.roadmapId,
      title: title ?? this.title,
      topicOrder: topicOrder ?? this.topicOrder,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phase_id': phaseId,
      'roadmap_id': roadmapId,
      'title': title,
      'topic_order': topicOrder,
      'is_completed': isCompleted ? 1 : 0,
      'notes': notes,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory RoadmapTopic.fromMap(Map<String, dynamic> map) {
    return RoadmapTopic(
      id: map['id'] as String,
      phaseId: map['phase_id'] as String,
      roadmapId: map['roadmap_id'] as String,
      title: map['title'] as String,
      topicOrder: (map['topic_order'] as num?)?.toInt() ?? 0,
      isCompleted: (map['is_completed'] as num?)?.toInt() == 1,
      notes: map['notes'] as String?,
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'] as String) : null,
    );
  }
}
