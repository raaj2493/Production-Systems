import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../../notifications/data/notification_service.dart';
import '../domain/reminder_model.dart';

class ReminderRepository {
  final DatabaseService _dbService;
  final NotificationService _notificationService;

  ReminderRepository({
    DatabaseService? dbService,
    NotificationService? notificationService,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _notificationService = notificationService ?? NotificationService();

  /// Retrieve all configured flexible reminders
  Future<List<ReminderConfig>> getAllReminders() async {
    final db = await _dbService.database;
    final rows = await db.query(
      AppTables.reminders,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => ReminderConfig.fromMap(r)).toList();
  }

  /// Retrieve single reminder by id
  Future<ReminderConfig?> getReminderById(String id) async {
    final db = await _dbService.database;
    final rows = await db.query(
      AppTables.reminders,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReminderConfig.fromMap(rows.first);
  }

  /// Retrieve linked reminder for a habit or task
  Future<ReminderConfig?> getReminderForTarget(String targetType, String targetId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      AppTables.reminders,
      where: 'target_type = ? AND target_id = ?',
      whereArgs: [targetType, targetId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ReminderConfig.fromMap(rows.first);
  }

  /// Save or update a reminder config
  Future<void> saveReminder(ReminderConfig reminder) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.reminders,
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Synchronize to native AlarmManager
    if (reminder.isEnabled) {
      await _notificationService.scheduleFlexibleReminder(reminder);
    } else {
      await _notificationService.cancelFlexibleReminder(reminder.id);
    }
  }

  /// Delete a reminder by ID
  Future<void> deleteReminder(String id) async {
    final db = await _dbService.database;
    await db.delete(
      AppTables.reminders,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notificationService.cancelFlexibleReminder(id);
  }

  /// Delete all reminders linked to a target habit or task
  Future<void> deleteRemindersForTarget(String targetType, String targetId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      AppTables.reminders,
      where: 'target_type = ? AND target_id = ?',
      whereArgs: [targetType, targetId],
    );

    for (final row in rows) {
      final id = row['id'] as String;
      await _notificationService.cancelFlexibleReminder(id);
    }

    await db.delete(
      AppTables.reminders,
      where: 'target_type = ? AND target_id = ?',
      whereArgs: [targetType, targetId],
    );
  }

  /// Toggle reminder enabled state
  Future<void> toggleReminder(String id, bool isEnabled) async {
    final db = await _dbService.database;
    final now = DateTime.now();
    await db.update(
      AppTables.reminders,
      {
        'is_enabled': isEnabled ? 1 : 0,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    final updated = await getReminderById(id);
    if (updated != null) {
      if (isEnabled) {
        await _notificationService.scheduleFlexibleReminder(updated);
      } else {
        await _notificationService.cancelFlexibleReminder(id);
      }
    }
  }

  /// Synchronize all enabled reminders with native AlarmManager
  Future<void> syncAllReminders() async {
    final reminders = await getAllReminders();
    for (final reminder in reminders) {
      if (reminder.isEnabled) {
        await _notificationService.scheduleFlexibleReminder(reminder);
      } else {
        await _notificationService.cancelFlexibleReminder(reminder.id);
      }
    }
  }
}
