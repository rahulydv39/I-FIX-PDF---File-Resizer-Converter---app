/// App Settings Service
/// Manages app settings using shared_preferences
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service for managing app settings
class AppSettingsService {
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  /// Get notifications enabled status
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  /// Set notifications enabled status
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  /// Get app storage usage in bytes
  Future<int> getStorageUsage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return await _getDirectorySize(directory);
    } catch (e) {
      return 0;
    }
  }

  /// Calculate directory size recursively
  Future<int> _getDirectorySize(Directory directory) async {
    int totalSize = 0;
    
    try {
      if (await directory.exists()) {
        await for (var entity in directory.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    
    return totalSize;
  }

  /// Clear app cache
  Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Format bytes to human-readable size
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
