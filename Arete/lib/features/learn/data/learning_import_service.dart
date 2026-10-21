import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';

class LearningImportPreview {
  final String schemaVersion;
  final String title;
  final int categoriesCount;
  final int goalsCount;
  final int roadmapsCount;
  final int phasesCount;
  final int topicsCount;
  final int primaryProjectsCount;
  final int advancedAiProjectsCount;
  final int dsaProblemsCount;
  final int knownSkillsCount;
  final List<String> categoryTitles;
  final List<String> primaryProjectNames;

  const LearningImportPreview({
    required this.schemaVersion,
    required this.title,
    required this.categoriesCount,
    required this.goalsCount,
    required this.roadmapsCount,
    required this.phasesCount,
    required this.topicsCount,
    required this.primaryProjectsCount,
    required this.advancedAiProjectsCount,
    required this.dsaProblemsCount,
    required this.knownSkillsCount,
    required this.categoryTitles,
    required this.primaryProjectNames,
  });
}

class LearningImportResult {
  final bool success;
  final String message;
  final int categoriesImported;
  final int roadmapsImported;
  final int phasesImported;
  final int topicsImported;
  final int projectsImported;
  final int dsaProblemsImported;

  const LearningImportResult({
    required this.success,
    required this.message,
    this.categoriesImported = 0,
    this.roadmapsImported = 0,
    this.phasesImported = 0,
    this.topicsImported = 0,
    this.projectsImported = 0,
    this.dsaProblemsImported = 0,
  });
}

class LearningImportService {
  final DatabaseService _dbService;

