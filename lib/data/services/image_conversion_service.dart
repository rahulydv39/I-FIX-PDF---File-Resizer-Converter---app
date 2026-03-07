/// Image Conversion Service
/// Handles image-to-image conversion (resize, compress, format change)
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/image_item.dart';
import '../../domain/entities/image_settings.dart';
import 'file_export_service.dart';

/// Result of a single image conversion
class ImageConversionResult {
  /// Original image
  final ImageItem originalImage;

  /// Path to converted image
  final String outputPath;

  /// Original size in bytes
  final int originalSizeBytes;

  /// Converted size in bytes
  final int convertedSizeBytes;

  /// Original dimensions
  final int originalWidth;
  final int originalHeight;

  /// New dimensions
  final int newWidth;
  final int newHeight;

  const ImageConversionResult({
    required this.originalImage,
    required this.outputPath,
    required this.originalSizeBytes,
    required this.convertedSizeBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.newWidth,
    required this.newHeight,
  });

  /// Compression ratio percentage
  double get compressionRatio =>
      ((originalSizeBytes - convertedSizeBytes) / originalSizeBytes * 100);

  /// Size reduction as readable string
  String get sizeReduction {
    final reduction = originalSizeBytes - convertedSizeBytes;
    if (reduction > 0) {
      return '-${(reduction / 1024).toStringAsFixed(1)} KB';
    } else {
      return '+${(-reduction / 1024).toStringAsFixed(1)} KB';
    }
  }
}

/// Result of batch image conversion
class BatchConversionResult {
  /// Individual results
  final List<ImageConversionResult> results;

  /// Total processing time in milliseconds
  final int processingTimeMs;

  /// Number of successful conversions
  final int successCount;

  /// Number of failed conversions
  final int failureCount;

  const BatchConversionResult({
    required this.results,
    required this.processingTimeMs,
    required this.successCount,
    required this.failureCount,
  });

  /// Total size saved in bytes
  int get totalSizeSaved {
    return results.fold<int>(
      0,
      (sum, r) => sum + (r.originalSizeBytes - r.convertedSizeBytes),
    );
  }

  /// Formatted total size saved
  String get formattedSizeSaved {
    final kb = totalSizeSaved / 1024;
    if (kb.abs() > 1024) {
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '${kb.toStringAsFixed(1)} KB';
  }
}

/// Service for converting images to other formats/sizes
class ImageConversionService {
  final FileExportService _exportService;

  ImageConversionService({
    FileExportService? exportService,
  }) : _exportService = exportService ?? FileExportService();

  /// Convert a single image
  Future<ImageConversionResult> convertImage({
    required ImageItem image,
    required ImageSettings settings,
    String? outputPath,
  }) async {
    // Load image
    final file = File(image.path);
    final bytes = await file.readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      throw ImageConversionException('Failed to decode image: ${image.path}');
    }

    final originalWidth = originalImage.width;
    final originalHeight = originalImage.height;

    // Process image
    img.Image processedImage = originalImage;

    // Apply resize
    processedImage = _applyResize(processedImage, settings);

    // Apply grayscale if enabled
    if (settings.grayscale) {
      processedImage = img.grayscale(processedImage);
    }

    // Encode to target format with target size optimization if enabled
    Uint8List outputBytes;
    
    // Check if target size is set and valid (must be > 0)
    final hasTargetSize = settings.targetSizeKb != null && settings.targetSizeKb! > 0;
    
    if (hasTargetSize) {
      print('Target size detected → using iterative compression');
      print('Target Size: ${settings.targetSizeKb} KB');
      
      // Optimize for target file size
      final targetBytes = settings.targetSizeKb! * 1024;
      outputBytes = await _optimizeForTargetSize(
        image: processedImage,
        settings: settings,
        targetBytes: targetBytes,
      );
      
      print('Final output size: ${(outputBytes.length / 1024).toStringAsFixed(2)} KB');
    } else {
      print('No target size detected → using normal compression');
      // Use standard quality encoding
      outputBytes = _encodeWithQuality(
        processedImage,
        settings.outputFormat,
        settings.quality,
      );
    }

    // Get MIME type
    final mimeType = _getMimeType(settings.outputFormat);
    
    // Generate filename with IMG_ prefix
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final filename = 'IMG_$timestamp.${settings.outputFormat.extension}';
    
