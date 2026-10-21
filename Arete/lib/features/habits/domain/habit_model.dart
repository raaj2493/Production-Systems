import 'dart:convert';

class Habit {
  final String id;
  final String title;
  final String? description;
  final String frequencyType; // 'daily' | 'weekdays'
  final List<int> customDays; // 1 = Monday ... 7 = Sunday
  final String? color;
  final DateTime createdAt;
  final DateTime? archivedAt;

  // Computed state
  final bool isCompletedToday;
  final int currentStreak;
  final int bestStreak;

  const Habit({
    required this.id,
    required this.title,
    this.description,
    this.frequencyType = 'daily',
    this.customDays = const [1, 2, 3, 4, 5, 6, 7],
    this.color,
    required this.createdAt,
    this.archivedAt,
    this.isCompletedToday = false,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  bool isScheduledForDay(int weekday) {
    if (frequencyType == 'daily') return true;
    return customDays.contains(weekday);
  }

  bool isScheduledForDate(DateTime date) {
    return isScheduledForDay(date.weekday);
  }

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    String? frequencyType,
    List<int>? customDays,
    String? color,
    DateTime? createdAt,
    DateTime? archivedAt,
    bool? isCompletedToday,
    int? currentStreak,
    int? bestStreak,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      frequencyType: frequencyType ?? this.frequencyType,
      customDays: customDays ?? this.customDays,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'frequency_type': frequencyType,
      'custom_days': jsonEncode(customDays),
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  factory Habit.fromMap(
    Map<String, dynamic> map, {
    bool isCompletedToday = false,
    int currentStreak = 0,
    int bestStreak = 0,
  }) {
    List<int> days = const [1, 2, 3, 4, 5, 6, 7];
    if (map['custom_days'] != null && (map['custom_days'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(map['custom_days'] as String);
        if (decoded is List) {
          days = decoded.map((e) => (e as num).toInt()).toList();
        }
      } catch (_) {}
    }

    return Habit(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      frequencyType: map['frequency_type'] as String? ?? 'daily',
      customDays: days,
      color: map['color'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      archivedAt: map['archived_at'] != null
          ? DateTime.tryParse(map['archived_at'] as String)
          : null,
      isCompletedToday: isCompletedToday,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
    );
  }
}
