/// Usage Statistics Service
/// Tracks and persists user statistics like PDFs created and images converted
/// Syncs with Cloud Firestore for cross-session persistence
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_sync_service.dart';

/// Service for tracking and persisting usage statistics
class UsageStatsService {
  static const String _keyPdfsCreated = 'total_pdfs_created';
  static const String _keyImagesConverted = 'total_images_converted';
  
  SharedPreferences? _prefs;
  FirestoreSyncService? _syncService;
  
  // In-memory cache for performance
  int _cachedPdfsCreated = 0;
  int _cachedImagesConverted = 0;
  bool _isInitialized = false;
  
  /// Set the Firestore sync service (called from DI after construction)
  void setSyncService(FirestoreSyncService syncService) {
    _syncService = syncService;
  }
  
  /// Initialize the service and load cached values
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    
    // Load existing local values or default to 0
    _cachedPdfsCreated = _prefs!.getInt(_keyPdfsCreated) ?? 0;
    _cachedImagesConverted = _prefs!.getInt(_keyImagesConverted) ?? 0;
    
    _isInitialized = true;
    
    print('📊 Usage Stats Initialized:');
    print('   PDFs Created: $_cachedPdfsCreated');
    print('   Images Converted: $_cachedImagesConverted');
  }
  
  /// Load stats from Firestore and merge with local.
  /// Remote values always win (they represent the true cumulative count).
  Future<void> loadFromFirestore() async {
    if (_syncService == null || !_syncService!.isAuthenticated) return;
    await _ensureInitialized();

    final remote = await _syncService!.loadStats();
    if (remote == null) {
      // No remote data — push local stats to Firestore (first-time sync)
      if (_cachedPdfsCreated > 0 || _cachedImagesConverted > 0) {
        await _syncService!.saveStats(
          totalImages: _cachedImagesConverted,
          totalPdfs: _cachedPdfsCreated,
        );
        print('📊 First-time sync: pushed local stats to Firestore');
      }
      return;
    }

    // Use the higher value between local and remote
    final remotePdfs = remote['totalPdfs'] ?? 0;
    final remoteImages = remote['totalImages'] ?? 0;

    _cachedPdfsCreated = remotePdfs > _cachedPdfsCreated ? remotePdfs : _cachedPdfsCreated;
    _cachedImagesConverted = remoteImages > _cachedImagesConverted ? remoteImages : _cachedImagesConverted;

    // Persist merged values locally
    await _prefs!.setInt(_keyPdfsCreated, _cachedPdfsCreated);
    await _prefs!.setInt(_keyImagesConverted, _cachedImagesConverted);

    print('📊 Stats loaded from Firestore:');
    print('   PDFs Created: $_cachedPdfsCreated');
    print('   Images Converted: $_cachedImagesConverted');
  }
  
  /// Increment PDF created count
  Future<void> incrementPdfCreated() async {
    await _ensureInitialized();
    
    _cachedPdfsCreated++;
    await _prefs!.setInt(_keyPdfsCreated, _cachedPdfsCreated);
    
    // Sync to Firestore
    _syncService?.incrementStat(field: 'totalPdfs');
    
    print('📊 PDF count updated → $_cachedPdfsCreated');
  }
  
  /// Increment image converted count
  Future<void> incrementImageConverted() async {
    await _ensureInitialized();
    
    _cachedImagesConverted++;
    await _prefs!.setInt(_keyImagesConverted, _cachedImagesConverted);
    
    // Sync to Firestore
    _syncService?.incrementStat(field: 'totalImages');
    
    print('📊 Image count updated → $_cachedImagesConverted');
  }
  
  /// Get total PDFs created
  Future<int> getPdfCreatedCount() async {
    await _ensureInitialized();
    return _cachedPdfsCreated;
  }
  
  /// Get total images converted
  Future<int> getImageConvertedCount() async {
    await _ensureInitialized();
    return _cachedImagesConverted;
  }
  
  /// Get both stats at once (more efficient for UI)
  Future<UsageStats> getStats() async {
    await _ensureInitialized();
    return UsageStats(
      pdfsCreated: _cachedPdfsCreated,
      imagesConverted: _cachedImagesConverted,
    );
  }
  
  /// Reset all statistics (for testing or user request)
  Future<void> resetStats() async {
    await _ensureInitialized();
    
    _cachedPdfsCreated = 0;
    _cachedImagesConverted = 0;
    
    await _prefs!.setInt(_keyPdfsCreated, 0);
    await _prefs!.setInt(_keyImagesConverted, 0);
    
    print('📊 Usage stats reset to 0');
  }
  
  /// Ensure service is initialized before any operation
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}

/// Usage statistics data class
class UsageStats {
  final int pdfsCreated;
  final int imagesConverted;
  
  const UsageStats({
    required this.pdfsCreated,
    required this.imagesConverted,
  });
  
  /// Get total conversions (PDFs + Images)
  int get totalConversions => pdfsCreated + imagesConverted;
}
