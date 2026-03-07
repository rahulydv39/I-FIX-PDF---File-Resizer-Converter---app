/// Firestore Sync Service
/// Syncs usage stats and conversion history to Cloud Firestore per user
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/conversion_history_item.dart';

/// Service for syncing local data to Cloud Firestore under users/{uid}
class FirestoreSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user's UID, or null if not logged in
  String? get _uid => _auth.currentUser?.uid;

  /// Whether user is authenticated
  bool get isAuthenticated => _uid != null;

  /// Reference to the user's document: users/{uid}
  DocumentReference? get _userDoc {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// Reference to the user's history subcollection: users/{uid}/history
  CollectionReference? get _historyCollection {
    return _userDoc?.collection('history');
  }

  // ─── STATS ────────────────────────────────────────────────────────────────

  /// Increment a stat field (totalImages or totalPdfs) atomically
  Future<void> incrementStat({required String field}) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      await doc.set(
        {field: FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      print('🔥 Firestore: $field incremented');
    } catch (e) {
      print('⚠️ Firestore incrementStat failed: $e');
    }
  }

  /// Load stats from Firestore
  /// Returns {totalImages: int, totalPdfs: int} or null if unavailable
  Future<Map<String, int>?> loadStats() async {
    final doc = _userDoc;
    if (doc == null) return null;

    try {
      final snapshot = await doc.get();
      if (!snapshot.exists) return null;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return null;

      return {
        'totalImages': (data['totalImages'] as num?)?.toInt() ?? 0,
        'totalPdfs': (data['totalPdfs'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      print('⚠️ Firestore loadStats failed: $e');
      return null;
    }
  }

  /// Save full stats to Firestore (used for initial sync)
  Future<void> saveStats({
    required int totalImages,
    required int totalPdfs,
  }) async {
    final doc = _userDoc;
    if (doc == null) return;

    try {
      await doc.set(
        {
          'totalImages': totalImages,
          'totalPdfs': totalPdfs,
        },
        SetOptions(merge: true),
      );
      print('🔥 Firestore: stats saved (images=$totalImages, pdfs=$totalPdfs)');
    } catch (e) {
      print('⚠️ Firestore saveStats failed: $e');
    }
  }

  // ─── HISTORY ──────────────────────────────────────────────────────────────

  /// Add a history entry to Firestore
  Future<void> addHistoryEntry(ConversionHistoryItem item) async {
    final collection = _historyCollection;
    if (collection == null) return;

    try {
      await collection.add({
        'fileName': item.fileName,
        'filePath': item.filePath,
        'fileType': item.fileType == ConversionFileType.image ? 'image' : 'pdf',
        'createdAt': Timestamp.fromDate(item.createdAt),
        'fileSize': item.fileSize,
      });
      print('🔥 Firestore: history entry added — ${item.fileName}');
    } catch (e) {
      print('⚠️ Firestore addHistoryEntry failed: $e');
    }
  }

  /// Load all history entries from Firestore (newest first)
  Future<List<ConversionHistoryItem>> loadHistory() async {
    final collection = _historyCollection;
    if (collection == null) return [];

    try {
      final snapshot = await collection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ConversionHistoryItem(
          fileName: data['fileName'] as String? ?? '',
          filePath: data['filePath'] as String? ?? '',
          fileType: (data['fileType'] as String?) == 'image'
              ? ConversionFileType.image
              : ConversionFileType.pdf,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      print('⚠️ Firestore loadHistory failed: $e');
      return [];
    }
  }

  /// Upload local history entries to Firestore (for initial sync)
  Future<void> syncLocalHistoryToFirestore(List<ConversionHistoryItem> items) async {
    final collection = _historyCollection;
    if (collection == null) return;

    try {
      // Use batched writes for efficiency
      final batch = _firestore.batch();
      for (final item in items) {
        final docRef = collection.doc();
        batch.set(docRef, {
          'fileName': item.fileName,
          'filePath': item.filePath,
          'fileType': item.fileType == ConversionFileType.image ? 'image' : 'pdf',
          'createdAt': Timestamp.fromDate(item.createdAt),
          'fileSize': item.fileSize,
        });
      }
      await batch.commit();
      print('🔥 Firestore: ${items.length} history entries synced');
    } catch (e) {
      print('⚠️ Firestore syncLocalHistory failed: $e');
    }
  }
}
