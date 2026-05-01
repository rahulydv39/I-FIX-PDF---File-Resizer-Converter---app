import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/document_model.dart';
import '../../domain/entities/folder_model.dart';

/// Handles all SQLite operations for scanned documents and folders.
class DocumentService {
  Database? _database;
  static const String _docsTable = 'documents';
  static const String _foldersTable = 'folders';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'scanned_documents.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_foldersTable (
        id TEXT PRIMARY KEY,
        folderName TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $_docsTable (
        id TEXT PRIMARY KEY,
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        extractedText TEXT,
        createdAt TEXT NOT NULL,
        fileType TEXT NOT NULL,
        folderId TEXT,
        thumbnailPath TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop old tables and recreate with new schema
      await db.execute('DROP TABLE IF EXISTS $_docsTable');
      await db.execute('DROP TABLE IF EXISTS $_foldersTable');
      await _createTables(db, newVersion);
    }
  }

  // ─────────────────────────── DOCUMENTS ───────────────────────────

  Future<DocumentModel> saveDocument({
    required String filePath,
    required String fileName,
    required String extractedText,
    required String fileType,
    String? folderId,
    String? thumbnailPath,
  }) async {
    final db = await database;
    final id = const Uuid().v4();
    final doc = DocumentModel(
      id: id,
      filePath: filePath,
      fileName: fileName,
      extractedText: extractedText,
      createdAt: DateTime.now(),
      fileType: fileType,
      folderId: folderId,
      thumbnailPath: thumbnailPath,
    );
    await db.insert(_docsTable, doc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return doc;
  }

  Future<void> updateDocument(DocumentModel doc) async {
    final db = await database;
    await db.update(
      _docsTable,
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> renameDocument(String id, String newName) async {
    final db = await database;
    await db.update(
      _docsTable,
      {'fileName': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> moveToFolder(String docId, String? folderId) async {
    final db = await database;
    await db.update(
      _docsTable,
      {'folderId': folderId},
      where: 'id = ?',
      whereArgs: [docId],
    );
  }

  Future<List<DocumentModel>> getAllDocuments({String? folderId, bool isRoot = false}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (folderId != null) {
      maps = await db.query(_docsTable,
          where: 'folderId = ?', whereArgs: [folderId], orderBy: 'createdAt DESC');
    } else if (isRoot) {
      maps = await db.query(_docsTable,
          where: 'folderId IS NULL', orderBy: 'createdAt DESC');
    } else {
      maps = await db.query(_docsTable, orderBy: 'createdAt DESC');
    }
    return maps.map(DocumentModel.fromMap).toList();
  }

  Future<List<DocumentModel>> searchDocuments(String query) async {
    final db = await database;
    final maps = await db.query(
      _docsTable,
      where: 'extractedText LIKE ? OR fileName LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map(DocumentModel.fromMap).toList();
  }

  Future<void> deleteDocument(String id) async {
    final db = await database;
    await db.delete(_docsTable, where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────── FOLDERS ───────────────────────────

  Future<FolderModel> createFolder(String name) async {
    final db = await database;
    final folder = FolderModel(
      id: const Uuid().v4(),
      folderName: name,
      createdAt: DateTime.now(),
    );
    await db.insert(_foldersTable, folder.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return folder;
  }

  Future<List<FolderModel>> getAllFolders() async {
    final db = await database;
    final maps = await db.query(_foldersTable, orderBy: 'createdAt DESC');
    return maps.map(FolderModel.fromMap).toList();
  }

  Future<void> deleteFolder(String id) async {
    final db = await database;
    // Unassign documents from this folder
    await db.update(_docsTable, {'folderId': null},
        where: 'folderId = ?', whereArgs: [id]);
    await db.delete(_foldersTable, where: 'id = ?', whereArgs: [id]);
  }
}
