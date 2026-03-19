// lib/data/local/scan_dao.dart
// DAO — toutes les requêtes SQLite sur la table scans
// Inclut : CRUD, file sync, requêtes suivi longitudinal

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'database_helper.dart';
import '../../domain/entities/scan_result.dart';

class ScanDao {
  ScanDao._();
  static final ScanDao instance = ScanDao._();

  final _uuid = const Uuid();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ── INSERT ────────────────────────────────────────────────────

  /// Sauvegarde un résultat de scan (génère un UUID si absent)
  Future<ScanResult> insertScan(ScanResult scan) async {
    final db = await _db;
    final toSave = scan.id.isEmpty
        ? ScanResult(
            id: _uuid.v4(),
            disease: scan.disease,
            confidence: scan.confidence,
            allProbabilities: scan.allProbabilities,
            capturedAt: scan.capturedAt,
            plantName: scan.plantName,
            tagZone: scan.tagZone,
            latitude: scan.latitude,
            longitude: scan.longitude,
          )
        : scan;

    await db.insert(
      DatabaseHelper.tableScans,
      toSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return toSave;
  }

  // ── SELECT ────────────────────────────────────────────────────

  /// Tous les scans, du plus récent au plus ancien
  Future<List<ScanResult>> getAllScans({int limit = 50}) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseHelper.tableScans,
      orderBy: '${DatabaseHelper.colCapturedAt} DESC',
      limit: limit,
    );
    return maps.map(ScanResult.fromMap).toList();
  }

  /// Scans d'une zone étiquetée — pour suivi longitudinal
  Future<List<ScanResult>> getScansByZone(String tagZone) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseHelper.tableScans,
      where: '${DatabaseHelper.colTagZone} = ?',
      whereArgs: [tagZone],
      orderBy: '${DatabaseHelper.colCapturedAt} ASC', // chronologique pour courbe
    );
    return maps.map(ScanResult.fromMap).toList();
  }

  /// Toutes les zones étiquetées distinctes
  Future<List<String>> getAllTagZones() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT DISTINCT ${DatabaseHelper.colTagZone}
      FROM ${DatabaseHelper.tableScans}
      WHERE ${DatabaseHelper.colTagZone} IS NOT NULL
      ORDER BY ${DatabaseHelper.colTagZone}
    ''');
    return result
        .map((r) => r[DatabaseHelper.colTagZone] as String)
        .toList();
  }

  // ── SYNC QUEUE ────────────────────────────────────────────────

  /// Scans en attente d'envoi au serveur
  Future<List<ScanResult>> getPendingScans({int batchSize = 20}) async {
    final db = await _db;
    final maps = await db.query(
      DatabaseHelper.tableScans,
      where: '${DatabaseHelper.colSyncStatus} = ?',
      whereArgs: ['pending'],
      orderBy: '${DatabaseHelper.colCapturedAt} ASC',
      limit: batchSize,
    );
    return maps.map(ScanResult.fromMap).toList();
  }

  /// Marquer un scan comme synchronisé
  Future<void> markSynced(String id) async {
    final db = await _db;
    await db.update(
      DatabaseHelper.tableScans,
      {DatabaseHelper.colSyncStatus: 'synced'},
      where: '${DatabaseHelper.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Marquer un scan comme en erreur de sync
  Future<void> markSyncFailed(String id) async {
    final db = await _db;
    await db.update(
      DatabaseHelper.tableScans,
      {DatabaseHelper.colSyncStatus: 'failed'},
      where: '${DatabaseHelper.colId} = ?',
      whereArgs: [id],
    );
  }

  // ── DELETE ────────────────────────────────────────────────────

  Future<void> deleteScan(String id) async {
    final db = await _db;
    await db.delete(
      DatabaseHelper.tableScans,
      where: '${DatabaseHelper.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Nettoyage : supprimer les scans synchronisés de plus de 30 jours
  Future<int> cleanOldSyncedScans() async {
    final db = await _db;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    return db.delete(
      DatabaseHelper.tableScans,
      where: '${DatabaseHelper.colSyncStatus} = ? AND '
             '${DatabaseHelper.colCapturedAt} < ?',
      whereArgs: ['synced', cutoff],
    );
  }
}