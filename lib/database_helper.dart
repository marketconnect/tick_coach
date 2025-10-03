import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'edit_workout_screen.dart'; // For Interval and IntervalKind
import 'workouts_screen.dart'; // For Workout

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('workouts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        set_count INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE intervals(
        id TEXT PRIMARY KEY,
        workout_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        title TEXT,
        description TEXT,
        duration_sec INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        is_reps_based INTEGER NOT NULL,
        image_uri TEXT,
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> saveWorkout(
    Workout workout,
    List<Interval> intervals,
    int setCount,
  ) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // Upsert workout
      await txn.insert('workouts', {
        'id': workout.id,
        'title': workout.title,
        'set_count': setCount,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Delete old intervals for this workout
      await txn.delete(
        'intervals',
        where: 'workout_id = ?',
        whereArgs: [workout.id],
      );

      // Insert new intervals
      for (int i = 0; i < intervals.length; i++) {
        final interval = intervals[i];
        await txn.insert('intervals', {
          'id': interval.id,
          'workout_id': workout.id,
          'kind': interval.kind.name,
          'title': interval.title,
          'description': interval.description,
          'duration_sec': interval.durationSec,
          'reps': interval.reps,
          'is_reps_based': interval.isRepsBased ? 1 : 0,
          'image_uri': interval.imageUri,
          'sort_order': i,
        });
      }
    });
  }

  Future<List<Interval>> getIntervalsForWorkout(String workoutId) async {
    final db = await instance.database;
    final maps = await db.query(
      'intervals',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'sort_order ASC',
    );

    if (maps.isEmpty) {
      return [];
    }

    return maps
        .map(
          (json) => Interval(
            id: json['id'] as String,
            kind: IntervalKind.values.byName(json['kind'] as String),
            title: json['title'] as String?,
            description: json['description'] as String?,
            durationSec: json['duration_sec'] as int,
            reps: json['reps'] as int,
            isRepsBased: (json['is_reps_based'] as int) == 1,
            imageUri: json['image_uri'] as String?,
          ),
        )
        .toList();
  }

  Future<int> getSetCountForWorkout(String workoutId) async {
    final db = await instance.database;
    final maps = await db.query(
      'workouts',
      columns: ['set_count'],
      where: 'id = ?',
      whereArgs: [workoutId],
    );

    if (maps.isNotEmpty) {
      return maps.first['set_count'] as int;
    } else {
      return 1; // Default value
    }
  }
}
