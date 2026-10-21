import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_service.dart';
import '../../focus/data/focus_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../../habits/data/habit_repository.dart';
import '../../learn/data/learn_repository.dart';
import '../../notes/data/note_repository.dart';
import '../../tasks/data/task_repository.dart';

class BackupService {
  final DatabaseService _dbService;

  BackupService([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<String> exportBackup() async {
    final jsonString = await _dbService.exportToJson();
    final now = DateTime.now();
    final fileName = 'arete_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}.json';

    final xFile = XFile.fromData(
      Uint8List.fromList(utf8.encode(jsonString)),
      mimeType: 'application/json',
      name: fileName,
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: 'Areté Data Backup',
          text: kIsWeb ? jsonString : 'Areté encrypted local backup file',
        ),
      );
    } catch (e) {
      debugPrint('Share exception: $e');
    }

    return fileName;
  }

  Future<bool> importBackupFromFile(WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return false;

      final file = result.files.first;
      String? content;

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        final xFile = XFile(file.path!);
        content = await xFile.readAsString();
      }

      if (content == null || content.isEmpty) return false;

      final success = await _dbService.importFromJson(content, replaceExisting: true);

      if (success) {
        // Refresh all feature providers
        ref.invalidate(goalsProvider);
        ref.invalidate(tasksProvider);
        ref.invalidate(habitsProvider);
        ref.invalidate(collectionsProvider);
        ref.invalidate(resourcesProvider);
        ref.invalidate(notesProvider);
        ref.invalidate(recentFocusSessionsProvider);
        ref.invalidate(todayFocusSecondsProvider);
      }