  LearningImportService([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  static const String defaultAssetPath = 'assets/data/arete_learning_import_organized.json';

  Future<String?> loadDefaultAssetJsonString() async {
    try {
      return await rootBundle.loadString(defaultAssetPath);
    } catch (_) {
      return null;
    }
  }

  bool validateJson(Map<String, dynamic> json) {
    final schema = json['schema_version'];
    final exportType = json['export_type'];
    final categories = json['learning_categories'];

    if (schema != '2.0.0' && schema != '2.0') return false;
    if (exportType != 'arete_learning_import') return false;
    if (categories is! Map || categories.isEmpty) return false;

    return true;
  }

  LearningImportPreview inspectImport(Map<String, dynamic> json) {
    final schema = json['schema_version']?.toString() ?? '2.0.0';
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    final title = metadata['title']?.toString() ?? 'Organized Learning Data';

    final categoriesMap = json['learning_categories'] as Map<String, dynamic>? ?? {};
    final categoryTitles = <String>[];
    int goalsCount = 0;
    int roadmapsCount = 0;
    int phasesCount = 0;
    int topicsCount = 0;

    for (final entry in categoriesMap.entries) {
      final cat = entry.value as Map<String, dynamic>? ?? {};
      final catTitle = cat['title']?.toString() ?? entry.key;
      categoryTitles.add(catTitle);

      final goals = cat['goals'] as List? ?? [];
      goalsCount += goals.length;

      final roadmaps = cat['roadmaps'] as List? ?? [];
      roadmapsCount += roadmaps.length;
      for (final r in roadmaps) {
        final rMap = r as Map<String, dynamic>? ?? {};
        final phases = rMap['phases'] as List? ?? [];
        phasesCount += phases.length;
        for (final p in phases) {
          final pMap = p as Map<String, dynamic>? ?? {};
          final topics = pMap['topics'] as List? ?? [];
          topicsCount += topics.length;
        }
      }
    }

    final projectLearning = json['project_learning'] as Map<String, dynamic>? ?? {};
    final primaryProjects = projectLearning['primary_projects'] as List? ?? [];
    final advancedAiProjects = projectLearning['advanced_ai_systems'] as List? ?? [];
    final primaryNames = primaryProjects
        .map((p) => (p as Map<String, dynamic>?)?['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    // DSA Practice
    int dsaCount = 0;
    final dsaCat = categoriesMap['problem_solving_and_dsa'] as Map<String, dynamic>?;
    final dsaRoadmaps = dsaCat?['roadmaps'] as List? ?? [];
    if (dsaRoadmaps.isNotEmpty) {
      final firstDsa = dsaRoadmaps.first as Map<String, dynamic>? ?? {};
      final progress = firstDsa['current_progress'] as Map<String, dynamic>? ?? {};
      final problems = progress['two_pointer_practice'] as List? ?? [];
      dsaCount = problems.length;
    }

    // Profile skills
    final profile = json['profile'] as Map<String, dynamic>? ?? {};
    final knownSkills = profile['current_or_known_skills'] as List? ?? [];

    return LearningImportPreview(
      schemaVersion: schema,
      title: title,
      categoriesCount: categoriesMap.length,
      goalsCount: goalsCount,
      roadmapsCount: roadmapsCount,
      phasesCount: phasesCount,
      topicsCount: topicsCount,
      primaryProjectsCount: primaryProjects.length,
      advancedAiProjectsCount: advancedAiProjects.length,
      dsaProblemsCount: dsaCount,
      knownSkillsCount: knownSkills.length,
      categoryTitles: categoryTitles,
      primaryProjectNames: primaryNames,
    );
  }

  Future<LearningImportResult> executeImport(
    Map<String, dynamic> json, {
    bool preserveUserProgress = true,
  }) async {
    if (!validateJson(json)) {
      return const LearningImportResult(
        success: false,
        message: 'Invalid schema version or missing learning categories in import data.',
      );
    }

    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();

    int categoriesImported = 0;
    int roadmapsImported = 0;
    int phasesImported = 0;
    int topicsImported = 0;
    int projectsImported = 0;
    int dsaImported = 0;

    try {
      await db.transaction((txn) async {
        // Step 1: Pre-fetch existing completed topic IDs & notes to preserve user checkmarks
        final existingCompletedTopicIds = <String, ({int isCompleted, String? notes})>{};
        if (preserveUserProgress) {
          final existingTopics = await txn.query(AppTables.learningRoadmapTopics);
          for (final row in existingTopics) {
            final id = row['id'] as String;
            final isCompleted = (row['is_completed'] as num?)?.toInt() ?? 0;
            final notes = row['notes'] as String?;
            if (isCompleted == 1 || notes != null) {
              existingCompletedTopicIds[id] = (isCompleted: isCompleted, notes: notes);
            }
          }
        }

        // Step 2: Import Profile
        final profileMap = json['profile'] as Map<String, dynamic>?;
        if (profileMap != null) {
          final careerDir = profileMap['career_direction'] as Map<String, dynamic>? ?? {};
          final prefMethod = profileMap['preferred_learning_method'] as Map<String, dynamic>? ?? {};

          await txn.insert(
            AppTables.learningProfile,
            {
              'id': 'user_profile',
              'primary_goal': profileMap['primary_goal'] ?? '',
              'target_horizon': profileMap['target_horizon'] ?? '',
              'career_title': careerDir['working_title'] ?? 'Software Engineer',
              'career_emphasis': jsonEncode(careerDir['emphasis'] ?? []),
              'known_skills': jsonEncode(profileMap['current_or_known_skills'] ?? []),
              'learning_skills': jsonEncode(['Two Pointers', 'Go Backend', 'PostgreSQL Internals']),
              'planned_skills': jsonEncode(['System Design', 'AI Engineering', 'Kubernetes']),
              'learning_style': prefMethod['style'] ?? '',
              'theory_practice_ratio': prefMethod['theory_to_practice'] ?? '',
              'learning_workflow': jsonEncode(prefMethod['workflow'] ?? []),
              'learning_preferences': jsonEncode(prefMethod['preferences'] ?? []),
              'hackathon_rhythm': jsonEncode(prefMethod['preferred_hackathon_rhythm'] ?? []),
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Step 3: Import Categories, Goals, Roadmaps, Phases, and Topics
        final categoriesMap = json['learning_categories'] as Map<String, dynamic>? ?? {};
        int catOrder = 0;

        for (final entry in categoriesMap.entries) {
          final catKey = entry.key;
          final catData = entry.value as Map<String, dynamic>? ?? {};
          final catTitle = catData['title'] as String? ?? catKey;

          await txn.insert(
            AppTables.learningCategories,
            {
              'id': catKey,
              'title': catTitle,
              'icon': catKey,
              'color': _getCategoryColor(catKey),
              'display_order': catOrder++,
              'created_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          categoriesImported++;

          // Goals
          final goalsList = catData['goals'] as List? ?? [];
          for (final g in goalsList) {
            final gMap = g as Map<String, dynamic>? ?? {};
            final goalId = gMap['id'] as String? ?? 'goal-$catKey';
            await txn.insert(
              AppTables.goals,
              {
                'id': goalId,
                'title': gMap['title'] as String? ?? 'Master $catTitle',
                'description': gMap['description'] as String?,
                'color': _getCategoryColor(catKey),
                'created_at': now,
                'updated_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }

          // Roadmaps
          final roadmapsList = catData['roadmaps'] as List? ?? [];
          int roadmapOrder = 0;
          for (final r in roadmapsList) {
            final rMap = r as Map<String, dynamic>? ?? {};
            final rId = rMap['id'] as String? ?? 'roadmap-$catKey-$roadmapOrder';
            final rTitle = rMap['title'] as String? ?? '$catTitle Roadmap';
            final rDesc = rMap['description'] as String?;
            final rStatus = rMap['status'] as String? ?? 'not_started';
            final rLang = rMap['language'] as String? ?? rMap['primary_language'] as String?;
            final rRules = rMap['learning_rules'] as List? ?? [];

            await txn.insert(
              AppTables.learningRoadmaps,
              {
                'id': rId,
                'category_id': catKey,
                'title': rTitle,
                'description': rDesc,
                'status': rStatus,
                'primary_language': rLang,
                'learning_rules': jsonEncode(rRules),
                'display_order': roadmapOrder++,
                'created_at': now,
                'updated_at': now,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            roadmapsImported++;

            // Phases & Topics
            final phasesList = rMap['phases'] as List? ?? [];
            int phaseOrder = 0;
            for (final p in phasesList) {
              final pMap = p as Map<String, dynamic>? ?? {};
              final pTitle = pMap['title'] as String? ?? 'Phase ${phaseOrder + 1}';
              final pId = 'phase-$rId-$phaseOrder';

              await txn.insert(
                AppTables.learningRoadmapPhases,
                {
                  'id': pId,
                  'roadmap_id': rId,
                  'title': pTitle,
                  'phase_order': phaseOrder++,
                  'created_at': now,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              phasesImported++;

              // Topics
              final topicsList = pMap['topics'] as List? ?? [];
              int topicOrder = 0;
              for (final t in topicsList) {
                final tTitle = t.toString();
                final tId = 'topic-$pId-$topicOrder';

                // Check preserved state
                final preserved = existingCompletedTopicIds[tId];
                final isDone = preserved?.isCompleted ?? 0;
                final existingNotes = preserved?.notes;

                await txn.insert(
                  AppTables.learningRoadmapTopics,
                  {
                    'id': tId,
                    'phase_id': pId,
                    'roadmap_id': rId,
                    'title': tTitle,
                    'topic_order': topicOrder++,
                    'is_completed': isDone,
                    'notes': existingNotes,
                    'completed_at': isDone == 1 ? now : null,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
                topicsImported++;
              }
            }

            // Special DSA Problem Extraction
            if (catKey == 'problem_solving_and_dsa') {
              final currentProg = rMap['current_progress'] as Map<String, dynamic>? ?? {};
              final twoPointerProblems = currentProg['two_pointer_practice'] as List? ?? [];
              int probOrder = 0;
              for (final prob in twoPointerProblems) {
                final pTitle = prob.toString();
                final probId = 'dsa-${pTitle.toLowerCase().replaceAll(' ', '-')}';

                await txn.insert(
                  AppTables.dsaProblems,
                  {
                    'id': probId,
                    'title': pTitle,
                    'pattern': 'Two Pointers',
                    'difficulty': _inferDsaDifficulty(pTitle),
                    'status': _inferDsaStatus(pTitle),
                    'intuition': 'Maintain two pointers (left/right or slow/fast) based on sorted order or in-place boundary.',
                    'approach': 'Start with brute-force intuition, establish loop invariants, and dry run edge cases.',
                    'display_order': probOrder++,
                    'created_at': now,
                    'updated_at': now,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
                dsaImported++;
              }
            }
          }
        }

        // Step 4: Import Projects (Primary & Advanced AI Systems)
        final projectLearning = json['project_learning'] as Map<String, dynamic>? ?? {};
        final primaryProjects = projectLearning['primary_projects'] as List? ?? [];
        for (final p in primaryProjects) {
          final pMap = p as Map<String, dynamic>? ?? {};
          final pName = pMap['name'] as String? ?? 'Untitled Project';
          final pId = 'proj-primary-${pMap['order'] ?? pName.toLowerCase().replaceAll(' ', '-')}';

          String? checkpoint;
          final curProg = pMap['current_progress'] as Map<String, dynamic>?;
          if (curProg != null) {
            checkpoint = curProg['checkpoint'] as String?;
          }

          await txn.insert(
            AppTables.learningProjects,
            {
              'id': pId,
              'category_id': 'backend_engineering',
              'roadmap_id': 'roadmap-backend-production-systems',
              'project_group': 'primary',
              'name': pName,
              'description': pMap['description'] as String?,
              'architecture': pMap['architecture'] as String? ?? 'Modular Monolith',
              'status': pMap['status'] as String? ?? 'planned',
              'project_order': (pMap['order'] as num?)?.toInt() ?? 0,
              'tech_stack': jsonEncode(pMap['stack'] ?? ['Go', 'Gin', 'PostgreSQL']),
              'domain_areas': jsonEncode(pMap['domain_areas'] ?? []),
              'learning_focus': jsonEncode(pMap['learning_focus'] ?? []),
              'checkpoint_notes': checkpoint,
              'created_at': now,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          projectsImported++;
        }

        // Advanced AI Systems
        final advancedAiProjects = projectLearning['advanced_ai_systems'] as List? ?? [];
        int advOrder = 0;
        for (final p in advancedAiProjects) {
          final pMap = p as Map<String, dynamic>? ?? {};
          final pName = pMap['name'] as String? ?? 'AI System';
          final pId = 'proj-ai-$advOrder';

          await txn.insert(
            AppTables.learningProjects,
            {
              'id': pId,
              'category_id': 'ai_engineering',
              'roadmap_id': 'roadmap-ai-engineering-systems',
              'project_group': 'advanced_ai',
              'name': pName,
              'description': pMap['description'] as String?,
              'architecture': 'Event-Driven Distributed System',
              'status': pMap['status'] as String? ?? 'planned',
              'project_order': advOrder++,
              'tech_stack': jsonEncode(['Go', 'Python', 'PostgreSQL', 'pgvector', 'Docker']),
              'domain_areas': jsonEncode(['AI Infrastructure', 'Hybrid Search', 'Evaluation']),
              'learning_focus': jsonEncode(['Latency', 'Quality', 'Security', 'Reliability']),
              'checkpoint_notes': null,
              'created_at': now,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          projectsImported++;
        }
      });

      return LearningImportResult(
        success: true,
        message: 'Successfully imported $categoriesImported categories, $roadmapsImported roadmaps ($topicsImported topics), and $projectsImported learning projects.',
        categoriesImported: categoriesImported,
        roadmapsImported: roadmapsImported,
        phasesImported: phasesImported,
        topicsImported: topicsImported,
        projectsImported: projectsImported,
        dsaProblemsImported: dsaImported,
      );
    } catch (e) {
      return LearningImportResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }

  static String _getCategoryColor(String catKey) {
    switch (catKey) {
      case 'computer_science':
        return '#2A4E35';
      case 'problem_solving_and_dsa':
        return '#FF7A59';
      case 'backend_engineering':
        return '#1C3B4D';
      case 'system_design':
        return '#5A2D00';
      case 'ai_engineering':
        return '#7B2CBF';
      case 'cloud_and_devops':
        return '#0F4C5C';
      case 'database_engineering':
        return '#E36414';
      default:
        return '#2A4E35';
    }
  }

  static String _inferDsaDifficulty(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('three sum')) return 'Medium';
    if (lower.contains('two sum')) return 'Easy';
    if (lower.contains('remove') || lower.contains('reverse') || lower.contains('valid')) return 'Easy';
    return 'Medium';
  }

  static String _inferDsaStatus(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('two sum') || lower.contains('three sum')) return 'attempted';
    if (lower.contains('remove') || lower.contains('valid palindrome')) return 'solved';
    return 'not_started';
  }
}

final learningImportServiceProvider = Provider<LearningImportService>((ref) {
  return LearningImportService();
});
