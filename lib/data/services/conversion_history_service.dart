/// Conversion History Service
/// SQLite-backed local database for conversion history
/// Syncs with Cloud Firestore for cross-session persistence
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/conversion_history_item.dart';
import 'firestore_sync_service.dart';

/// Service for managing conversion history in a local SQLite database
class ConversionHistoryService {
  static const String _dbName = 'conversion_history.db';
  static const String _tableName = 'history';
  static const int _dbVersion = 1;

  Database? _db;
  bool _isInitialized = false;
  FirestoreSyncService? _syncService;
  
  /// Notifier for real-time history stats updates
  final ValueNotifier<HistoryStats?> statsNotifier = ValueNotifier(null);

  /// Set the Firestore sync service (called from DI after construction)
  void setSyncService(FirestoreSyncService syncService) {
    _syncService = syncService;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fileName TEXT NOT NULL,
            filePath TEXT NOT NULL,
            fileType TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            fileSize INTEGER NOT NULL
          )
        ''');
        print('📦 History database created');
      },
    );

    _isInitialized = true;
    print('📦 History database initialized');
    _updateStatsNotifier();
  }

  /// Ensure DB is ready
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }

  /// Add a new history entry (local + Firestore)
  Future<int> addHistory(ConversionHistoryItem item) async {
    await _ensureInitialized();

    final map = item.toMap();
    map.remove('id'); // Let SQLite auto-increment

    final id = await _db!.insert(_tableName, map);

    print('📦 History added: ${item.fileName} (id=$id, type=${item.fileType.name})');

    // Sync to Firestore
    _syncService?.addHistoryEntry(item);

    _updateStatsNotifier();

    return id;
  }

  /// Load history from Firestore and insert missing entries into local SQLite.
  Future<void> loadFromFirestore() async {
    if (_syncService == null || !_syncService!.isAuthenticated) return;
    await _ensureInitialized();

    final remoteItems = await _syncService!.loadHistory();
    if (remoteItems.isEmpty) {
      // No remote data — push local history to Firestore (first-time sync)
      final localImages = await getAllImages();
      final localPdfs = await getAllPDFs();
      final allLocal = [...localImages, ...localPdfs];
      if (allLocal.isNotEmpty) {
        await _syncService!.syncLocalHistoryToFirestore(allLocal);
        print('📦 First-time sync: pushed ${allLocal.length} local entries to Firestore');
      }
      return;
    }

    // Get existing local entries to avoid duplicates
    final localImages = await getAllImages();
    final localPdfs = await getAllPDFs();
    final existingKeys = <String>{};
    for (final item in [...localImages, ...localPdfs]) {
      existingKeys.add('${item.fileName}_${item.createdAt.toIso8601String()}');
    }

    // Insert missing remote entries into local DB
    int added = 0;
    for (final item in remoteItems) {
      final key = '${item.fileName}_${item.createdAt.toIso8601String()}';
      if (!existingKeys.contains(key)) {
        final map = item.toMap();
        map.remove('id');
        await _db!.insert(_tableName, map);
        added++;
      }
    }

    print('📦 History loaded from Firestore: $added new entries added');
    _updateStatsNotifier();
  }

  /// Get all image history entries (newest first)
  Future<List<ConversionHistoryItem>> getAllImages() async {
    await _ensureInitialized();

    final rows = await _db!.query(
      _tableName,
      where: 'fileType = ?',
      whereArgs: ['image'],
      orderBy: 'createdAt DESC',
    );

    return rows.map((row) => ConversionHistoryItem.fromMap(row)).toList();
  }

  /// Get all PDF history entries (newest first)
  Future<List<ConversionHistoryItem>> getAllPDFs() async {
    await _ensureInitialized();

    final rows = await _db!.query(
      _tableName,
      where: 'fileType = ?',
      whereArgs: ['pdf'],
      orderBy: 'createdAt DESC',
    );

    return rows.map((row) => ConversionHistoryItem.fromMap(row)).toList();
  }

  /// Get count of image conversions
  Future<int> getImageCount() async {
    await _ensureInitialized();

    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE fileType = ?',
      ['image'],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get count of PDF conversions
  Future<int> getPdfCount() async {
    await _ensureInitialized();

    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE fileType = ?',
      ['pdf'],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete a history entry and its file from disk
  Future<void> deleteHistory(int id) async {
    await _ensureInitialized();

    // Get the entry first to find the file path
    final rows = await _db!.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (rows.isNotEmpty) {
      final item = ConversionHistoryItem.fromMap(rows.first);

      // Delete file from disk
      try {
        final file = File(item.filePath);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Deleted file: ${item.filePath}');
        }
      } catch (e) {
        print('⚠️ Could not delete file: $e');
      }

      // Delete from database
      await _db!.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      print('🗑️ History entry deleted: id=$id, ${item.fileName}');
      _updateStatsNotifier();
    }
  }

  /// Rename a history entry and its file from disk
  Future<void> renameHistory(int id, String newName) async {
    await _ensureInitialized();

    final rows = await _db!.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (rows.isNotEmpty) {
      final item = ConversionHistoryItem.fromMap(rows.first);
      final file = File(item.filePath);
      
      if (await file.exists()) {
        final dir = p.dirname(item.filePath);
        final ext = p.extension(item.filePath);
        
        String nameWithoutExt = newName;
        if (newName.toLowerCase().endsWith(ext.toLowerCase())) {
          nameWithoutExt = newName.substring(0, newName.length - ext.length);
        }
        
        final finalFileName = '$nameWithoutExt$ext';
        final newPath = p.join(dir, finalFileName);
        
        await file.rename(newPath);
        
        await _db!.update(
          _tableName,
          {'fileName': finalFileName, 'filePath': newPath},
          where: 'id = ?',
          whereArgs: [id],
        );
        
        print('✏️ History entry renamed: id=$id, $finalFileName');
        
        // Also sync the renamed file up if needed, but since we rely on it syncing through load, we leave it simple here.
        _updateStatsNotifier();
      }
    }
  }

  /// Get usage stats (counts from database)
  Future<HistoryStats> getStats() async {
    final imageCount = await getImageCount();
    final pdfCount = await getPdfCount();

    return HistoryStats(
      imageCount: imageCount,
      pdfCount: pdfCount,
    );
  }
  
  /// Update stats notifier
  Future<void> _updateStatsNotifier() async {
    if (!_isInitialized) return;
    statsNotifier.value = await getStats();
  }

  /// Close the database
  Future<void> close() async {
    await _db?.close();
    _isInitialized = false;
  }
}

/// Stats from the history database
class HistoryStats {
  final int imageCount;
  final int pdfCount;

  const HistoryStats({
    required this.imageCount,
    required this.pdfCount,
  });

  int get total => imageCount + pdfCount;
}
