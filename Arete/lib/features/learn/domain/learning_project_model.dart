import 'dart:convert';
import 'package:flutter/material.dart';

class LearningProject {
  final String id;
  final String categoryId;
  final String? roadmapId;
  final String projectGroup; // 'primary' or 'advanced_ai'
  final String name;
  final String? description;
  final String? architecture;
  final String status; // 'planned', 'in_progress', 'completed'
  final int projectOrder;
  final List<String> techStack;
  final List<String> domainAreas;
  final List<String> learningFocus;
  final String? checkpointNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final String? categoryTitle;

  const LearningProject({
    required this.id,
    required this.categoryId,
    this.roadmapId,
    this.projectGroup = 'primary',
    required this.name,
    this.description,
    this.architecture,
    this.status = 'planned',
    this.projectOrder = 0,
    this.techStack = const [],
    this.domainAreas = const [],
    this.learningFocus = const [],
    this.checkpointNotes,
    required this.createdAt,
    required this.updatedAt,
    this.categoryTitle,
  });

  bool get isPrimary => projectGroup == 'primary';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  Color get statusColor {
    switch (status) {
      case 'completed':
        return const Color(0xFF2A4E35);
      case 'in_progress':
        return const Color(0xFFFF7A59);
      case 'planned':
      default:
        return const Color(0xFF8B948C);
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'planned':
      default:
        return 'Planned';
    }
  }

  LearningProject copyWith({
    String? id,
    String? categoryId,
    String? roadmapId,
    String? projectGroup,
    String? name,
    String? description,
    String? architecture,
    String? status,
    int? projectOrder,
    List<String>? techStack,
    List<String>? domainAreas,
    List<String>? learningFocus,
    String? checkpointNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryTitle,
  }) {
    return LearningProject(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      roadmapId: roadmapId ?? this.roadmapId,
      projectGroup: projectGroup ?? this.projectGroup,
      name: name ?? this.name,
      description: description ?? this.description,
      architecture: architecture ?? this.architecture,
      status: status ?? this.status,
      projectOrder: projectOrder ?? this.projectOrder,
      techStack: techStack ?? this.techStack,
      domainAreas: domainAreas ?? this.domainAreas,
      learningFocus: learningFocus ?? this.learningFocus,
      checkpointNotes: checkpointNotes ?? this.checkpointNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryTitle: categoryTitle ?? this.categoryTitle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'roadmap_id': roadmapId,
      'project_group': projectGroup,
      'name': name,
      'description': description,
      'architecture': architecture,
      'status': status,
      'project_order': projectOrder,
      'tech_stack': jsonEncode(techStack),
      'domain_areas': jsonEncode(domainAreas),
      'learning_focus': jsonEncode(learningFocus),
      'checkpoint_notes': checkpointNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LearningProject.fromMap(Map<String, dynamic> map, {String? categoryTitle}) {
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

    return LearningProject(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      roadmapId: map['roadmap_id'] as String?,
      projectGroup: map['project_group'] as String? ?? 'primary',
      name: map['name'] as String,
      description: map['description'] as String?,
      architecture: map['architecture'] as String?,
      status: map['status'] as String? ?? 'planned',
      projectOrder: (map['project_order'] as num?)?.toInt() ?? 0,
      techStack: parseList(map['tech_stack']),
      domainAreas: parseList(map['domain_areas']),
      learningFocus: parseList(map['learning_focus']),
      checkpointNotes: map['checkpoint_notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
      categoryTitle: categoryTitle ?? (map['category_title'] as String?),
    );
  }
}
