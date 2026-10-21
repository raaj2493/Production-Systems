import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../domain/learning_collection_model.dart';
import '../domain/learning_resource_model.dart';

class LearnRepository {
  final DatabaseService _dbService;

  LearnRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  // --- Collections ---
  Future<List<LearningCollection>> getAllCollections() async {
    final db = await _dbService.database;

    // Fetch resources to calculate total duration in minutes per collection
    final resources = await getAllResources();
    final durationByCollection = <String, int>{};
    for (final r in resources) {
      if (r.collectionId != null && r.durationMinutes > 0) {
        durationByCollection[r.collectionId!] =
            (durationByCollection[r.collectionId!] ?? 0) + r.durationMinutes;
      }
    }

    // Ensure curated folders exist if missing
    final curatedCheck = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM ${AppTables.learningCollections} WHERE id = 'folder_backend_systems'"),
    ) ?? 0;
    if (curatedCheck == 0) {
      await ensureDefaultFoldersAndResources();
    }

    final results = await db.rawQuery('''
      SELECT 
        c.*,
        COUNT(r.id) AS total_resources,
        SUM(CASE WHEN r.status = 'completed' THEN 1 ELSE 0 END) AS completed_resources
      FROM ${AppTables.learningCollections} c
      LEFT JOIN ${AppTables.learningResources} r ON r.collection_id = c.id
      GROUP BY c.id
      ORDER BY c.created_at ASC
    ''');

