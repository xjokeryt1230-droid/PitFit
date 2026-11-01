
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class WorkoutPlanService {
  WorkoutPlanService._();

  static final WorkoutPlanService instance = WorkoutPlanService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final directory = await getDatabasesPath();
    final path = p.join(directory, 'pitfit_plans.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX plans_username_idx
          ON plans(username)
        ''');

        await db.execute('''
          CREATE TABLE plan_exercises (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            sets INTEGER NOT NULL DEFAULT 3,
            reps INTEGER NOT NULL DEFAULT 10,
            duration_seconds INTEGER NOT NULL DEFAULT 0,
            rest_seconds INTEGER NOT NULL DEFAULT 90,
            notes TEXT NOT NULL DEFAULT '',
            position INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(plan_id) REFERENCES plans(id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE INDEX plan_exercises_plan_idx
          ON plan_exercises(plan_id)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            ALTER TABLE plan_exercises
            ADD COLUMN rest_seconds INTEGER NOT NULL DEFAULT 90
          ''');
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    return _database!;
  }

  Future<List<Map<String, Object?>>> getPlans(String username) async {
    final db = await database;

    final plans = await db.query(
      'plans',
      where: 'username = ?',
      whereArgs: [username],
      orderBy: 'updated_at DESC, id DESC',
    );

    final result = <Map<String, Object?>>[];

    for (final plan in plans) {
      final exercises = await db.query(
        'plan_exercises',
        where: 'plan_id = ?',
        whereArgs: [plan['id']],
      );

      result.add({...plan, 'exercise_count': exercises.length});
    }

    return result;
  }

  Future<Map<String, Object?>?> getPlan(int planId, String username) async {
    final db = await database;

    final plans = await db.query(
      'plans',
      where: 'id = ? AND username = ?',
      whereArgs: [planId, username],
      limit: 1,
    );

    if (plans.isEmpty) return null;

    final exercises = await db.query(
      'plan_exercises',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'position ASC, id ASC',
    );

    return {...plans.first, 'exercises': exercises};
  }

  Future<int> createPlan({
    required String username,
    required String name,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return db.insert('plans', {
      'username': username,
      'name': name.trim(),
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<bool> renamePlan({
    required int planId,
    required String username,
    required String name,
  }) async {
    final db = await database;

    final count = await db.update(
      'plans',
      {
        'name': name.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND username = ?',
      whereArgs: [planId, username],
    );

    return count > 0;
  }

  Future<bool> deletePlan({
    required int planId,
    required String username,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      final plans = await txn.query(
        'plans',
        columns: ['id'],
        where: 'id = ? AND username = ?',
        whereArgs: [planId, username],
        limit: 1,
      );

      if (plans.isEmpty) return false;

      await txn.delete(
        'plan_exercises',
        where: 'plan_id = ?',
        whereArgs: [planId],
      );

      await txn.delete(
        'plans',
        where: 'id = ? AND username = ?',
        whereArgs: [planId, username],
      );

      return true;
    });
  }

  Future<List<Map<String, Object?>>> getExercises(int planId) async {
    final db = await database;

    return db.query(
      'plan_exercises',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'position ASC, id ASC',
    );
  }

  Future<int> addExercise({
    required int planId,
    required String name,
    required int sets,
    required int reps,
    required int durationSeconds,
    int restSeconds = 90,
    String notes = '',
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      final existing = await txn.query(
        'plan_exercises',
        columns: ['id'],
        where: 'plan_id = ?',
        whereArgs: [planId],
      );

      final id = await txn.insert('plan_exercises', {
        'plan_id': planId,
        'name': name.trim(),
        'sets': sets,
        'reps': reps,
        'duration_seconds': durationSeconds,
        'rest_seconds': restSeconds,
        'notes': notes.trim(),
        'position': existing.length,
      });

      await txn.update(
        'plans',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [planId],
      );

      return id;
    });
  }

  Future<bool> updateExercise({
    required int exerciseId,
    required int planId,
    required String name,
    required int sets,
    required int reps,
    required int durationSeconds,
    int restSeconds = 90,
    required String notes,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      final count = await txn.update(
        'plan_exercises',
        {
          'name': name.trim(),
          'sets': sets,
          'reps': reps,
          'duration_seconds': durationSeconds,
          'rest_seconds': restSeconds,
          'notes': notes.trim(),
        },
        where: 'id = ? AND plan_id = ?',
        whereArgs: [exerciseId, planId],
      );

      if (count > 0) {
        await txn.update(
          'plans',
          {'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [planId],
        );
      }

      return count > 0;
    });
  }

  Future<bool> deleteExercise({
    required int exerciseId,
    required int planId,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      final count = await txn.delete(
        'plan_exercises',
        where: 'id = ? AND plan_id = ?',
        whereArgs: [exerciseId, planId],
      );

      if (count == 0) return false;

      final remaining = await txn.query(
        'plan_exercises',
        columns: ['id'],
        where: 'plan_id = ?',
        whereArgs: [planId],
        orderBy: 'position ASC, id ASC',
      );

      for (var i = 0; i < remaining.length; i++) {
        await txn.update(
          'plan_exercises',
          {'position': i},
          where: 'id = ?',
          whereArgs: [remaining[i]['id']],
        );
      }

      await txn.update(
        'plans',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [planId],
      );

      return true;
    });
  }

  Future<void> moveExercise({
    required int planId,
    required int fromIndex,
    required int toIndex,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final exercises = await txn.query(
        'plan_exercises',
        where: 'plan_id = ?',
        whereArgs: [planId],
        orderBy: 'position ASC, id ASC',
      );

      if (fromIndex < 0 ||
          fromIndex >= exercises.length ||
          toIndex < 0 ||
          toIndex >= exercises.length) {
        return;
      }

      final moved = exercises.removeAt(fromIndex);
      exercises.insert(toIndex, moved);

      for (var i = 0; i < exercises.length; i++) {
        await txn.update(
          'plan_exercises',
          {'position': i},
          where: 'id = ?',
          whereArgs: [exercises[i]['id']],
        );
      }

      await txn.update(
        'plans',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [planId],
      );
    });
  }
}