      return success;
    } catch (e) {
      debugPrint('Import backup error: $e');
      return false;
    }
  }

  Future<bool> importBackupFromText(WidgetRef ref, String jsonString, {bool replaceExisting = false}) async {
    try {
      final success = await _dbService.importFromJson(jsonString, replaceExisting: replaceExisting);
      if (success) {
        // Invalidate all providers
        ref.invalidate(goalsProvider);
        ref.invalidate(tasksProvider);
        ref.invalidate(habitsProvider);
        ref.invalidate(collectionsProvider);
        ref.invalidate(resourcesProvider);
        ref.invalidate(notesProvider);
        ref.invalidate(recentFocusSessionsProvider);
        ref.invalidate(todayFocusSecondsProvider);
      }
      return success;
    } catch (e) {
      debugPrint('Import backup from text error: $e');
      return false;
    }
  }

  static String getStarterTemplateJson() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final nowIso = now.toIso8601String();

    return '''{
  "app": "Areté",
  "version": 4,
  "exported_at": "$nowIso",
  "tables": {
    "goals": [
      {
        "id": "goal_systems_design",
        "title": "Master Backend & System Design",
        "description": "High-throughput architectures, microservices, and databases",
        "color": "#D2E8D4",
        "target_date": "2026-12-31",
        "is_completed": 0,
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "goal_dsa_leetcode",
        "title": "DSA & Blind 75 Mastery",
        "description": "Two pointers, graphs, trees, and dynamic programming",
        "color": "#FFDDB3",
        "target_date": "2026-11-30",
        "is_completed": 0,
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "goal_deep_mindset",
        "title": "Neuroscience & Peak Focus Protocols",
        "description": "Deep work routines, dopamine detox, and stoic craft",
        "color": "#E8DEF8",
        "target_date": "2026-12-31",
        "is_completed": 0,
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      }
    ],
    "habits": [
      {
        "id": "habit_deep_work",
        "title": "Deep Work (2+ Hours)",
        "description": "Zero distraction engineering sprints with Focus Shield",
        "frequency": "daily",
        "target_days": "1,2,3,4,5,6,7",
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "habit_dsa_problem",
        "title": "Solve 1 Hard / 2 Medium DSA",
        "description": "Consistent LeetCode problem solving & pattern breakdown",
        "frequency": "daily",
        "target_days": "1,2,3,4,5,6,7",
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "habit_reading",
        "title": "Read 20 Pages Non-Fiction",
        "description": "Books on systems, stoicism, and deep work",
        "frequency": "daily",
        "target_days": "1,2,3,4,5,6,7",
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "habit_hydration",
        "title": "Drink 3.5L Water & Hydrate",
        "description": "Electrolytes and physical energy upkeep",
        "frequency": "daily",
        "target_days": "1,2,3,4,5,6,7",
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      }
    ],
    "tasks": [
      {
        "id": "task_system_sharding",
        "goal_id": "goal_systems_design",
        "title": "Review Database Sharding & Partitioning Architecture",
        "description": "Analyze consistent hashing and failover mechanisms",
        "due_date": "$today",
        "is_completed": 0,
        "is_daily_target": 1,
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "task_neetcode_trees",
        "goal_id": "goal_dsa_leetcode",
        "title": "NeetCode: Binary Tree Maximum Path Sum",
        "description": "Write bottom-up recursive solution with edge cases",
        "due_date": "$today",
        "is_completed": 0,
        "is_daily_target": 1,
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "task_daily_reflection",
        "goal_id": "goal_deep_mindset",
        "title": "Daily Stoic Journal & Inquiry Review",
        "description": "Reflect on today's focus blocks and alignment",
        "due_date": "$today",
        "is_completed": 0,
        "is_daily_target": 0,
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      }
    ],
    "learning_collections": [
      {
        "id": "folder_backend_systems",
        "title": "Backend & System Design",
        "description": "Distributed architectures, scaling, caching, and database design patterns.",
        "color": "#D2E8D4",
        "icon": "dns",
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "folder_dsa_algorithms",
        "title": "DSA & Algorithms",
        "description": "Blind 75/150 patterns, dynamic programming, graphs, and system interviews.",
        "color": "#FFDDB3",
        "icon": "code",
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      }
    ],
    "learning_resources": [
      {
        "id": "res_system_design_gaurav",
        "collection_id": "folder_backend_systems",
        "title": "System Design Course for Beginners (Gaurav Sen)",
        "url": "https://www.youtube.com/watch?v=m8Icp_Cid5o",
        "resource_type": "video",
        "description": "Complete high-level architectural walkthrough for scalable backends.",
        "duration": "1h 15m",
        "thumbnail_url": "https://img.youtube.com/vi/m8Icp_Cid5o/maxresdefault.jpg",
        "status": "in_progress",
        "progress_percentage": 45,
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      },
      {
        "id": "res_db_sharding",
        "collection_id": "folder_backend_systems",
        "title": "Database Sharding & Horizontal Partitioning Explained",
        "url": "https://www.youtube.com/watch?v=5faMjKuB9bc",
        "resource_type": "video",
        "description": "Deep dive into database sharding, consistency keys, and failure recovery.",
        "duration": "25m",
        "thumbnail_url": "https://img.youtube.com/vi/5faMjKuB9bc/maxresdefault.jpg",
        "status": "not_started",
        "progress_percentage": 0,
        "created_at": "$nowIso",
        "updated_at": "$nowIso"
      }
    ]
  }
}''';
  }

  Future<void> resetAllData(WidgetRef ref) async {
    await _dbService.clearAllData();
    ref.invalidate(goalsProvider);
    ref.invalidate(tasksProvider);
    ref.invalidate(habitsProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(resourcesProvider);
    ref.invalidate(notesProvider);
    ref.invalidate(recentFocusSessionsProvider);
    ref.invalidate(todayFocusSecondsProvider);
  }

  Future<void> seedStarterData(WidgetRef ref) async {
    await _dbService.seedStarterData();
    ref.invalidate(goalsProvider);
    ref.invalidate(tasksProvider);
    ref.invalidate(habitsProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(resourcesProvider);
    ref.invalidate(notesProvider);
    ref.invalidate(recentFocusSessionsProvider);
    ref.invalidate(todayFocusSecondsProvider);
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
