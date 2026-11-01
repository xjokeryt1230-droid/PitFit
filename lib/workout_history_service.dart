import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class WorkoutHistoryService {
  WorkoutHistoryService._();

  static final WorkoutHistoryService instance = WorkoutHistoryService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();

    _database = await openDatabase(
      p.join(dbPath, 'pitfit_workout_history.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workout_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            workout_title TEXT NOT NULL,
            completed_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_workout_history_user
          ON workout_history(username, completed_at)
        ''');
      },
    );

    return _database!;
  }

  Future<void> saveWorkout({
    required String username,
    required String title,
  }) async {
    final db = await database;

    await db.insert('workout_history', {
      'username': username,
      'workout_title': title,
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getHistory(String username) async {
    final db = await database;

    return db.query(
      'workout_history',
      where: 'username = ?',
      whereArgs: [username],
      orderBy: 'completed_at DESC',
    );
  }

  Future<int> getCompletedCount(String username) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM workout_history '
      'WHERE username = ?',
      [username],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
