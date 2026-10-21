import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/tables.dart';
import '../domain/note_model.dart';

class NoteRepository {
  final DatabaseService _dbService;

  NoteRepository([DatabaseService? dbService])
      : _dbService = dbService ?? DatabaseService.instance;

  Future<List<Note>> getAllNotes({String? tag, String? goalId, String? resourceId}) async {
    final db = await _dbService.database;
    String whereClause = '';
    List<dynamic> args = [];

    if (goalId != null) {
      whereClause = 'WHERE n.goal_id = ?';
      args = [goalId];
    } else if (resourceId != null) {
      whereClause = 'WHERE n.resource_id = ?';
      args = [resourceId];
    }

    final results = await db.rawQuery('''
      SELECT 
        n.*,
        g.title AS goal_title,
        r.title AS resource_title
      FROM ${AppTables.notes} n
      LEFT JOIN ${AppTables.goals} g ON g.id = n.goal_id
      LEFT JOIN ${AppTables.learningResources} r ON r.id = n.resource_id
      $whereClause
      ORDER BY n.is_pinned DESC, n.updated_at DESC
    ''', args);

    var notes = results.map((r) => Note.fromMap(r)).toList();

    if (tag != null && tag.isNotEmpty) {
      notes = notes.where((n) => n.tags.contains(tag)).toList();
    }

    return notes;
  }

  Future<Note?> getNoteById(String id) async {
    final db = await _dbService.database;
    final results = await db.rawQuery('''
      SELECT 
        n.*,
        g.title AS goal_title,
        r.title AS resource_title
      FROM ${AppTables.notes} n
      LEFT JOIN ${AppTables.goals} g ON g.id = n.goal_id
      LEFT JOIN ${AppTables.learningResources} r ON r.id = n.resource_id
      WHERE n.id = ?
    ''', [id]);

    if (results.isEmpty) return null;
    return Note.fromMap(results.first);
  }

  Future<void> saveNote(Note note) async {
    final db = await _dbService.database;
    await db.insert(
      AppTables.notes,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> togglePin(String id) async {
    final db = await _dbService.database;
    final note = await getNoteById(id);
    if (note == null) return;

    await db.update(
      AppTables.notes,
      {
        'is_pinned': note.isPinned ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await _dbService.database;
    await db.delete(
      AppTables.notes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getAllTags() async {
    final notes = await getAllNotes();
    final Set<String> tagSet = {};
    for (final note in notes) {
      tagSet.addAll(note.tags);
    }
    return tagSet.toList()..sort();
  }
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository();
});

class NotesNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  final NoteRepository _repository;

  NotesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    try {
      final list = await _repository.getAllNotes();
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveNote(Note note) async {
    await _repository.saveNote(note);
    await loadNotes();
  }

  Future<void> togglePin(String id) async {
    await _repository.togglePin(id);
    await loadNotes();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    await loadNotes();
  }
}

final notesProvider =
    StateNotifierProvider<NotesNotifier, AsyncValue<List<Note>>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  return NotesNotifier(repo);
});

final allTagsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  ref.watch(notesProvider); // reload when notes change
  return repo.getAllTags();
});