    // Export file using FileExportService
    final exportedFile = await _exportService.exportFile(
      bytes: outputBytes,
      filename: filename,
      mimeType: mimeType,
      fileType: ExportFileType.image,
    );

    return ImageConversionResult(
      originalImage: image,
      outputPath: exportedFile.path,
      originalSizeBytes: bytes.length,
      convertedSizeBytes: exportedFile.sizeBytes,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      newWidth: processedImage.width,
      newHeight: processedImage.height,
    );
  }

  /// Convert multiple images (batch mode)
  Future<BatchConversionResult> convertBatch({
    required List<ImageItem> images,
    required ImageSettings settings,
    void Function(int current, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = <ImageConversionResult>[];
    int successCount = 0;
    int failureCount = 0;

    for (int i = 0; i < images.length; i++) {
      onProgress?.call(i + 1, images.length);

      try {
        final result = await convertImage(
          image: images[i],
          settings: settings,
        );
        results.add(result);
        successCount++;
      } catch (e) {
        failureCount++;
        // Continue with other images
      }
    }

    stopwatch.stop();

    return BatchConversionResult(
      results: results,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      successCount: successCount,
      failureCount: failureCount,
    );
  }

  /// Get MIME type for output format
  String _getMimeType(OutputFormat format) {
    switch (format) {
      case OutputFormat.jpeg:
        return 'image/jpeg';
      case OutputFormat.png:
        return 'image/png';
      case OutputFormat.webp:
        return 'image/webp';
      case OutputFormat.heic:
        return 'image/heic';
    }
  }

  /// Apply resize transformations
  img.Image _applyResize(img.Image image, ImageSettings settings) {
    switch (settings.resizeMode) {
      case ResizeMode.original:
        return image;

      case ResizeMode.percentage:
        final newWidth = (image.width * settings.resizePercentage / 100).round();
        final newHeight =
            (image.height * settings.resizePercentage / 100).round();
        return img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );

      case ResizeMode.custom:
        final (width, height) = settings.effectiveDimensions;
        if (width != null && height != null) {
          if (settings.lockAspectRatio) {
            // Fit within bounds while maintaining aspect ratio
            return img.copyResize(
              image,
              width: width,
              height: height,
              interpolation: img.Interpolation.linear,
            );
          } else {
            // Exact dimensions (may distort)
            return img.copyResize(
              image,
              width: width,
              height: height,
              interpolation: img.Interpolation.linear,
            );
          }
        } else if (width != null) {
          return img.copyResize(
            image,
            width: width,
            interpolation: img.Interpolation.linear,
          );
        } else if (height != null) {
          return img.copyResize(
            image,
            height: height,
            interpolation: img.Interpolation.linear,
          );
        }
        return image;

      case ResizeMode.preset:
        final preset = settings.dimensionPreset;
        if (preset != null) {
          return img.copyResize(
            image,
            width: preset.width,
            height: preset.height,
            interpolation: img.Interpolation.linear,
          );
        }
        return image;
    }
  }

  /// Generate output path for converted image
  Future<String> _generateOutputPath(
      ImageItem image, OutputFormat format) async {
    final directory = await _getOutputDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = image.fileName.split('.').first;
    return '$directory/${baseName}_converted_$timestamp.${format.extension}';
  }

  /// Get output directory
  Future<String> _getOutputDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final outputDir =
        Directory('${appDocDir.path}/${AppConstants.convertedImagesFolder}');

    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return outputDir.path;
  }

  /// Estimate output size for given settings
  int estimateOutputSize(ImageItem image, ImageSettings settings) {
    // Rough estimation based on quality and dimensions
    double sizeFactor = settings.quality / 100;

    // Format factor
    switch (settings.outputFormat) {
      case OutputFormat.jpeg:
        sizeFactor *= 0.15; // JPEG compresses well
        break;
      case OutputFormat.png:
        sizeFactor *= 0.8; // PNG is lossless, larger
        break;
      case OutputFormat.webp:
        sizeFactor *= 0.1; // WebP compresses better
        break;
      case OutputFormat.heic:
        sizeFactor *= 0.12; // HEIC compresses very well
        break;
    }

    // Resize factor
    if (settings.resizeMode == ResizeMode.percentage) {
      final scale = settings.resizePercentage / 100;
      sizeFactor *= scale * scale; // Area scales quadratically
    }

    return (image.sizeBytes * sizeFactor).round();
  }

