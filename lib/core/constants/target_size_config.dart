/// Target Size Configuration
/// Constants for fixed target file size options
library;

/// Available target file sizes in bytes
class TargetSizeConfig {
  /// Fixed size options in KB
  static const List<int> availableSizesKb = [10, 20, 40, 50, 100];

  /// Fixed size options in bytes
  static const List<int> availableSizesBytes = [
    10 * 1024,  // 10 KB
    20 * 1024,  // 20 KB
    40 * 1024,  // 40 KB
    50 * 1024,  // 50 KB
    100 * 1024, // 100 KB
  ];

  /// Default target size in KB
  static const int defaultSizeKb = 40;

  /// Default target size in bytes
  static const int defaultSizeBytes = 40 * 1024;

  /// Get UI label for a size in KB
  static String getLabel(int sizeKb) => '$sizeKb KB';

  /// Get all UI labels
  static List<String> get labels =>
      availableSizesKb.map((kb) => getLabel(kb)).toList();

  /// Convert KB to bytes
  static int kbToBytes(int kb) => kb * 1024;

  /// Convert bytes to KB
  static int bytesToKb(int bytes) => (bytes / 1024).round();

  /// Debug log for selected size
  static void logSelection(int sizeKb) {
    final bytes = kbToBytes(sizeKb);
    print('✓ Selected target size: $sizeKb KB ($bytes bytes)');
  }

  /// Validate if size is in available options
  static bool isValidSize(int sizeKb) => availableSizesKb.contains(sizeKb);

  /// Get nearest valid size
  static int getNearestValidSize(int sizeKb) {
    if (isValidSize(sizeKb)) return sizeKb;
    
    // Find nearest
    int nearest = defaultSizeKb;
    int minDiff = (sizeKb - nearest).abs();
    
    for (final size in availableSizesKb) {
      final diff = (sizeKb - size).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = size;
      }
    }
    
    return nearest;
  }
}