    return results.map((row) {
      final id = row['id'] as String;
      final total = (row['total_resources'] as num?)?.toInt() ?? 0;
      final completed = (row['completed_resources'] as num?)?.toInt() ?? 0;
      final totalDuration = durationByCollection[id] ?? 0;

      return LearningCollection.fromMap(
        row,
        totalResources: total,
        completedResources: completed,
        totalDurationMinutes: totalDuration,
      );
    }).toList();
  }

  Future<void> createCollection(LearningCollection collection) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.learningCollections,
      collection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCollection(LearningCollection collection) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.learningCollections,
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
  }

  Future<void> deleteCollection(String id) async {
    final db = await _dbService.database;
    await db.delete(
      AppTables.learningCollections,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Resources ---
  Future<List<LearningResource>> getAllResources({String? collectionId}) async {
    final db = await _dbService.database;
    String whereClause = '';
    List<dynamic> args = [];

    if (collectionId != null) {
      whereClause = 'WHERE r.collection_id = ?';
      args = [collectionId];
    }

    final results = await db.rawQuery('''
      SELECT 
        r.*,
        c.title AS collection_title
      FROM ${AppTables.learningResources} r
      LEFT JOIN ${AppTables.learningCollections} c ON c.id = r.collection_id
      $whereClause
      ORDER BY r.created_at DESC
    ''', args);

    return results.map((r) => LearningResource.fromMap(r)).toList();
  }

  Future<void> createResource(LearningResource resource) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.learningResources,
      resource.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateResource(LearningResource resource) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.learningResources,
      resource.toMap(),
      where: 'id = ?',
      whereArgs: [resource.id],
    );
  }

  Future<void> moveResourceToCollection(String resourceId, String? targetCollectionId) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.learningResources,
      {
        'collection_id': targetCollectionId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [resourceId],
    );
  }

  Future<void> updateResourceTitle(String resourceId, String newTitle) async {
    final db = await _dbService.database;
    await db.update(
      AppTables.learningResources,
      {
        'title': newTitle,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [resourceId],
    );
  }

  Future<void> updateProgress(String id, int percentage) async {
    final db = await _dbService.database;
    final clamped = percentage.clamp(0, 100);
    ResourceStatus status;
    if (clamped == 100) {
      status = ResourceStatus.completed;
    } else if (clamped > 0) {
      status = ResourceStatus.inProgress;
    } else {
      status = ResourceStatus.notStarted;
    }

    await db.update(
      AppTables.learningResources,
      {
        'progress_percentage': clamped,
        'status': status.dbValue,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteResource(String id) async {
    final db = await _dbService.database;
    await db.delete(
      AppTables.learningResources,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Seeds the default 4 custom folders and curated YouTube resources
  Future<void> ensureDefaultFoldersAndResources() async {
    final db = await _dbService.database;
    final now = DateTime.now();

    // 1. Backend & System Design
    final backendFolder = LearningCollection(
      id: 'folder_backend_systems',
      title: 'Backend & System Design',
      description: 'Distributed architectures, scaling, caching, and database design patterns.',
      color: '#D2E8D4', // Pastel Sage
      icon: 'dns',
      createdAt: now,
      updatedAt: now,
    );

    // 2. DSA & Algorithms
    final dsaFolder = LearningCollection(
      id: 'folder_dsa_algorithms',
      title: 'DSA & Algorithms',
      description: 'Blind 75/150 patterns, dynamic programming, graphs, and system interviews.',
      color: '#FFDDB3', // Pastel Warm Amber
      icon: 'code',
      createdAt: now.add(const Duration(milliseconds: 10)),
      updatedAt: now.add(const Duration(milliseconds: 10)),
    );

    // 3. Mindset & Focus
    final mindsetFolder = LearningCollection(
      id: 'folder_mindset_focus',
      title: 'Mindset & Focus',
      description: 'Neuroscience of attention, deep work routines, and distraction shielding.',
      color: '#E8DEF8', // Pastel Lavender
      icon: 'psychology',
      createdAt: now.add(const Duration(milliseconds: 20)),
      updatedAt: now.add(const Duration(milliseconds: 20)),
    );

    // 4. Personal Growth
    final growthFolder = LearningCollection(
      id: 'folder_personal_growth',
      title: 'Personal Growth',
      description: 'Atomic habits, mental resilience, energy management, and stoic philosophy.',
      color: '#FDE8E1', // Soft Coral Peach
      icon: 'spa',
      createdAt: now.add(const Duration(milliseconds: 30)),
      updatedAt: now.add(const Duration(milliseconds: 30)),
    );

    await db.insert(
      AppTables.learningCollections,
      backendFolder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      AppTables.learningCollections,
      dsaFolder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      AppTables.learningCollections,
      mindsetFolder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      AppTables.learningCollections,
      growthFolder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // Seed resources if empty
    final resourcesCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${AppTables.learningResources}'),
    ) ?? 0;

    if (resourcesCount > 0) return;

    // Seed resources
    final sampleResources = [
      LearningResource(
        id: const Uuid().v4(),
        collectionId: backendFolder.id,
        title: 'System Design Course for Beginners (Gaurav Sen)',
        url: 'https://www.youtube.com/watch?v=m8Icp_Cid5o',
        resourceType: ResourceType.video,
        description: 'Complete high-level architectural walkthrough for scalable backends.',
        duration: '1h 15m',
        thumbnailUrl: 'https://img.youtube.com/vi/m8Icp_Cid5o/maxresdefault.jpg',
        status: ResourceStatus.inProgress,
        progressPercentage: 45,
        createdAt: now.add(const Duration(minutes: 1)),
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
      LearningResource(
        id: const Uuid().v4(),
        collectionId: backendFolder.id,
        title: 'Database Sharding & Horizontal Partitioning Explained',
        url: 'https://www.youtube.com/watch?v=5faMjKuB9bc',
        resourceType: ResourceType.video,
        description: 'Deep dive into database sharding, consistency keys, and failure recovery.',
        duration: '25m',
        thumbnailUrl: 'https://img.youtube.com/vi/5faMjKuB9bc/maxresdefault.jpg',
        status: ResourceStatus.notStarted,
        progressPercentage: 0,
        createdAt: now.add(const Duration(minutes: 2)),
        updatedAt: now.add(const Duration(minutes: 2)),
      ),
      LearningResource(
        id: const Uuid().v4(),
        collectionId: dsaFolder.id,
        title: 'NeetCode - Blind 75 / 150 LeetCode Algorithms Playlist',
        url: 'https://www.youtube.com/playlist?list=PLot-Xpze53ldVwtstag2TL4HQhAnC8ATf',
        resourceType: ResourceType.video,
        description: 'Core problem-solving patterns covering two pointers, trees, and graphs.',
        duration: '3h 40m',
        thumbnailUrl: 'https://img.youtube.com/vi/KLlXCFG5TnA/maxresdefault.jpg',
        status: ResourceStatus.inProgress,
        progressPercentage: 60,
        createdAt: now.add(const Duration(minutes: 3)),
        updatedAt: now.add(const Duration(minutes: 3)),
      ),
      LearningResource(
        id: const Uuid().v4(),
        collectionId: dsaFolder.id,
        title: 'Dynamic Programming - Learn to Solve Any DP Problem',
        url: 'https://www.youtube.com/watch?v=oBt53YbR9Kk',
        resourceType: ResourceType.video,
        description: 'Memoization, tabulation, and recursive breakdown techniques.',
        duration: '5h 10m',
        thumbnailUrl: 'https://img.youtube.com/vi/oBt53YbR9Kk/maxresdefault.jpg',
        status: ResourceStatus.notStarted,
        progressPercentage: 0,
        createdAt: now.add(const Duration(minutes: 4)),
        updatedAt: now.add(const Duration(minutes: 4)),
      ),
      LearningResource(
        id: const Uuid().v4(),
        collectionId: mindsetFolder.id,
        title: 'Dr. Andrew Huberman: Master Focus & Deep Learning Protocols',
        url: 'https://www.youtube.com/watch?v=LG53Vxum0as',
        resourceType: ResourceType.video,
        description: 'Dopamine cycles, ultradian 90-minute focus sessions, and neuroplasticity.',
        duration: '2h 15m',
        thumbnailUrl: 'https://img.youtube.com/vi/LG53Vxum0as/maxresdefault.jpg',
        status: ResourceStatus.completed,
        progressPercentage: 100,
        createdAt: now.add(const Duration(minutes: 5)),
        updatedAt: now.add(const Duration(minutes: 5)),
      ),
      LearningResource(
        id: const Uuid().v4(),
        collectionId: growthFolder.id,
        title: 'Atomic Habits Full Breakdown: Tiny Changes, Remarkable Results',
        url: 'https://www.youtube.com/watch?v=PZ7lDrwYdZc',
        resourceType: ResourceType.video,
        description: 'The 4 laws of behavior change applied to daily craft and disciplined work.',
        duration: '45m',
        thumbnailUrl: 'https://img.youtube.com/vi/PZ7lDrwYdZc/maxresdefault.jpg',
        status: ResourceStatus.completed,
        progressPercentage: 100,
        createdAt: now.add(const Duration(minutes: 6)),
        updatedAt: now.add(const Duration(minutes: 6)),
      ),
    ];

    for (final res in sampleResources) {
      await createResource(res);
    }
  }
}

final learnRepositoryProvider = Provider<LearnRepository>((ref) {
  return LearnRepository();
});

class CollectionsNotifier
    extends StateNotifier<AsyncValue<List<LearningCollection>>> {
  final LearnRepository _repository;

  CollectionsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCollections();
  }

  Future<void> loadCollections() async {
    try {
      final list = await _repository.getAllCollections();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCollection(LearningCollection collection) async {
    await _repository.createCollection(collection);
    await loadCollections();
  }

  Future<void> updateCollection(LearningCollection collection) async {
    await _repository.updateCollection(collection);
    await loadCollections();
  }

  Future<void> deleteCollection(String id) async {
    await _repository.deleteCollection(id);
    await loadCollections();
  }
}

final collectionsProvider = StateNotifierProvider<CollectionsNotifier,
    AsyncValue<List<LearningCollection>>>((ref) {
  final repo = ref.watch(learnRepositoryProvider);
  return CollectionsNotifier(repo);
});

class ResourcesNotifier
    extends StateNotifier<AsyncValue<List<LearningResource>>> {
  final LearnRepository _repository;
  final Ref _ref;

  ResourcesNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    loadResources();
  }

  Future<void> loadResources() async {
    try {
      final list = await _repository.getAllResources();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> addResource(LearningResource resource) async {
    await _repository.createResource(resource);
    await loadResources();
    _ref.invalidate(collectionsProvider);
  }

  Future<void> updateResource(LearningResource resource) async {
    await _repository.updateResource(resource);
    await loadResources();
    _ref.invalidate(collectionsProvider);
  }

  Future<void> moveResource(String resourceId, String? targetCollectionId) async {
    await _repository.moveResourceToCollection(resourceId, targetCollectionId);
    await loadResources();
    _ref.invalidate(collectionsProvider);
  }

  Future<void> updateTitle(String resourceId, String newTitle) async {
    await _repository.updateResourceTitle(resourceId, newTitle);
    await loadResources();
    _ref.invalidate(collectionsProvider);
  }

  Future<void> updateProgress(String id, int percentage) async {
    await _repository.updateProgress(id, percentage);
    await loadResources();
    _ref.invalidate(collectionsProvider);
  }

  Future<void> deleteResource(String id) async {
    await _repository.deleteResource(id);
    await loadResources();
    _ref.invalidate(collectionsProvider);
  }
}

final resourcesProvider = StateNotifierProvider<ResourcesNotifier,
    AsyncValue<List<LearningResource>>>((ref) {
  final repo = ref.watch(learnRepositoryProvider);
  return ResourcesNotifier(repo, ref);
});
