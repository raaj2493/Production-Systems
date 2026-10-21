import 'package:flutter/material.dart';

class DsaProblem {
  final String id;
  final String title;
  final String pattern;
  final String difficulty;
  final String status; // 'not_started', 'attempted', 'solved', 'mastered'
  final String? intuition;
  final String? approach;
  final String? mistakes;
  final String? timeComplexity;
  final String? spaceComplexity;
  final String? codeSnippet;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DsaProblem({
    required this.id,
    required this.title,
    required this.pattern,
    this.difficulty = 'Medium',
    this.status = 'not_started',
    this.intuition,
    this.approach,
    this.mistakes,
    this.timeComplexity,
    this.spaceComplexity,
    this.codeSnippet,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSolved => status == 'solved' || status == 'mastered';

  Color get statusColor {
    switch (status) {
      case 'mastered':
        return const Color(0xFF2A4E35);
      case 'solved':
        return const Color(0xFF5A8E65);
      case 'attempted':
        return const Color(0xFFFF7A59);
      case 'not_started':
      default:
        return const Color(0xFF8B948C);
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'mastered':
        return 'Mastered';
      case 'solved':
        return 'Solved';
      case 'attempted':
        return 'Attempted';
      case 'not_started':
      default:
        return 'Not Started';
    }
  }

  Color get difficultyColor {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF2A4E35);
      case 'hard':
        return const Color(0xFFBA1A1A);
      case 'medium':
      default:
        return const Color(0xFFB5701B);
    }
  }

  DsaProblem copyWith({
    String? id,
    String? title,
    String? pattern,
    String? difficulty,
    String? status,
    String? intuition,
    String? approach,
    String? mistakes,
    String? timeComplexity,
    String? spaceComplexity,
    String? codeSnippet,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DsaProblem(
      id: id ?? this.id,
      title: title ?? this.title,
      pattern: pattern ?? this.pattern,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      intuition: intuition ?? this.intuition,
      approach: approach ?? this.approach,
      mistakes: mistakes ?? this.mistakes,
      timeComplexity: timeComplexity ?? this.timeComplexity,
      spaceComplexity: spaceComplexity ?? this.spaceComplexity,
      codeSnippet: codeSnippet ?? this.codeSnippet,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'pattern': pattern,
      'difficulty': difficulty,
      'status': status,
      'intuition': intuition,
      'approach': approach,
      'mistakes': mistakes,
      'time_complexity': timeComplexity,
      'space_complexity': spaceComplexity,
      'code_snippet': codeSnippet,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DsaProblem.fromMap(Map<String, dynamic> map) {
    return DsaProblem(
      id: map['id'] as String,
      title: map['title'] as String,
      pattern: map['pattern'] as String,
      difficulty: map['difficulty'] as String? ?? 'Medium',
      status: map['status'] as String? ?? 'not_started',
      intuition: map['intuition'] as String?,
      approach: map['approach'] as String?,
      mistakes: map['mistakes'] as String?,
      timeComplexity: map['time_complexity'] as String?,
      spaceComplexity: map['space_complexity'] as String?,
      codeSnippet: map['code_snippet'] as String?,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
