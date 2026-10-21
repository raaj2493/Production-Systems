import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifications/data/notification_providers.dart';
import '../domain/reminder_model.dart';
import 'reminder_repository.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final notifService = ref.watch(notificationServiceProvider);
  return ReminderRepository(notificationService: notifService);
});

final remindersProvider =
    StateNotifierProvider<RemindersNotifier, AsyncValue<List<ReminderConfig>>>((ref) {
  final repo = ref.watch(reminderRepositoryProvider);
  return RemindersNotifier(repo);
});

final reminderForTargetProvider =
    FutureProvider.family<ReminderConfig?, ({String targetType, String targetId})>((ref, arg) async {
  final repo = ref.watch(reminderRepositoryProvider);
  return repo.getReminderForTarget(arg.targetType, arg.targetId);
});

class RemindersNotifier extends StateNotifier<AsyncValue<List<ReminderConfig>>> {
  final ReminderRepository _repo;

  RemindersNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadReminders();
  }

  Future<void> loadReminders() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getAllReminders();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveReminder(ReminderConfig reminder) async {
    try {
      await _repo.saveReminder(reminder);
      await loadReminders();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await _repo.deleteReminder(id);
      await loadReminders();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleReminder(String id, bool isEnabled) async {
    try {
      await _repo.toggleReminder(id, isEnabled);
      await loadReminders();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRemindersForTarget(String targetType, String targetId) async {
    try {
      await _repo.deleteRemindersForTarget(targetType, targetId);
      await loadReminders();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
