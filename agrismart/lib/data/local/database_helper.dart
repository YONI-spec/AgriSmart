// lib/data/local/database_helper.dart
// SQLite — initialisation, schéma, migrations
// Table scans avec tag_zone pour suivi longitudinal mobile

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  static const String _dbName    = 'agrismart.db';
  static const int    _dbVersion = 1;

  // ── Noms de tables et colonnes ────────────────────────────────
  static const String tableScans = 'scans';

  static const String colId          = 'id';
  static const String colDisease     = 'disease';
  static const String colConfidence  = 'confidence';
  static const String colPlantName   = 'plant_name';
  static const String colTagZone     = 'tag_zone';      // suivi longitudinal
  static const String colLatitude    = 'latitude';
  static const String colLongitude   = 'longitude';
  static const String colCapturedAt  = 'captured_at';
  static const String colSyncStatus  = 'sync_status';   // pending|synced|failed
  static const String colImagePath   = 'image_path';    // chemin local photo

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableScans (
        $colId          TEXT PRIMARY KEY,
        $colDisease     TEXT NOT NULL,
        $colConfidence  REAL NOT NULL,
        $colPlantName   TEXT,
        $colTagZone     TEXT,
        $colLatitude    REAL,
        $colLongitude   REAL,
        $colCapturedAt  TEXT NOT NULL,
        $colSyncStatus  TEXT NOT NULL DEFAULT 'pending',
        $colImagePath   TEXT
      )
    ''');

    // Index pour requêtes fréquentes
    await db.execute(
      'CREATE INDEX idx_scans_captured ON $tableScans ($colCapturedAt DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_scans_tag_zone ON $tableScans ($colTagZone)',
    );
    await db.execute(
      'CREATE INDEX idx_scans_sync ON $tableScans ($colSyncStatus)',
    );
  }

  // Migration future — ajouter des colonnes ici au besoin
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2 : await db.execute('ALTER TABLE scans ADD COLUMN ...');
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}