  /// Optimize image to hit target file size using safe sequential compression algorithm
  Future<Uint8List> _optimizeForTargetSize({
    required img.Image image,
    required ImageSettings settings,
    required int targetBytes,
  }) async {
    print('🎯 TARGET SIZE OPTIMIZATION START');
    print('   Original: ${image.width}x${image.height}');
    print('   Target: ${(targetBytes / 1024).toStringAsFixed(1)} KB');
    print('   Format: ${settings.outputFormat.displayName}');

    // Step 3: Validate Target Size
    int safeTargetBytes = targetBytes;
    if (safeTargetBytes < 10 * 1024) {
      print('⚠️ Target size too small, setting absolute minimum to 10KB');
      safeTargetBytes = 10 * 1024;
    }

    try {
      // Step 6: Memory Safety - single decoded image reused
      img.Image workingImage = image;
      
      // Step 1: Implement Safe Compression Algorithm
      int quality = 95;
      final int minQuality = 20;
      final int maxAttempts = 10;
      int attempts = 0;
      
      Uint8List? bestBytes;
      int bestDiff = double.maxFinite.toInt();

      while (attempts < maxAttempts) {
        attempts++;
        
        // Encode with current quality
        Uint8List encodedBytes = _encodeWithQuality(workingImage, settings.outputFormat, quality);
        
        int diff = (encodedBytes.length - safeTargetBytes).abs();
        final sizeKB = encodedBytes.length / 1024;
        final targetKB = safeTargetBytes / 1024;
        
        // Step 7: Logging
        print('   📊 Attempt $attempts: Q=$quality, Size=${sizeKB.toStringAsFixed(1)}KB (target: ${targetKB.toStringAsFixed(1)}KB)');
        
        // Save best effort
        if (diff < bestDiff) {
          bestDiff = diff;
          bestBytes = encodedBytes;
        }
        
        // If file size <= target size -> stop
        if (encodedBytes.length <= safeTargetBytes) {
          print('   ✅ Target achieved! Final: ${sizeKB.toStringAsFixed(1)}KB');
          return encodedBytes;
        }
        
        // Otherwise reduce quality
        quality -= 10;
        
        // Step 2: Add Image Resizing Fallback if quality gets too low
        if (quality < minQuality && encodedBytes.length > safeTargetBytes) {
          print('   🔽 Quality reached minimum, applying resize fallback by 10%');
          workingImage = img.copyResize(
            workingImage,
            width: (workingImage.width * 0.9).round(),
            height: (workingImage.height * 0.9).round(),
            interpolation: img.Interpolation.linear,
          );
          // Reset quality slightly to try compressing the smaller image without brutal artifacting
          quality = 70; 
        }
      }
      
      // Step 4: Prevent Infinite Loop (max attempts reached)
      if (bestBytes != null) {
        print('   ⚠️ Max attempts reached, returning best effort: ${(bestBytes.length / 1024).toStringAsFixed(1)} KB');
        return bestBytes;
      }
      
      return _encodeWithQuality(image, settings.outputFormat, 80); // Failsafe
      
    } catch (e) {
      // Step 5: Handle Exceptions
      print('❌ Compression failed with error: $e');
      // Return a basic compressed version if logic fails completely
      return _encodeWithQuality(image, settings.outputFormat, 60);
    }
  }

  /// Encode image with specific quality setting
  Uint8List _encodeWithQuality(
    img.Image image,
    OutputFormat format,
    int quality,
  ) {
    switch (format) {
      case OutputFormat.jpeg:
        return img.encodeJpg(image, quality: quality);
      case OutputFormat.png:
        // PNG is lossless, quality doesn't apply
        // For size reduction, we can use compression level
        return img.encodePng(image, level: 9);
      case OutputFormat.webp:
        // WebP encoding with quality (fallback to JPEG for now)
        return img.encodeJpg(image, quality: quality);
      case OutputFormat.heic:
        // HEIC encoding not directly supported, fallback to JPEG
        return img.encodeJpg(image, quality: quality);
    }
  }
}

/// Exception for image conversion errors
class ImageConversionException implements Exception {
  final String message;
  ImageConversionException(this.message);

  @override
  String toString() => 'ImageConversionException: $message';
}
