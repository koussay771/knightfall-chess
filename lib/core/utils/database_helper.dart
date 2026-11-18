// lib/core/utils/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/match_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chess_hotspot.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE match_history (
        id TEXT PRIMARY KEY,
        date INTEGER NOT NULL,
        opponentName TEXT NOT NULL,
        result TEXT NOT NULL,
        reason TEXT NOT NULL,
        mode TEXT NOT NULL,
        dareText TEXT,
        moves TEXT NOT NULL,
        pgn TEXT,
        myMaterialAdvantage INTEGER
      )
    ''');
  }

  /// Insert a match record. Returns the rowid.
  Future<int> insertMatch(MatchRecord record) async {
    final db = await database;
    return db.insert(
      'match_history',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetch all match records, most recent first.
  Future<List<MatchRecord>> getAllMatches() async {
    final db = await database;
    final rows = await db.query(
      'match_history',
      orderBy: 'date DESC',
    );
    return rows.map(MatchRecord.fromMap).toList();
  }

  /// Fetch matches against a specific opponent (case-insensitive), most recent first.
  Future<List<MatchRecord>> getMatchesByOpponent(String name) async {
    final db = await database;
    final rows = await db.query(
      'match_history',
      where: 'LOWER(opponentName) = LOWER(?)',
      whereArgs: [name],
      orderBy: 'date DESC',
    );
    return rows.map(MatchRecord.fromMap).toList();
  }

  /// Returns head-to-head record against a named opponent.
  Future<Map<String, int>> getHeadToHead(String opponentName) async {
    final matches = await getMatchesByOpponent(opponentName);
    int wins = 0, draws = 0, losses = 0;
    for (final m in matches) {
      if (m.result == 'win') {
        wins++;
      } else if (m.result == 'draw') {
        draws++;
      } else {
        losses++;
      }
    }
    return {'wins': wins, 'draws': draws, 'losses': losses};
  }

  /// Delete a match by id.
  Future<void> deleteMatch(String id) async {
    final db = await database;
    await db.delete('match_history', where: 'id = ?', whereArgs: [id]);
  }
}
