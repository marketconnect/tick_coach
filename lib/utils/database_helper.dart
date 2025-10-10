import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tick_coach/domain/models/chat_message.dart';
import 'package:tick_coach/domain/models/interval.dart'
    show Interval, IntervalKind;
import 'package:tick_coach/domain/models/workout.dart';
// For Interval and IntervalKind

import 'dart:math';

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

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createDB(db, version);
        await _createDefaultWorkouts(db);
      },
    );
  }

  Future<void> _createDefaultWorkouts(Database db) async {
    String newId() =>
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    await db.transaction((txn) async {
      // Workout 1: Разминка
      final workout1Id = 'default_warmup';
      await txn.insert('workouts', {
        'id': workout1Id,
        'title': 'Разминка',
        'set_count': 1,
      });
      final warmupIntervals = [
        Interval(
          id: newId(),
          kind: IntervalKind.work,
          durationSec: 30,
          title: 'Работа',
          description:
              'круговые движения суставов (шея, плечи, таз, колени, голеностоп)',
        ),
        Interval(
          id: newId(),
          kind: IntervalKind.work,
          durationSec: 60,
          title: 'Работа',
          description: 'шаг и присед к стулу (частичная амплитуда)',
        ),
        Interval(
          id: newId(),
          kind: IntervalKind.work,
          durationSec: 60,
          title: 'Работа',
          description: 'выпады назад попеременно (медленно)',
        ),
        Interval(
          id: newId(),
          kind: IntervalKind.work,
          durationSec: 30,
          title: 'Работа',
          description: 'лёгкие прыжки на месте или марш на месте',
        ),
      ];
      for (int i = 0; i < warmupIntervals.length; i++) {
        final interval = warmupIntervals[i];
        await txn.insert('intervals', {
          'id': interval.id,
          'workout_id': workout1Id,
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
      // Workout 2: Тренировка
      final workout2Id = 'default_tabata';
      await txn.insert('workouts', {
        'id': workout2Id,
        'title': 'Тренировка',
        'set_count': 1,
      });
      List<Interval> tabataIntervals = [];
      final tabataDescriptions = [
        'Планка на прямых руках',
        'Шаги на месте с высоким подъемом бедра',
        'Скручивания на пресс',
        'Глубокие приседания',
      ];
      for (int i = 0; i < tabataDescriptions.length; i++) {
        for (int j = 0; j < 8; j++) {
          tabataIntervals.add(
            Interval(
              id: newId(),
              kind: IntervalKind.work,
              durationSec: 20,
              title: 'Работа',
              description: tabataDescriptions[i],
            ),
          );
          tabataIntervals.add(
            Interval(
              id: newId(),
              kind: IntervalKind.rest,
              durationSec: 10,
              title: 'Отдых',
            ),
          );
        }
        if (i < tabataDescriptions.length - 1) {
          tabataIntervals.removeLast();
          tabataIntervals.add(
            Interval(
              id: newId(),
              kind: IntervalKind.between_sets,
              durationSec: 60,
              title: 'Отдых между сетами',
            ),
          );
        }
      }
      tabataIntervals.removeLast();
      for (int i = 0; i < tabataIntervals.length; i++) {
        final interval = tabataIntervals[i];
        await txn.insert('intervals', _intervalToMap(interval, workout2Id, i));
      }
    });
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workouts(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        set_count INTEGER NOT NULL,
        notes TEXT
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

    await db.execute('''
      CREATE TABLE chat_messages(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        sender TEXT NOT NULL,
        timestamp INTEGER NOT NULL
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
        'notes': workout.notes,
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
        await txn.insert('intervals', _intervalToMap(interval, workout.id, i));
      }
    });
  }

  Map<String, dynamic> _intervalToMap(
    Interval interval,
    String workoutId,
    int order,
  ) => {
    'id': interval.id,
    'workout_id': workoutId,
    'kind': interval.kind.name,
    'title': interval.title,
    'description': interval.description,
    'duration_sec': interval.durationSec,
    'reps': interval.reps,
    'is_reps_based': interval.isRepsBased ? 1 : 0,
    'image_uri': interval.imageUri,
    'sort_order': order,
  };
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

  Future<List<Map<String, dynamic>>> getAllWorkouts() async {
    final db = await instance.database;
    return await db.query('workouts', orderBy: 'title');
  }

  Future<void> updateWorkoutNotes(String workoutId, String notes) async {
    final db = await instance.database;
    await db.update(
      'workouts',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<void> duplicateWorkout(String workoutId) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // 1. Get original workout
      final originalWorkoutMaps = await txn.query(
        'workouts',
        where: 'id = ?',
        whereArgs: [workoutId],
      );
      if (originalWorkoutMaps.isEmpty) {
        return;
      }
      final originalWorkoutMap = originalWorkoutMaps.first;

      // 2. Get original intervals
      final originalIntervalMaps = await txn.query(
        'intervals',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
        orderBy: 'sort_order ASC',
      );

      // 3. Create new workout
      final newWorkoutId =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      final newWorkoutTitle = 'Копия ${originalWorkoutMap['title']}';

      final newWorkoutData = Map<String, dynamic>.from(originalWorkoutMap);
      newWorkoutData['id'] = newWorkoutId;
      newWorkoutData['title'] = newWorkoutTitle;

      await txn.insert('workouts', newWorkoutData);

      // 4. Create and insert new intervals
      for (final originalIntervalMap in originalIntervalMaps) {
        final newIntervalData = Map<String, dynamic>.from(originalIntervalMap);
        newIntervalData['id'] =
            '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}_${originalIntervalMap['sort_order']}';
        newIntervalData['workout_id'] = newWorkoutId;
        await txn.insert('intervals', newIntervalData);
      }
    });
  }

  Future<void> deleteWorkout(String workoutId) async {
    final db = await instance.database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    final db = await instance.database;
    await db.insert(
      'chat_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getChatMessages() async {
    final db = await instance.database;
    final maps = await db.query('chat_messages', orderBy: 'timestamp ASC');
    if (maps.isEmpty) {
      return [];
    }
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }
}
