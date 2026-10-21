import 'package:flutter/material.dart';
import '../utils/youtube_parser.dart';

enum ResourceType {
  video,
  course,
  article,
  book,
  documentation,
  roadmap,
  other;

  String get displayName {
    switch (this) {
      case ResourceType.video:
        return 'Video / Playlist';
      case ResourceType.course:
        return 'Course';
      case ResourceType.article:
        return 'Article';
      case ResourceType.book:
        return 'Book';
      case ResourceType.documentation:
        return 'Documentation';
      case ResourceType.roadmap:
        return 'Roadmap';
      case ResourceType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ResourceType.video:
        return Icons.play_circle_outline;
      case ResourceType.course:
        return Icons.school_outlined;
      case ResourceType.article:
        return Icons.article_outlined;
      case ResourceType.book:
        return Icons.menu_book_outlined;
      case ResourceType.documentation:
        return Icons.description_outlined;
      case ResourceType.roadmap:
        return Icons.alt_route_outlined;
      case ResourceType.other:
        return Icons.bookmark_border;
    }
  }

  static ResourceType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'video':
        return ResourceType.video;
      case 'course':
        return ResourceType.course;
      case 'article':
        return ResourceType.article;
      case 'book':
        return ResourceType.book;
      case 'documentation':
        return ResourceType.documentation;
      case 'roadmap':
        return ResourceType.roadmap;
      default:
        return ResourceType.other;
    }
  }

  String get dbValue => name;
}

enum ResourceStatus {
  notStarted,
  inProgress,
  completed;

  String get displayName {
    switch (this) {
      case ResourceStatus.notStarted:
        return 'Not Started';
      case ResourceStatus.inProgress:
        return 'In Progress';
      case ResourceStatus.completed:
        return 'Completed';
    }
  }

  static ResourceStatus fromString(String val) {
    switch (val.toLowerCase()) {
      case 'in_progress':
        return ResourceStatus.inProgress;
      case 'completed':
        return ResourceStatus.completed;
      case 'not_started':
      default:
        return ResourceStatus.notStarted;
    }
  }

  String get dbValue {
    switch (this) {
      case ResourceStatus.notStarted:
        return 'not_started';
      case ResourceStatus.inProgress:
        return 'in_progress';
      case ResourceStatus.completed:
        return 'completed';
    }
  }
}

class LearningResource {
  final String id;
  final String? collectionId;
  final String title;
  final String url;
  final ResourceType resourceType;
  final String? description;
  final String? topic;
  final ResourceStatus status;
  final int progressPercentage; // 0 - 100
  final String? notes;
  final String? duration;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined metadata
  final String? collectionTitle;

  const LearningResource({
    required this.id,
    this.collectionId,
    required this.title,
    required this.url,
    this.resourceType = ResourceType.article,
    this.description,
    this.topic,
    this.status = ResourceStatus.notStarted,
    this.progressPercentage = 0,
    this.notes,
    this.duration,
    this.thumbnailUrl,
    required this.createdAt,
    required this.updatedAt,
    this.collectionTitle,
  });

  ResourceType get type => resourceType;

  bool get isYouTube => YouTubeParser.isYouTubeUrl(url);

  bool get isPlaylist => YouTubeParser.isPlaylist(url);

  String? get youtubeVideoId => YouTubeParser.extractVideoId(url);

  String? get youtubePlaylistId => YouTubeParser.extractPlaylistId(url);

  String? get effectiveThumbnailUrl =>
      thumbnailUrl ?? YouTubeParser.getThumbnailUrl(url);

  String? get fallbackThumbnailUrl =>
      YouTubeParser.getFallbackThumbnailUrl(url);

  int get durationMinutes => YouTubeParser.parseDurationToMinutes(duration);

  String get badgeTypeLabel {
    if (isPlaylist) return 'YouTube Playlist';
    if (isYouTube) return 'YouTube Video';
    return resourceType.displayName;
  }

  LearningResource copyWith({
    String? id,
    String? collectionId,
    String? title,
    String? url,
    ResourceType? resourceType,
    String? description,
    String? topic,
    ResourceStatus? status,
    int? progressPercentage,
    String? notes,
    String? duration,
    String? thumbnailUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? collectionTitle,
  }) {
    return LearningResource(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      title: title ?? this.title,
      url: url ?? this.url,
      resourceType: resourceType ?? this.resourceType,
      description: description ?? this.description,
      topic: topic ?? this.topic,
      status: status ?? this.status,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      notes: notes ?? this.notes,
      duration: duration ?? this.duration,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      collectionTitle: collectionTitle ?? this.collectionTitle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collection_id': collectionId,
      'title': title,
      'url': url,
      'resource_type': resourceType.dbValue,
      'description': description,
      'topic': topic,
      'status': status.dbValue,
      'progress_percentage': progressPercentage,
      'notes': notes,
      'duration': duration,
      'thumbnail_url': thumbnailUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LearningResource.fromMap(Map<String, dynamic> map) {
    return LearningResource(
      id: map['id'] as String,
      collectionId: map['collection_id'] as String?,
      title: map['title'] as String,
      url: map['url'] as String,
      resourceType: ResourceType.fromString(map['resource_type'] as String? ?? 'other'),
      description: map['description'] as String?,
      topic: map['topic'] as String?,
      status: ResourceStatus.fromString(map['status'] as String? ?? 'not_started'),
      progressPercentage: (map['progress_percentage'] as num? ?? 0).toInt(),
      notes: map['notes'] as String?,
      duration: map['duration'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      collectionTitle: map['collection_title'] as String?,
    );
  }
}
