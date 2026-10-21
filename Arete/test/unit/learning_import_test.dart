import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arete/core/database/database_service.dart';
import 'package:arete/features/learn/data/learning_hub_repository.dart';
import 'package:arete/features/learn/data/learning_import_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Learning Import & Hub Integration Tests', () {
    late DatabaseService dbService;
    late LearningImportService importService;
    late LearningHubRepository hubRepo;
    late Map<String, dynamic> sourceJson;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initDatabase(inMemory: true);
      importService = LearningImportService(dbService);
      hubRepo = LearningHubRepository(dbService);

      final file = File('assets/data/arete_learning_import_organized.json');
      expect(file.existsSync(), isTrue, reason: 'Asset JSON must exist');
      sourceJson = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    tearDown(() async {
      await dbService.close();
    });

    test('1. Validates source JSON schema and required sections', () {
      expect(importService.validateJson(sourceJson), isTrue);

      final invalidJson = {'schema_version': '1.0'};
      expect(importService.validateJson(invalidJson), isFalse);
    });

    test('2. Inspects import content and produces accurate preview metrics', () {
      final preview = importService.inspectImport(sourceJson);

      expect(preview.schemaVersion, equals('2.0.0'));
      expect(preview.categoriesCount, equals(7));
      expect(preview.goalsCount, equals(7));
      expect(preview.roadmapsCount, equals(7));
      expect(preview.phasesCount, equals(61));
      expect(preview.topicsCount, equals(434));
      expect(preview.primaryProjectsCount, equals(8));
      expect(preview.advancedAiProjectsCount, equals(6));
      expect(preview.dsaProblemsCount, equals(7));
      expect(preview.knownSkillsCount, equals(9));
      expect(preview.categoryTitles, containsAll([
        'Computer Science Fundamentals',
        'DSA & Problem Solving',
        'Backend Engineering',
        'System Design',
        'AI Engineering',
        'Cloud & DevOps',
        'Database Engineering',
      ]));
      expect(preview.primaryProjectNames, contains('HeroVerse + TaskFlow'));
    });

    test('3. Safely executes atomic transactional import into SQLite', () async {
      final result = await importService.executeImport(sourceJson);

      expect(result.success, isTrue);
      expect(result.categoriesImported, equals(7));
      expect(result.roadmapsImported, equals(7));
      expect(result.phasesImported, equals(61));
      expect(result.topicsImported, equals(434));
      expect(result.projectsImported, equals(14)); // 8 primary + 6 advanced AI
      expect(result.dsaProblemsImported, equals(7));

      // Verify categories through repository
      final categories = await hubRepo.getAllCategories();
      expect(categories.length, equals(7));
      for (final cat in categories) {
        expect(cat.totalRoadmaps, greaterThan(0));
        expect(cat.totalTopics, greaterThan(0));
      }

      // Verify roadmaps
      final roadmaps = await hubRepo.getAllRoadmaps();
      expect(roadmaps.length, equals(7));
      final dsaRoadmap = await hubRepo.getRoadmapById('roadmap-dsa');
      expect(dsaRoadmap, isNotNull);
      expect(dsaRoadmap!.phases.length, equals(16));
      expect(dsaRoadmap.learningRules.length, equals(10));

      // Verify projects
      final primaryProjects = await hubRepo.getAllProjects(projectGroup: 'primary');
      expect(primaryProjects.length, equals(8));
      expect(primaryProjects.first.name, equals('HeroVerse + TaskFlow'));
      expect(primaryProjects.first.architecture, contains('modular monolith'));
      expect(primaryProjects.first.techStack, contains('Go'));

      final aiProjects = await hubRepo.getAllProjects(projectGroup: 'advanced_ai');
      expect(aiProjects.length, equals(6));
      expect(aiProjects.map((p) => p.name), containsAll(['Pulse', 'Atlas', 'FlowForge', 'CloudForge', 'TraceLab']));

      // Verify DSA Problems
      final dsaProblems = await hubRepo.getAllDsaProblems();
      expect(dsaProblems.length, equals(7));
      expect(dsaProblems.map((p) => p.title), containsAll([
        'Remove Duplicates',
        'Remove Element',
        'Move Zeroes',
        'Valid Palindrome',
        'Reverse String',
        'Two Sum II',
        'Three Sum',
      ]));

      // Verify Profile
      final profile = await hubRepo.getLearningProfile();
      expect(profile, isNotNull);
      expect(profile!.careerTitle, contains('Full Stack Software Engineer'));
      expect(profile.knownSkills.length, equals(9));
      expect(profile.theoryPracticeRatio, contains('20% theory and 80% implementation'));
    });

    test('4. Repeated import is idempotent and does not duplicate records', () async {
      // First import
      await importService.executeImport(sourceJson);

      // Second import
      final secondResult = await importService.executeImport(sourceJson);
      expect(secondResult.success, isTrue);

      final categories = await hubRepo.getAllCategories();
      expect(categories.length, equals(7), reason: 'Should not create duplicate categories');

      final roadmaps = await hubRepo.getAllRoadmaps();
      expect(roadmaps.length, equals(7), reason: 'Should not create duplicate roadmaps');

      final projects = await hubRepo.getAllProjects();
      expect(projects.length, equals(14), reason: 'Should not create duplicate projects');

      final dsaProblems = await hubRepo.getAllDsaProblems();
      expect(dsaProblems.length, equals(7), reason: 'Should not create duplicate DSA problems');
    });

    test('5. Preserves user-completed topic checkmarks and reflections upon re-import', () async {
      await importService.executeImport(sourceJson);

      final roadmaps = await hubRepo.getAllRoadmaps();
      final roadmap = await hubRepo.getRoadmapById(roadmaps.first.id);
      expect(roadmap, isNotNull);
      final firstTopic = roadmap!.phases.first.topics.first;

      // Mark topic complete and set custom notes
      await hubRepo.toggleTopicCompletion(firstTopic.id, true);
      await hubRepo.updateTopicNotes(firstTopic.id, 'My custom understanding of kernel mode');

      // Re-import with preserveUserProgress: true
      await importService.executeImport(sourceJson, preserveUserProgress: true);

      // Verify persistence was preserved
      final reloadedRoadmap = await hubRepo.getRoadmapById(roadmap.id);
      final reloadedTopic = reloadedRoadmap!.phases.first.topics.first;

      expect(reloadedTopic.isCompleted, isTrue);
      expect(reloadedTopic.notes, equals('My custom understanding of kernel mode'));
    });

    test('6. Updates DSA problem status, intuition, and complexities', () async {
      await importService.executeImport(sourceJson);

      final problems = await hubRepo.getAllDsaProblems();
      final threeSum = problems.firstWhere((p) => p.title == 'Three Sum');

      final updated = threeSum.copyWith(
        status: 'mastered',
        intuition: 'Fix one element, reduce to Two Sum II with two opposite pointers.',
        approach: 'Sort array first, skip duplicates, use left and right pointers.',
        timeComplexity: 'O(N^2)',
        spaceComplexity: 'O(1) excluding sorting',
      );

      await hubRepo.updateDsaProblem(updated);

      final reloaded = (await hubRepo.getAllDsaProblems()).firstWhere((p) => p.title == 'Three Sum');
      expect(reloaded.status, equals('mastered'));
      expect(reloaded.intuition, contains('Fix one element'));
      expect(reloaded.timeComplexity, equals('O(N^2)'));
      expect(reloaded.spaceComplexity, equals('O(1) excluding sorting'));
    });

    test('7. Updates Project checkpoint notes and status', () async {
      await importService.executeImport(sourceJson);

      final heroProject = await hubRepo.getProjectById('proj-primary-1');
      expect(heroProject, isNotNull);

      final updated = heroProject!.copyWith(
        status: 'in_progress',
        checkpointNotes: 'Completed hero creation POST endpoint with gin validation. Added tests.',
      );

      await hubRepo.updateProject(updated);

      final reloaded = await hubRepo.getProjectById('proj-primary-1');
      expect(reloaded!.status, equals('in_progress'));
      expect(reloaded.checkpointNotes, contains('POST endpoint with gin validation'));
    });
  });
}
