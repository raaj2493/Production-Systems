import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/focus/presentation/app_blocker_settings_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';
import '../../features/habits/presentation/habits_screen.dart';
import '../../features/learn/presentation/category_detail_screen.dart';
import '../../features/learn/presentation/learn_screen.dart';
import '../../features/learn/presentation/project_detail_screen.dart';
import '../../features/learn/presentation/roadmap_detail_screen.dart';
import '../../features/navigation/presentation/main_scaffold.dart';
import '../../features/navigation/presentation/more_screen.dart';
import '../../features/notes/domain/note_model.dart';
import '../../features/notes/presentation/note_editor_screen.dart';
import '../../features/notes/presentation/notes_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/today/presentation/today_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Today
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),

        // Tab 2: Tasks & Goals
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksScreen(),
            ),
          ],
        ),

        // Tab 3: Focus Timer
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/focus',
              builder: (context, state) => const FocusScreen(),
              routes: [
                GoRoute(
                  path: 'apps',
                  builder: (context, state) => const AppBlockerSettingsScreen(),
                ),
              ],
            ),
          ],
        ),

        // Tab 4: Learn
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/learn',
              builder: (context, state) => const LearnScreen(),
              routes: [
                GoRoute(
                  path: 'category/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return CategoryDetailScreen(categoryId: id);
                  },
                ),
                GoRoute(
                  path: 'roadmap/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return RoadmapDetailScreen(roadmapId: id);
                  },
                ),
                GoRoute(
                  path: 'project/:id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return ProjectDetailScreen(projectId: id);
                  },
                ),
              ],
            ),
          ],
        ),

        // Tab 5: More (Habits, Notes, Progress, Settings)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => const MoreScreen(),
              routes: [
                GoRoute(
                  path: 'habits',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const HabitsScreen(),
                ),
                GoRoute(
                  path: 'notes',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const NotesScreen(),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final note = state.extra as Note?;
                        return NoteEditorScreen(note: note);
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'progress',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const ProgressScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
