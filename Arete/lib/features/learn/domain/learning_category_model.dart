import 'package:flutter/material.dart';

class LearningCategory {
  final String id;
  final String title;
  final String? icon;
  final String? color;
  final int displayOrder;
  final DateTime createdAt;

  // Joined / computed metrics
  final int totalRoadmaps;
  final int totalProjects;
  final int completedTopics;
  final int totalTopics;

  const LearningCategory({
    required this.id,
    required this.title,
    this.icon,
    this.color,
    this.displayOrder = 0,
    required this.createdAt,
    this.totalRoadmaps = 0,
    this.totalProjects = 0,
    this.completedTopics = 0,
    this.totalTopics = 0,
  });

  double get progressRatio =>
      totalTopics > 0 ? (completedTopics / totalTopics).clamp(0.0, 1.0) : 0.0;

  IconData get iconData {
    switch (id) {
      case 'computer_science':
        return Icons.memory_rounded;
      case 'problem_solving_and_dsa':
        return Icons.psychology_rounded;
      case 'backend_engineering':
        return Icons.dns_rounded;
      case 'system_design':
        return Icons.architecture_rounded;
      case 'ai_engineering':
        return Icons.smart_toy_rounded;
      case 'cloud_and_devops':
        return Icons.cloud_queue_rounded;
      case 'database_engineering':
        return Icons.storage_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  Color get categoryColor {
    if (color != null && color!.isNotEmpty) {
      try {
        final hex = color!.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    switch (id) {
      case 'computer_science':
        return const Color(0xFF2A4E35);
      case 'problem_solving_and_dsa':
        return const Color(0xFFFF7A59);
      case 'backend_engineering':
        return const Color(0xFF1C3B4D);
      case 'system_design':
        return const Color(0xFF5A2D00);
      case 'ai_engineering':
        return const Color(0xFF7B2CBF);
      case 'cloud_and_devops':
        return const Color(0xFF0F4C5C);
      case 'database_engineering':
        return const Color(0xFFE36414);
      default:
        return const Color(0xFF2A4E35);
    }
  }

  LearningCategory copyWith({
    String? id,
    String? title,
    String? icon,
    String? color,
    int? displayOrder,
    DateTime? createdAt,
    int? totalRoadmaps,
    int? totalProjects,
    int? completedTopics,
    int? totalTopics,
  }) {
    return LearningCategory(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      totalRoadmaps: totalRoadmaps ?? this.totalRoadmaps,
      totalProjects: totalProjects ?? this.totalProjects,
      completedTopics: completedTopics ?? this.completedTopics,
      totalTopics: totalTopics ?? this.totalTopics,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'color': color,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LearningCategory.fromMap(Map<String, dynamic> map, {
    int totalRoadmaps = 0,
    int totalProjects = 0,
    int completedTopics = 0,
    int totalTopics = 0,
  }) {
    return LearningCategory(
      id: map['id'] as String,
      title: map['title'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      totalRoadmaps: totalRoadmaps,
      totalProjects: totalProjects,
      completedTopics: completedTopics,
      totalTopics: totalTopics,
    );
  }
}
