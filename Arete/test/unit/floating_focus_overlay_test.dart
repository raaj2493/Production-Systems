import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arete/features/focus/presentation/focus_timer_controller.dart';
import 'package:arete/features/focus/data/pip_service.dart';
import 'package:arete/features/focus/presentation/widgets/floating_focus_pill_overlay.dart';
import 'package:arete/features/focus/presentation/widgets/pip_focus_view.dart';
import 'package:arete/core/providers/app_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      'focus_timer_state': 'running',
      'focus_session_type': 'focus',
      'focus_total_seconds': 1500,
      'focus_remaining_seconds': 1200,
      'focus_target_end_ms': nowMs + 1200000,
    });
    prefs = await SharedPreferences.getInstance();
  });

  group('Floating Focus Overlay & Controller Tests', () {
    test('1. FocusTimerController.addMinutes increases remaining and total seconds', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final controller = container.read(focusTimerProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 50));

      final initialRemaining = container.read(focusTimerProvider).remainingSeconds;
      final initialTotal = container.read(focusTimerProvider).totalSeconds;

      controller.addMinutes(5);

      final updatedState = container.read(focusTimerProvider);
      expect(updatedState.remainingSeconds, initialRemaining + 300);
      expect(updatedState.totalSeconds, initialTotal + 300);
    });

    testWidgets('2. FloatingFocusPillOverlay renders Material 3 pill with controls',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  FloatingFocusPillOverlay(),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify phase badge and controls
      expect(find.text('FOCUS'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('5m'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap +5m button
      await tester.tap(find.text('5m'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should have increased remaining time
      expect(container.read(focusTimerProvider).totalSeconds, 1800);

      container.read(focusTimerProvider.notifier).pause();
      container.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('3. PipFocusView renders Option B minimal dynamic island capsule with play/pause and countdown digits',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PipFocusView(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('+5m'), findsNothing);
      expect(find.byType(FadeTransition), findsWidgets);

      container.read(focusTimerProvider.notifier).pause();
      container.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('4. PipService passes totalSeconds and syncs overlay parameters', () async {
      final pipService = PipService();
      expect(pipService.isAndroid, true);

      // Verify enterPip and updateOverlay handles totalSeconds gracefully
      final enterResult = await pipService.enterPip(
        remainingSeconds: 1500,
        totalSeconds: 1500,
        isRunning: true,
        isBreak: false,
      );
      expect(enterResult, false); // Returns false when platform channel has no active plugin handler

      await pipService.updateOverlay(
        remainingSeconds: 1400,
        totalSeconds: 1500,
        isRunning: true,
        isBreak: false,
      );
    });
  });
}
