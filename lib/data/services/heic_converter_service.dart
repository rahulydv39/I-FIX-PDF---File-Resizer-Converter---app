/// HEIC Converter Service
/// Handles conversion of HEIC images to processable JPEG format
library;

import 'dart:io';
import 'package:platform_image_converter/platform_image_converter.dart';
import 'package:path_provider/path_provider.dart';

/// Service for converting HEIC images to JPEG for cross-platform compatibility
class HeicConverterService {
  // Track temporary files for cleanup
  final List<String> _tempFiles = [];

  /// Convert HEIC file to processable JPEG format
  /// 
  /// Returns converted JPEG file if input is HEIC, otherwise returns original file.
  /// Converted files are stored in app's temporary directory.
  Future<File> convertHeicToProcessable(File inputFile) async {
    try {
      // Check if file is HEIC
      if (!_isHeicFile(inputFile.path)) {
        return inputFile;
      }

      print('🔄 HEIC detected: ${_getFileName(inputFile.path)}');
      print('   Converting to JPEG...');

      // Generate temp output path
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = _getFileName(inputFile.path)
          .replaceAll('.heic', '')
          .replaceAll('.HEIC', '')
          .replaceAll('.heif', '')
          .replaceAll('.HEIF', '');
      final outputPath = '${tempDir.path}/heic_${fileName}_$timestamp.jpg';

      // Convert HEIC to JPEG using platform_image_converter
      final bytes = await inputFile.readAsBytes();
      
      final convertedBytes = await ImageConverter.convert(
        inputData: bytes,
        format: OutputFormat.jpeg,
        quality: 95, // High quality for conversion
      );

      // Write converted bytes to temp file
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(convertedBytes);

      // Track for cleanup
      _tempFiles.add(outputPath);

      final size = outputFile.lengthSync();
      print('   ✅ Conversion successful');
      print('   Output: ${(size / 1024).toStringAsFixed(1)} KB');
      print('   Temp file: $outputPath');

      return outputFile;
    } catch (e) {
      print('   ❌ HEIC conversion failed: $e');
      print('   Attempting to use original file (may work on iOS)');

      // Fallback: try to use original file
      // This might work on iOS where native HEIC support exists
      return inputFile;
    }
  }

  /// Check if file is HEIC based on extension
  bool _isHeicFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    return extension == 'heic' || extension == 'heif';
  }

  /// Extract filename from path
  String _getFileName(String path) {
    return path.split('/').last;
  }

  /// Clean up all temporary HEIC conversion files
  Future<void> cleanupTempFiles() async {
    if (_tempFiles.isEmpty) return;

    print('🧹 Cleaning up ${_tempFiles.length} HEIC temp file(s)...');

    int deleted = 0;
    for (final path in _tempFiles) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          deleted++;
        }
      } catch (e) {
        print('   ⚠️  Failed to delete temp file: $path - $e');
      }
    }

    print('   ✅ Deleted $deleted temp file(s)');
    _tempFiles.clear();
  }

  /// Get count of tracked temporary files
  int get tempFileCount => _tempFiles.length;
}

/// Exception thrown when HEIC conversion fails
class HeicConversionException implements Exception {
  final String message;
  HeicConversionException(this.message);

  @override
  String toString() => 'HeicConversionException: $message';
}
