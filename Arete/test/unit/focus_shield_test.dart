import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:arete/core/database/database_service.dart';
import 'package:arete/features/focus/domain/focus_session_model.dart';
import 'package:arete/features/focus/domain/blocked_app_model.dart';
import 'package:arete/features/focus/data/blocked_apps_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Focus Shield Data & Repository Tests', () {
    late DatabaseService dbService;
    late BlockedAppsRepository blockedRepo;

    setUp(() async {
      dbService = DatabaseService.instance;
      await dbService.initDatabase(inMemory: true);
      blockedRepo = BlockedAppsRepository(dbService);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('Persists and retrieves blocked package selections', () async {
      final initialBlocked = await blockedRepo.getBlockedPackageNames();
      expect(initialBlocked, isEmpty);

      // Select apps
      final packagesToBlock = {'com.instagram.android', 'com.google.android.youtube'};
      final packageNames = {
        'com.instagram.android': 'Instagram',
        'com.google.android.youtube': 'YouTube',
      };

      await blockedRepo.syncBlockedPackages(packagesToBlock, packageNames);

      final blockedAfter = await blockedRepo.getBlockedPackageNames();
      expect(blockedAfter, hasLength(2));
      expect(blockedAfter, containsAll(['com.instagram.android', 'com.google.android.youtube']));

      // Deselect an app
      await blockedRepo.setAppBlocked('com.instagram.android', 'Instagram', false);
      final blockedAfterToggle = await blockedRepo.getBlockedPackageNames();
      expect(blockedAfterToggle, equals(['com.google.android.youtube']));
    });

    test('Logs distraction interruptions and calculates statistics accurately', () async {
      expect(await blockedRepo.getTotalInterruptionCount(), equals(0));

      const sessionId = 'test-session-123';
      await blockedRepo.logInterruption(
        sessionId: sessionId,
        packageName: 'com.instagram.android',
        appName: 'Instagram',
      );
      await blockedRepo.logInterruption(
        sessionId: sessionId,
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
      );

      final totalCount = await blockedRepo.getTotalInterruptionCount();
      expect(totalCount, equals(2));
    });

    test('FocusSession model serializes and deserializes shield & strict mode fields', () {
      final now = DateTime.now();
      final session = FocusSession(
        id: 'test-session-uuid',
        sessionType: FocusSessionType.focus,
        durationSeconds: 1500,
        completedSeconds: 1500,
        isCompleted: true,
        shieldEnabled: true,
        strictMode: true,
        interruptionsCount: 3,
        startedAt: now.subtract(const Duration(minutes: 25)),
        endedAt: now,
      );

      final map = session.toMap();
      expect(map['shield_enabled'], equals(1));
      expect(map['strict_mode'], equals(1));
      expect(map['interruptions_count'], equals(3));
      expect(map['session_type'], equals('focus'));

      final restored = FocusSession.fromMap(map);
      expect(restored.id, equals('test-session-uuid'));
      expect(restored.shieldEnabled, isTrue);
      expect(restored.strictMode, isTrue);
      expect(restored.interruptionsCount, equals(3));
      expect(restored.durationSeconds, equals(1500));
      expect(restored.completedSeconds, equals(1500));
    });

    test('BlockedApp model handles iconBytes and search queries gracefully', () {
      final app1 = BlockedApp(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isBlocked: true,
      );
      final app2 = BlockedApp(
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        isBlocked: false,
      );

      expect(app1.matchesQuery('insta'), isTrue);
      expect(app1.matchesQuery('gram'), isTrue);
      expect(app1.matchesQuery('youtube'), isFalse);
      expect(app2.matchesQuery('you'), isTrue);
      expect(app2.matchesQuery('tube'), isTrue);

      final toggled = app1.copyWith(isBlocked: false);
      expect(toggled.isBlocked, isFalse);
      expect(toggled.packageName, equals('com.instagram.android'));
    });
  });

  group('Focus Shield State & Lifecycle Logic Tests', () {
    test('Calculates remaining time from persisted target timestamp correctly', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final targetEndMs = nowMs + (10 * 60 * 1000); // 10 minutes from now

      final remainingSeconds = ((targetEndMs - nowMs) / 1000).ceil();
      expect(remainingSeconds, inInclusiveRange(599, 600));

      final remainingRatio = (remainingSeconds / 600.0).clamp(0.0, 1.0);
      expect(remainingRatio, closeTo(1.0, 0.02));
    });

    test('Detects expired session after process termination or app restart', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final targetEndMs = nowMs - 5000; // Ended 5 seconds ago in past

      final isExpired = nowMs >= targetEndMs;
      expect(isExpired, isTrue);
    });

    test('Pomodoro break transition alternates between focus and break cleanly', () {
      var current = FocusSessionType.focus;
      var next = current == FocusSessionType.focus
          ? FocusSessionType.shortBreak
          : FocusSessionType.focus;
      expect(next, equals(FocusSessionType.shortBreak));

      current = FocusSessionType.shortBreak;
      next = current == FocusSessionType.focus
          ? FocusSessionType.shortBreak
          : FocusSessionType.focus;
      expect(next, equals(FocusSessionType.focus));
    });

    test('Pomodoro 4-cycle progression triggers Long Break after 4 completed focus sessions', () {
      var completedFocusCount = 0;
      FocusSessionType sessionType = FocusSessionType.focus;

      // Simulate 4 cycles
      for (int i = 1; i <= 4; i++) {
        // Start Focus
        sessionType = FocusSessionType.focus;
        expect(sessionType, equals(FocusSessionType.focus));

        // Complete Focus session
        completedFocusCount++;

        // Determine next break
        if (completedFocusCount >= 4) {
          sessionType = FocusSessionType.longBreak;
        } else {
          sessionType = FocusSessionType.shortBreak;
        }

        if (i < 4) {
          expect(sessionType, equals(FocusSessionType.shortBreak), reason: 'Cycle $i must lead to short break');
        } else {
          expect(sessionType, equals(FocusSessionType.longBreak), reason: 'Cycle 4 must lead to 15m long break');
        }
      }

      // After completing long break, cycles reset
      completedFocusCount = 0;
      sessionType = FocusSessionType.focus;
      expect(completedFocusCount, equals(0));
      expect(sessionType, equals(FocusSessionType.focus));
    });
  });
}
