
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class ExerciseProgressService {
  ExerciseProgressService._();

  static final ExerciseProgressService instance =
      ExerciseProgressService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final directory = await getDatabasesPath();
    final path = p.join(directory, 'pitfit_progress.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exercise_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            exercise_id INTEGER NOT NULL,
            exercise_name TEXT NOT NULL,
            plan_name TEXT NOT NULL,
            weight REAL,
            reps INTEGER,
            duration_seconds INTEGER,
            recorded_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX exercise_progress_user_exercise_idx
          ON exercise_progress(username, exercise_id, recorded_at)
        ''');
      },
    );

    return _database!;
  }

  Future<int> saveProgress({
    required String username,
    required int exerciseId,
    required String exerciseName,
    required String planName,
    double? weight,
    int? reps,
    int? durationSeconds,
  }) async {
    final db = await database;

    return db.insert('exercise_progress', {
      'username': username,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'plan_name': planName,
      'weight': weight,
      'reps': reps,
      'duration_seconds': durationSeconds,
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getProgress({
    required String username,
    required int exerciseId,
  }) async {
    final db = await database;

    return db.query(
      'exercise_progress',
      where: 'username = ? AND exercise_id = ?',
      whereArgs: [username, exerciseId],
      orderBy: 'recorded_at DESC, id DESC',
    );
  }

  Future<List<Map<String, Object?>>> getAllProgress(
    String username,
  ) async {
    final db = await database;

    return db.query(
      'exercise_progress',
      where: 'username = ?',
      whereArgs: [username],
      orderBy: 'recorded_at DESC, id DESC',
    );
  }

  Future<int> deleteProgress({
    required String username,
    required int progressId,
  }) async {
    final db = await database;

    return db.delete(
      'exercise_progress',
      where: 'id = ? AND username = ?',
      whereArgs: [progressId, username],
    );
  }
}
