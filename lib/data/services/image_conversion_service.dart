/// Image Conversion Service
/// Handles image-to-image conversion (resize, compress, format change)
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/image_item.dart';
import '../../domain/entities/image_settings.dart';
import '../../core/utils/target_size_optimizer.dart';
import 'file_export_service.dart';

/// Arguments for isolate computation
class _IsolateConversionArgs {
  final Uint8List originalBytes;
  final ImageSettings settings;

  _IsolateConversionArgs({required this.originalBytes, required this.settings});
}

/// Result of isolate computation
class _IsolateConversionResult {
  final Uint8List outputBytes;
  final int originalWidth;
  final int originalHeight;
  final int newWidth;
  final int newHeight;

  _IsolateConversionResult({
    required this.outputBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.newWidth,
    required this.newHeight,
  });
}

/// The top-level isolate entry point function
Future<_IsolateConversionResult> _processImageInIsolate(
  _IsolateConversionArgs args,
) async {
  final originalImage = img.decodeImage(args.originalBytes);
  if (originalImage == null) {
    throw Exception('Failed to decode image');
  }

  final originalWidth = originalImage.width;
  final originalHeight = originalImage.height;

  img.Image processedImage = originalImage;

  final hasTargetSize =
      args.settings.targetSizeKb != null && args.settings.targetSizeKb! > 0;

  // Determine if any transformation is actually needed
  final needsResize = args.settings.resizeMode != ResizeMode.original;
  final needsGrayscale = args.settings.grayscale;
  final hasTransformation = needsResize || needsGrayscale;

  late Uint8List outputBytes;

  if (hasTargetSize) {
    // ── Target-size path ───────────────────────────────────────────────────
    // Apply resize BEFORE handing bytes to TargetSizeOptimizer.
    // ❌ DO NOT encode at quality 100 — that inflates PNG/WebP and breaks
    //    the binary search in TargetSizeOptimizer.
    // ✅ Always produce a JPEG baseline so the optimizer can work correctly.
    processedImage = ImageConversionService.applyResize(
      processedImage,
      args.settings,
    );
    if (needsGrayscale) {
      processedImage = img.grayscale(processedImage);
    }

    print('Resize applied: ${processedImage.width}x${processedImage.height}');

    // JPEG at q95 — the optimizer (compress or expand) runs on the main thread.
    outputBytes = Uint8List.fromList(
      img.encodeJpg(processedImage, quality: 95),
    );
  } else if (!hasTransformation) {
    // ── No target size AND no transformation ──────────────────────────────
    // Return the original bytes as-is to avoid UNNECESSARY re-encoding which
    // would only inflate the file size (quality-100 decode→encode always grows).
    print(
      'No target size, no transformation → returning original bytes unchanged',
    );
    outputBytes = args.originalBytes;
  } else {
    // ── No target size BUT has resize / grayscale ─────────────────────────
    // Apply transformations, then encode at high quality in the chosen format.
    print('No target size detected → FAST CONVERT with transformations');
    processedImage = ImageConversionService.applyResize(
      processedImage,
      args.settings,
    );
    if (needsGrayscale) {
      processedImage = img.grayscale(processedImage);
    }

    print('Resize applied: ${processedImage.width}x${processedImage.height}');

    outputBytes = ImageConversionService.encodeWithQuality(
      processedImage,
      args.settings.outputFormat,
      95,
    );
  }

  return _IsolateConversionResult(
    outputBytes: outputBytes,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    newWidth: processedImage.width,
    newHeight: processedImage.height,
  );
}

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

  ImageConversionService({FileExportService? exportService})
    : _exportService = exportService ?? FileExportService();

  /// Convert a single image
  Future<ImageConversionResult> convertImage({
    required ImageItem image,
    required ImageSettings settings,
    String? outputPath,
  }) async {
    // Load image
    final file = File(image.path);
    final bytes = await file.readAsBytes();
    // Run heavy CPU tasks (decode, resize, upscale) in background isolate
    final isolateResult = await compute(
      _processImageInIsolate,
      _IsolateConversionArgs(originalBytes: bytes, settings: settings),
    );

    Uint8List outputBytes = isolateResult.outputBytes;
    final originalWidth = isolateResult.originalWidth;
    final originalHeight = isolateResult.originalHeight;
    final newWidth = isolateResult.newWidth;
    final newHeight = isolateResult.newHeight;

    // Run fast native binary search compression on the main thread
    // This uses C-code and doesn't block UI natively
    bool useTargetSize =
        settings.targetSizeKb != null && settings.targetSizeKb! > 0;
    if (useTargetSize) {
      // 1. RESIZE WIDTH/HEIGHT NOT WORKING fix
      // Ensure resize happens BEFORE compression and is actually used.
      final (targetWidth, targetHeight) = settings.effectiveDimensions;
      if (targetWidth != null || targetHeight != null) {
        img.Image? image = img.decodeImage(outputBytes);
        if (image != null) {
          int newWidth = targetWidth ?? image.width;
          int newHeight = targetHeight ?? image.height;

          image = img.copyResize(image, width: newWidth, height: newHeight);

          outputBytes = Uint8List.fromList(img.encodeJpg(image, quality: 100));
        }
      }

      outputBytes = await TargetSizeOptimizer.processTargetSize(
        inputBytes: outputBytes,
        targetKB: settings.targetSizeKb!,
        useTargetSize: true,
      );
    }

    // 4 & 5. FILE SIZE INCREASING & SAFETY CHECK fix
    if (outputBytes.length > bytes.length && !useTargetSize) {
      outputBytes = bytes; // prevent unnecessary increase
    }

    // Get MIME type
    final mimeType = _getMimeType(settings.outputFormat);

    // Generate a UNIQUE filename every time using millisecond epoch so that
    // consecutive conversions NEVER overwrite each other.
    // Custom names get a timestamp suffix appended to keep them unique.
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String filename;
    if (settings.customFileName != null &&
        settings.customFileName!.isNotEmpty) {
      // Strip any existing extension from the custom name, then re-apply.
      final base = settings.customFileName!.replaceAll(RegExp(r'\.[^.]+$'), '');
      filename = '${base}_$timestamp.${settings.outputFormat.extension}';
    } else {
      filename = 'IMG_$timestamp.${settings.outputFormat.extension}';
    }

    print('Output path: $filename');

    // Export file using FileExportService
    final exportedFile = await _exportService.exportFile(
      bytes: outputBytes,
      filename: filename,
      mimeType: mimeType,
      fileType: ExportFileType.image,
    );

    print('Output path: ${exportedFile.path}');

    return ImageConversionResult(
      originalImage: image,
      outputPath: exportedFile.path,
      originalSizeBytes: bytes.length,
      convertedSizeBytes: exportedFile.sizeBytes,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      newWidth: newWidth,
      newHeight: newHeight,
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
        final result = await convertImage(image: images[i], settings: settings);
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
  static img.Image applyResize(img.Image image, ImageSettings settings) {
    switch (settings.resizeMode) {
      case ResizeMode.original:
        return image;

      case ResizeMode.percentage:
        final newWidth =
            (image.width * settings.resizePercentage / 100).round();
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
    ImageItem image,
    OutputFormat format,
  ) async {
    final directory = await _getOutputDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = image.fileName.split('.').first;
    return '$directory/${baseName}_converted_$timestamp.${format.extension}';
  }

  /// Get output directory
  Future<String> _getOutputDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(
      '${appDocDir.path}/${AppConstants.convertedImagesFolder}',
    );

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

  /// Encode image with specific quality setting
  static Uint8List encodeWithQuality(
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
