import 'package:sqflite/sqflite.dart';
import 'tables.dart';

class DatabaseMigrations {
  static const int currentVersion = 5;

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON;');

    // 1. Goals
    await db.execute('''
      CREATE TABLE ${AppTables.goals} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        color TEXT,
        target_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 2. Tasks
    await db.execute('''
      CREATE TABLE ${AppTables.tasks} (
        id TEXT PRIMARY KEY,
        goal_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        due_date TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        is_daily_target INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES ${AppTables.goals} (id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_tasks_goal_id ON ${AppTables.tasks}(goal_id);');
    await db.execute('CREATE INDEX idx_tasks_due_date ON ${AppTables.tasks}(due_date);');
    await db.execute('CREATE INDEX idx_tasks_is_completed ON ${AppTables.tasks}(is_completed);');

    // 3. Habits
    await db.execute('''
      CREATE TABLE ${AppTables.habits} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        frequency_type TEXT NOT NULL DEFAULT 'daily',
        custom_days TEXT,
        color TEXT,
        created_at TEXT NOT NULL,
        archived_at TEXT
      );
    ''');

    // 4. Habit Completions
    await db.execute('''
      CREATE TABLE ${AppTables.habitCompletions} (
        id TEXT PRIMARY KEY,
        habit_id TEXT NOT NULL,
        completion_date TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES ${AppTables.habits} (id) ON DELETE CASCADE,
        UNIQUE (habit_id, completion_date)
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_habit_completions_habit_date ON ${AppTables.habitCompletions}(habit_id, completion_date);',
    );

    // 5. Focus Sessions
    await db.execute('''
      CREATE TABLE ${AppTables.focusSessions} (
        id TEXT PRIMARY KEY,
        task_id TEXT,
        goal_id TEXT,
        session_type TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        completed_seconds INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 1,
        shield_enabled INTEGER NOT NULL DEFAULT 0,
        strict_mode INTEGER NOT NULL DEFAULT 0,
        interruptions_count INTEGER NOT NULL DEFAULT 0,
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES ${AppTables.tasks} (id) ON DELETE SET NULL,
        FOREIGN KEY (goal_id) REFERENCES ${AppTables.goals} (id) ON DELETE SET NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_focus_sessions_started_at ON ${AppTables.focusSessions}(started_at);',
    );

    // 6. Learning Collections
    await db.execute('''
      CREATE TABLE ${AppTables.learningCollections} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        color TEXT,
        icon TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 7. Learning Resources
    await db.execute('''
      CREATE TABLE ${AppTables.learningResources} (
        id TEXT PRIMARY KEY,
        collection_id TEXT,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        resource_type TEXT NOT NULL DEFAULT 'article',
        description TEXT,
        topic TEXT,
        status TEXT NOT NULL DEFAULT 'not_started',
        progress_percentage INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        duration TEXT,
        thumbnail_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (collection_id) REFERENCES ${AppTables.learningCollections} (id) ON DELETE SET NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_resources_collection_id ON ${AppTables.learningResources}(collection_id);',
    );

    // 8. Notes
    await db.execute('''
      CREATE TABLE ${AppTables.notes} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        goal_id TEXT,
        resource_id TEXT,
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES ${AppTables.goals} (id) ON DELETE SET NULL,
        FOREIGN KEY (resource_id) REFERENCES ${AppTables.learningResources} (id) ON DELETE SET NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_notes_pinned_updated ON ${AppTables.notes}(is_pinned, updated_at);',
    );

    // 9. Tags
    await db.execute('''
      CREATE TABLE ${AppTables.tags} (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL
      );
    ''');

    // 10. Focus Shield Blocked Apps
    await db.execute('''
      CREATE TABLE ${AppTables.blockedApps} (
        package_name TEXT PRIMARY KEY,
        app_name TEXT NOT NULL,
        is_blocked INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );
    ''');

    // 11. Focus Shield Distraction Interruptions Log
    await db.execute('''
      CREATE TABLE ${AppTables.focusShieldInterruptions} (
        id TEXT PRIMARY KEY,
        session_id TEXT,
        package_name TEXT NOT NULL,
        app_name TEXT,
        timestamp TEXT NOT NULL
      );
    ''');

    // 12. Flexible Reminders (Interval, Fixed, Priority, Sticky)
    await db.execute('''
      CREATE TABLE ${AppTables.reminders} (
        id TEXT PRIMARY KEY,
        target_type TEXT NOT NULL,
        target_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        trigger_type TEXT NOT NULL DEFAULT 'fixed_time',
        interval_minutes INTEGER DEFAULT 60,
        window_start_hour INTEGER DEFAULT 9,
        window_start_minute INTEGER DEFAULT 0,
        window_end_hour INTEGER DEFAULT 21,
        window_end_minute INTEGER DEFAULT 0,
        fixed_hour INTEGER DEFAULT 10,
        fixed_minute INTEGER DEFAULT 0,
        days_of_week TEXT,
        priority TEXT NOT NULL DEFAULT 'medium',
        is_sticky INTEGER NOT NULL DEFAULT 0,
        sound_mode TEXT NOT NULL DEFAULT 'gentle_chime',
        is_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_reminders_target ON ${AppTables.reminders}(target_type, target_id);',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_enabled ON ${AppTables.reminders}(is_enabled);',
    );

    // 13. Learning System (Roadmaps, Categories, Projects, DSA, Profile)
    await _createLearningTables(db);
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppTables.blockedApps} (
          package_name TEXT PRIMARY KEY,
          app_name TEXT NOT NULL,
          is_blocked INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppTables.focusShieldInterruptions} (
          id TEXT PRIMARY KEY,
          session_id TEXT,
          package_name TEXT NOT NULL,
          app_name TEXT,
          timestamp TEXT NOT NULL
        );
      ''');
      try {
        await db.execute('ALTER TABLE ${AppTables.focusSessions} ADD COLUMN shield_enabled INTEGER NOT NULL DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE ${AppTables.focusSessions} ADD COLUMN strict_mode INTEGER NOT NULL DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE ${AppTables.focusSessions} ADD COLUMN interruptions_count INTEGER NOT NULL DEFAULT 0;');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      await _createLearningTables(db);
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE ${AppTables.learningCollections} ADD COLUMN icon TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE ${AppTables.learningResources} ADD COLUMN duration TEXT;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE ${AppTables.learningResources} ADD COLUMN thumbnail_url TEXT;');
      } catch (_) {}
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${AppTables.reminders} (
          id TEXT PRIMARY KEY,
          target_type TEXT NOT NULL,
          target_id TEXT,
          title TEXT NOT NULL,
          description TEXT,
          trigger_type TEXT NOT NULL DEFAULT 'fixed_time',
          interval_minutes INTEGER DEFAULT 60,
          window_start_hour INTEGER DEFAULT 9,
          window_start_minute INTEGER DEFAULT 0,
          window_end_hour INTEGER DEFAULT 21,
          window_end_minute INTEGER DEFAULT 0,
          fixed_hour INTEGER DEFAULT 10,
          fixed_minute INTEGER DEFAULT 0,
          days_of_week TEXT,
          priority TEXT NOT NULL DEFAULT 'medium',
          is_sticky INTEGER NOT NULL DEFAULT 0,
          sound_mode TEXT NOT NULL DEFAULT 'gentle_chime',
          is_enabled INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reminders_target ON ${AppTables.reminders}(target_type, target_id);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reminders_enabled ON ${AppTables.reminders}(is_enabled);',
      );
    }
  }

  static Future<void> _createLearningTables(DatabaseExecutor db) async {
    // Categories
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppTables.learningCategories} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        display_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');

    // Roadmaps
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppTables.learningRoadmaps} (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'not_started',
        primary_language TEXT,
        learning_rules TEXT,
        display_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES ${AppTables.learningCategories} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_roadmaps_category_id ON ${AppTables.learningRoadmaps}(category_id);',
    );

    // Roadmap Phases
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppTables.learningRoadmapPhases} (
        id TEXT PRIMARY KEY,
        roadmap_id TEXT NOT NULL,
        title TEXT NOT NULL,
        phase_order INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (roadmap_id) REFERENCES ${AppTables.learningRoadmaps} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_roadmap_phases_roadmap_id ON ${AppTables.learningRoadmapPhases}(roadmap_id);',
    );

    // Roadmap Topics
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppTables.learningRoadmapTopics} (
        id TEXT PRIMARY KEY,
        phase_id TEXT NOT NULL,
        roadmap_id TEXT NOT NULL,
        title TEXT NOT NULL,
        topic_order INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        completed_at TEXT,
        FOREIGN KEY (phase_id) REFERENCES ${AppTables.learningRoadmapPhases} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_roadmap_topics_phase_id ON ${AppTables.learningRoadmapTopics}(phase_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_roadmap_topics_roadmap_id ON ${AppTables.learningRoadmapTopics}(roadmap_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_roadmap_topics_completed ON ${AppTables.learningRoadmapTopics}(is_completed);',
    );

    // DSA Practice Problems
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppTables.dsaProblems} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        pattern TEXT NOT NULL,
        difficulty TEXT NOT NULL DEFAULT 'Medium',
        status TEXT NOT NULL DEFAULT 'not_started',
        intuition TEXT,
        approach TEXT,
        mistakes TEXT,
        time_complexity TEXT,
        space_complexity TEXT,
        code_snippet TEXT,
        display_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dsa_problems_pattern ON ${AppTables.dsaProblems}(pattern);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dsa_problems_status ON ${AppTables.dsaProblems}(status);',
    );

    // Learning Projects (Primary & Advanced AI Systems)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppTables.learningProjects} (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        roadmap_id TEXT,
        project_group TEXT NOT NULL DEFAULT 'primary',
        name TEXT NOT NULL,
        description TEXT,
        architecture TEXT,
        status TEXT NOT NULL DEFAULT 'planned',
        project_order INTEGER NOT NULL DEFAULT 0,
        tech_stack TEXT,
        domain_areas TEXT,
        learning_focus TEXT,
        checkpoint_notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES ${AppTables.learningCategories} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learning_projects_category ON ${AppTables.learningProjects}(category_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learning_projects_group ON ${AppTables.learningProjects}(project_group);',
    );

    // Learning Profile & Preferences
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppTables.learningProfile} (
        id TEXT PRIMARY KEY,
        primary_goal TEXT,
        target_horizon TEXT,
        career_title TEXT,
        career_emphasis TEXT,
        known_skills TEXT,
        learning_skills TEXT,
        planned_skills TEXT,
        learning_style TEXT,
        theory_practice_ratio TEXT,
        learning_workflow TEXT,
        learning_preferences TEXT,
        hackathon_rhythm TEXT,
        updated_at TEXT NOT NULL
      );
    ''');
  }

  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }
}
