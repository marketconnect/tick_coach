import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tick_coach/domain/models/chat_message.dart';
import 'dart:convert';
import 'package:tick_coach/domain/models/training_session.dart';

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
      CREATE TABLE training_sessions(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE blocks(
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        type TEXT NOT NULL,
        label TEXT,
        sort_order INTEGER NOT NULL,
             FOREIGN KEY (session_id) REFERENCES training_sessions (id) ON DELETE CASCADE
   )
 ''');
    await db.execute('''
   CREATE TABLE sets(
     id TEXT PRIMARY KEY,
     block_id TEXT NOT NULL,
     repeat INTEGER NOT NULL,
     label TEXT,
     sort_order INTEGER NOT NULL,
     FOREIGN KEY (block_id) REFERENCES blocks (id) ON DELETE CASCADE
   )
 ''');
    await db.execute('''
      CREATE TABLE set_items(
        id TEXT PRIMARY KEY,
        set_id TEXT NOT NULL,
        type TEXT NOT NULL, -- 'exercise' or 'rest'
        sort_order INTEGER NOT NULL,
        
        -- Common fields
        name TEXT, -- for exercise
        duration_sec INTEGER, -- for rest
        -- Exercise specific fields
        modality TEXT,
        equipment TEXT,
        load_kg REAL,
        tempo TEXT,
        repetitions_json TEXT,
        holds_json TEXT,
        -- Rest specific fields
        reason TEXT,
        FOREIGN KEY (set_id) REFERENCES sets (id) ON DELETE CASCADE
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

  Future<void> saveTrainingSession(TrainingSession session) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // Upsert session
      await txn.insert('training_sessions', {
        'id': session.id,
        'name': session.name,
        'notes': session.notes,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // Delete old children
      final blockIds = (await txn.query(
        'blocks',
        columns: ['id'],
        where: 'session_id = ?',
        whereArgs: [session.id],
      )).map((row) => row['id'] as String).toList();
      if (blockIds.isNotEmpty) {
        final setIds = (await txn.query(
          'sets',
          columns: ['id'],
          where: 'block_id IN (${List.filled(blockIds.length, '?').join(',')})',
          whereArgs: blockIds,
        )).map((row) => row['id'] as String).toList();
        if (setIds.isNotEmpty) {
          await txn.delete(
            'set_items',
            where: 'set_id IN (${List.filled(setIds.length, '?').join(',')})',
            whereArgs: setIds,
          );
        }
        await txn.delete(
          'sets',
          where: 'block_id IN (${List.filled(blockIds.length, '?').join(',')})',
          whereArgs: blockIds,
        );
      }
      await txn.delete(
        'blocks',
        where: 'session_id = ?',
        whereArgs: [session.id],
      );
      // Insert new children
      for (int i = 0; i < session.blocks.length; i++) {
        final block = session.blocks[i];
        await txn.insert('blocks', {
          'id': block.id,
          'session_id': session.id,
          'type': block.type,
          'label': block.label,
          'sort_order': i,
        });
        for (int j = 0; j < block.sets.length; j++) {
          final set = block.sets[j];
          await txn.insert('sets', {
            'id': set.id,
            'block_id': block.id,
            'repeat': set.repeat,
            'label': set.label,
            'sort_order': j,
          });
          for (int k = 0; k < set.items.length; k++) {
            final item = set.items[k];
            Map<String, dynamic> itemData = {
              'id': item.id,
              'set_id': set.id,
              'sort_order': k,
            };
            if (item is Exercise) {
              itemData.addAll({
                'type': 'exercise',
                'name': item.name,
                'modality': item.modality,
                'equipment': item.equipment,
                'load_kg': item.loadKg,
                'tempo': item.tempo,
                'repetitions_json': jsonEncode({
                  'is_reps_based': item.isRepsBased,
                  'reps': item.reps,
                  'duration_sec': item.durationSec,
                  'repetitions': item.repetitions
                      .map((r) => r.toJson())
                      .toList(),
                }),
                'holds_json': jsonEncode(
                  item.holds.map((h) => h.toJson()).toList(),
                ),
              });
            } else if (item is Rest) {
              itemData.addAll({
                'type': 'rest',
                'duration_sec': item.durationSec,
                'reason': item.reason,
              });
            }
            await txn.insert('set_items', itemData);
          }
        }
      }
    });
  }

  Future<TrainingSession?> getTrainingSession(String sessionId) async {
    final db = await instance.database;
    final sessionMaps = await db.query(
      'training_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    if (sessionMaps.isEmpty) return null;
    final sessionMap = sessionMaps.first;
    final session = TrainingSession(
      id: sessionMap['id'] as String,
      name: sessionMap['name'] as String,
      notes: sessionMap['notes'] as String?,
    );
    final blockMaps = await db.query(
      'blocks',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sort_order ASC',
    );
    for (final blockMap in blockMaps) {
      final block = Block(
        id: blockMap['id'] as String,
        type: blockMap['type'] as String,
        label: blockMap['label'] as String?,
      );
      session.blocks.add(block);
      final setMaps = await db.query(
        'sets',
        where: 'block_id = ?',
        whereArgs: [block.id],
        orderBy: 'sort_order ASC',
      );
      for (final setMap in setMaps) {
        final set = Set(
          id: setMap['id'] as String,
          repeat: setMap['repeat'] as int,
          label: setMap['label'] as String?,
        );
        block.sets.add(set);
        final itemMaps = await db.query(
          'set_items',
          where: 'set_id = ?',
          whereArgs: [set.id],
          orderBy: 'sort_order ASC',
        );
        for (final itemMap in itemMaps) {
          final type = itemMap['type'] as String;
          if (type == 'exercise') {
            final repetitionsJson =
                itemMap['repetitions_json'] as String? ?? '[]';
            final decodedRepetitions = jsonDecode(repetitionsJson);
            List<Repetition> repetitions;
            bool isRepsBased = true;
            int reps = 10;
            int durationSec = 30;
            if (decodedRepetitions is Map) {
              isRepsBased = decodedRepetitions['is_reps_based'] ?? true;
              reps = decodedRepetitions['reps'] ?? 10;
              durationSec = decodedRepetitions['duration_sec'] ?? 30;
              repetitions = (decodedRepetitions['repetitions'] as List? ?? [])
                  .map((r) => Repetition(index: r['index']))
                  .toList();
            } else if (decodedRepetitions is List) {
              repetitions = decodedRepetitions
                  .map((r) => Repetition(index: r['index']))
                  .toList();
            } else {
              repetitions = [];
            }
            set.items.add(
              Exercise(
                id: itemMap['id'] as String,
                name: itemMap['name'] as String,
                modality: itemMap['modality'] as String?,
                equipment: itemMap['equipment'] as String?,
                loadKg: itemMap['load_kg'] as double?,
                tempo: itemMap['tempo'] as String?,
                repetitions: repetitions,
                isRepsBased: isRepsBased,
                reps: reps,
                durationSec: durationSec,
                holds: (jsonDecode(itemMap['holds_json'] as String) as List)
                    .map((h) => Hold(durationSec: h['duration_sec']))
                    .toList(),
              ),
            );
          } else if (type == 'rest') {
            set.items.add(
              Rest(
                id: itemMap['id'] as String,
                durationSec: itemMap['duration_sec'] as int,
                reason: itemMap['reason'] as String?,
              ),
            );
          }
        }
      }
    }
    return session;
  }

  Future<List<Map<String, dynamic>>> getAllTrainingSessions() async {
    final db = await instance.database;
    return await db.query('training_sessions', orderBy: 'name');
  }

  Future<void> updateTrainingSessionNotes(
    String sessionId,
    String notes,
  ) async {
    final db = await instance.database;
    await db.update(
      'training_sessions',
      {'notes': notes},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteTrainingSession(String sessionId) async {
    final db = await instance.database;
    await db.delete(
      'training_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
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
