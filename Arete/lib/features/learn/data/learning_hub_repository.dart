import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../domain/dsa_problem_model.dart';
import '../domain/learning_category_model.dart';
import '../domain/learning_profile_model.dart';
import '../domain/learning_project_model.dart';
import '../domain/learning_roadmap_model.dart';

class LearningHubRepository {
  final DatabaseService _dbService;

  LearningHubRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  // --- Categories ---
  Future<List<LearningCategory>> getAllCategories() async {
    final db = await _dbService.database;
    final results = await db.rawQuery('''
      SELECT 
        c.*,
        COUNT(DISTINCT r.id) AS total_roadmaps,
        COUNT(DISTINCT p.id) AS total_projects,
        COUNT(DISTINCT t.id) AS total_topics,
        SUM(CASE WHEN t.is_completed = 1 THEN 1 ELSE 0 END) AS completed_topics
      FROM ${AppTables.learningCategories} c
      LEFT JOIN ${AppTables.learningRoadmaps} r ON r.category_id = c.id
      LEFT JOIN ${AppTables.learningProjects} p ON p.category_id = c.id
      LEFT JOIN ${AppTables.learningRoadmapTopics} t ON t.roadmap_id = r.id
      GROUP BY c.id
      ORDER BY c.display_order ASC
    ''');

    return results.map((row) {
      return LearningCategory.fromMap(
        row,
        totalRoadmaps: (row['total_roadmaps'] as num?)?.toInt() ?? 0,
        totalProjects: (row['total_projects'] as num?)?.toInt() ?? 0,
        totalTopics: (row['total_topics'] as num?)?.toInt() ?? 0,
        completedTopics: (row['completed_topics'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<LearningCategory?> getCategoryById(String id) async {
    final categories = await getAllCategories();
    return categories.where((c) => c.id == id).firstOrNull;
  }

  Future<void> createCategory(LearningCategory category) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.learningCategories,
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCategory(LearningCategory category) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.learningCategories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _dbService.database;
    await db.delete(
      AppTables.learningCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Roadmaps ---
  Future<List<LearningRoadmap>> getAllRoadmaps({String? categoryId}) async {
    final db = await _dbService.database;
    String whereClause = '';
    List<dynamic> args = [];
    if (categoryId != null) {
      whereClause = 'WHERE r.category_id = ?';
      args = [categoryId];
    }

    final results = await db.rawQuery('''
      SELECT 
        r.*,
        c.title AS category_title,
        COUNT(DISTINCT t.id) AS total_topics,
        SUM(CASE WHEN t.is_completed = 1 THEN 1 ELSE 0 END) AS completed_topics
      FROM ${AppTables.learningRoadmaps} r
      LEFT JOIN ${AppTables.learningCategories} c ON c.id = r.category_id
      LEFT JOIN ${AppTables.learningRoadmapTopics} t ON t.roadmap_id = r.id
      $whereClause
      GROUP BY r.id
      ORDER BY r.display_order ASC
    ''', args);

    return results.map((row) {
      return LearningRoadmap.fromMap(
        row,
        totalTopicsCount: (row['total_topics'] as num?)?.toInt() ?? 0,
        completedTopicsCount: (row['completed_topics'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<LearningRoadmap?> getRoadmapById(String id) async {
    final db = await _dbService.database;
    final roadmapResults = await db.rawQuery('''
      SELECT 
        r.*,
        c.title AS category_title
      FROM ${AppTables.learningRoadmaps} r
      LEFT JOIN ${AppTables.learningCategories} c ON c.id = r.category_id
      WHERE r.id = ?
    ''', [id]);

    if (roadmapResults.isEmpty) return null;
    final row = roadmapResults.first;

    // Fetch phases
    final phasesResults = await db.query(
      AppTables.learningRoadmapPhases,
      where: 'roadmap_id = ?',
      whereArgs: [id],
      orderBy: 'phase_order ASC',
    );

    // Fetch topics
    final topicsResults = await db.query(
      AppTables.learningRoadmapTopics,
      where: 'roadmap_id = ?',
      whereArgs: [id],
      orderBy: 'topic_order ASC',
    );

    final topicsMap = <String, List<RoadmapTopic>>{};
    for (final tRow in topicsResults) {
      final topic = RoadmapTopic.fromMap(tRow);
      topicsMap.putIfAbsent(topic.phaseId, () => []).add(topic);
    }

    final phases = phasesResults.map((pRow) {
      final pId = pRow['id'] as String;
      return RoadmapPhase.fromMap(pRow, topics: topicsMap[pId] ?? []);
    }).toList();

    return LearningRoadmap.fromMap(row, phases: phases);
  }

  Future<void> toggleTopicCompletion(String topicId, bool isCompleted) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.learningRoadmapTopics,
      {
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  Future<void> updateTopicNotes(String topicId, String notes) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.learningRoadmapTopics,
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [topicId],
    );
  }

  // --- DSA Problems ---
  Future<List<DsaProblem>> getAllDsaProblems({String? pattern, String? status}) async {
    final db = await _dbService.database;
    List<String> whereConditions = [];
    List<dynamic> args = [];

    if (pattern != null) {
      whereConditions.add('pattern = ?');
      args.add(pattern);
    }
    if (status != null) {
      whereConditions.add('status = ?');
      args.add(status);
    }

    final where = whereConditions.isNotEmpty ? 'WHERE ${whereConditions.join(' AND ')}' : '';
    final results = await db.rawQuery('''
      SELECT * FROM ${AppTables.dsaProblems}
      $where
      ORDER BY display_order ASC
    ''', args);

    return results.map((r) => DsaProblem.fromMap(r)).toList();
  }

  Future<void> updateDsaProblem(DsaProblem problem) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.dsaProblems,
      problem.toMap(),
      where: 'id = ?',
      whereArgs: [problem.id],
    );
  }

  // --- Projects ---
  Future<List<LearningProject>> getAllProjects({String? projectGroup, String? categoryId}) async {
    final db = await _dbService.database;
    List<String> whereConditions = [];
    List<dynamic> args = [];

    if (projectGroup != null) {
      whereConditions.add('p.project_group = ?');
      args.add(projectGroup);
    }
    if (categoryId != null) {
      whereConditions.add('p.category_id = ?');
      args.add(categoryId);
    }

    final where = whereConditions.isNotEmpty ? 'WHERE ${whereConditions.join(' AND ')}' : '';
    final results = await db.rawQuery('''
      SELECT 
        p.*,
        c.title AS category_title
      FROM ${AppTables.learningProjects} p
      LEFT JOIN ${AppTables.learningCategories} c ON c.id = p.category_id
      $where
      ORDER BY p.project_order ASC
    ''', args);

    return results.map((r) => LearningProject.fromMap(r)).toList();
  }

  Future<LearningProject?> getProjectById(String id) async {
    final projects = await getAllProjects();
    return projects.where((p) => p.id == id).firstOrNull;
  }

  Future<void> updateProject(LearningProject project) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.learningProjects,
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  // --- Learning Profile ---
  Future<LearningProfile?> getLearningProfile() async {
    final db = await _dbService.database;
    final results = await db.query(
      AppTables.learningProfile,
      where: 'id = ?',
      whereArgs: ['user_profile'],
    );
    if (results.isEmpty) return null;
    return LearningProfile.fromMap(results.first);
  }

  Future<void> saveLearningProfile(LearningProfile profile) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.learningProfile,
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

// Riverpod Providers
final learningHubRepositoryProvider = Provider<LearningHubRepository>((ref) {
  return LearningHubRepository();
});

final learningCategoriesProvider = FutureProvider<List<LearningCategory>>((ref) async {
  final repo = ref.watch(learningHubRepositoryProvider);
  return repo.getAllCategories();
});

final learningRoadmapsProvider = FutureProvider<List<LearningRoadmap>>((ref) async {
  final repo = ref.watch(learningHubRepositoryProvider);
  return repo.getAllRoadmaps();
});

final dsaProblemsProvider = FutureProvider<List<DsaProblem>>((ref) async {
  final repo = ref.watch(learningHubRepositoryProvider);
  return repo.getAllDsaProblems();
});

final learningProjectsProvider = FutureProvider<List<LearningProject>>((ref) async {
  final repo = ref.watch(learningHubRepositoryProvider);
  return repo.getAllProjects();
});

final learningProfileProvider = FutureProvider<LearningProfile?>((ref) async {
  final repo = ref.watch(learningHubRepositoryProvider);
  return repo.getLearningProfile();
});
