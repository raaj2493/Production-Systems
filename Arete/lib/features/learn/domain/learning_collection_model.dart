import 'package:flutter/material.dart';
import '../utils/youtube_parser.dart';

class LearningCollection {
  final String id;
  final String title;
  final String? description;
  final String? color;
  final String? icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed metrics
  final int totalResources;
  final int completedResources;
  final int totalDurationMinutes;

  const LearningCollection({
    required this.id,
    required this.title,
    this.description,
    this.color,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
    this.totalResources = 0,
    this.completedResources = 0,
    this.totalDurationMinutes = 0,
  });

  double get progressRatio => totalResources > 0
      ? (completedResources / totalResources).clamp(0.0, 1.0)
      : 0.0;

  bool get isCompleted =>
      totalResources > 0 && completedResources >= totalResources;

  String get summaryText =>
      YouTubeParser.formatFolderSummary(totalResources, totalDurationMinutes);

  IconData get iconData => getFolderIcon(icon);

  static IconData getFolderIcon(String? iconKey) {
    switch (iconKey?.toLowerCase()) {
      case 'dns':
      case 'backend':
      case 'server':
        return Icons.dns_rounded;
      case 'code':
      case 'dsa':
      case 'algorithms':
        return Icons.code_rounded;
      case 'psychology':
      case 'mindset':
      case 'focus':
        return Icons.psychology_rounded;
      case 'spa':
      case 'growth':
      case 'zen':
        return Icons.spa_rounded;
      case 'menu_book':
      case 'book':
      case 'study':
        return Icons.menu_book_rounded;
      case 'rocket_launch':
      case 'rocket':
      case 'projects':
        return Icons.rocket_launch_rounded;
      case 'school':
      case 'course':
        return Icons.school_rounded;
      case 'lightbulb':
      case 'ideas':
        return Icons.lightbulb_rounded;
      case 'terminal':
      case 'devops':
        return Icons.terminal_rounded;
      case 'folder':
      default:
        return Icons.folder_rounded;
    }
  }

  LearningCollection copyWith({
    String? id,
    String? title,
    String? description,
    String? color,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalResources,
    int? completedResources,
    int? totalDurationMinutes,
  }) {
    return LearningCollection(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalResources: totalResources ?? this.totalResources,
      completedResources: completedResources ?? this.completedResources,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'color': color,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LearningCollection.fromMap(
    Map<String, dynamic> map, {
    int totalResources = 0,
    int completedResources = 0,
    int totalDurationMinutes = 0,
  }) {
    return LearningCollection(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      color: map['color'] as String?,
      icon: map['icon'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      totalResources: totalResources,
      completedResources: completedResources,
      totalDurationMinutes: totalDurationMinutes,
    );
  }
}
