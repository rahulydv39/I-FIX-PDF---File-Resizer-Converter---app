/// Size Optimizer Service
/// Implements iterative optimization to achieve target PDF file size
library;

import 'dart:math';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/image_item.dart';
import '../../domain/entities/pdf_settings.dart';
import 'pdf_generator_service.dart';
import 'image_processor_service.dart';

/// Result of size optimization
class OptimizationResult {
  /// Path to the optimized PDF
  final String filePath;

  /// Final file size in bytes
  final int finalSizeBytes;

  /// Target size in bytes
  final int targetSizeBytes;

  /// Whether target was achieved within tolerance
  final bool targetAchieved;

  /// Number of optimization passes used
  final int passesUsed;

  /// Final settings used
  final PdfSettings finalSettings;

  const OptimizationResult({
    required this.filePath,
    required this.finalSizeBytes,
    required this.targetSizeBytes,
    required this.targetAchieved,
    required this.passesUsed,
    required this.finalSettings,
  });

  /// Difference from target as percentage
  double get differencePercent {
    return ((finalSizeBytes - targetSizeBytes) / targetSizeBytes * 100).abs();
  }

  /// Whether the final size is within acceptable tolerance (±10%)
  bool get isWithinTolerance {
    return differencePercent <= (AppConstants.sizeTolerancePercent * 100);
  }
}

/// Service for optimizing PDF size to meet target file size
///
/// Uses iterative optimization with up to [AppConstants.maxOptimizationPasses]
/// passes to adjust quality and DPI settings to achieve target size.
class SizeOptimizerService {
  final PdfGeneratorService _pdfGenerator;
  // Note: _imageProcessor kept for future advanced optimization features
  // ignore: unused_field
  final ImageProcessorService _imageProcessor;

  SizeOptimizerService({
    PdfGeneratorService? pdfGenerator,
    ImageProcessorService? imageProcessor,
  })  : _pdfGenerator = pdfGenerator ?? PdfGeneratorService(),
        _imageProcessor = imageProcessor ?? ImageProcessorService();

  /// Generate PDF optimized to target size
  ///
  /// Uses iterative refinement:
  /// 1. Generate with initial settings
  /// 2. If size differs significantly, adjust settings
  /// 3. Repeat until within tolerance or max passes reached
  Future<OptimizationResult> generateOptimizedPdf({
    required List<ImageItem> images,
    required PdfSettings initialSettings,
    required int targetSizeBytes,
    String? outputPath,
    void Function(int pass, int totalPasses)? onOptimizationProgress,
  }) async {
    PdfSettings currentSettings = initialSettings;
    PdfGenerationResult? result;
    int passesUsed = 0;

    // Iterative optimization loop
    for (int pass = 1; pass <= AppConstants.maxOptimizationPasses; pass++) {
      passesUsed = pass;
      onOptimizationProgress?.call(pass, AppConstants.maxOptimizationPasses);

      // Generate PDF with current settings
      result = await _pdfGenerator.generatePdf(
        images: images,
        settings: currentSettings,
        outputPath: outputPath,
      );

      // Check if we're within tolerance
      final sizeDifference = result.sizeBytes - targetSizeBytes;
      final differencePercent = (sizeDifference / targetSizeBytes).abs();

      if (differencePercent <= AppConstants.sizeTolerancePercent) {
        // Target achieved within tolerance
        return OptimizationResult(
          filePath: result.filePath,
          finalSizeBytes: result.sizeBytes,
          targetSizeBytes: targetSizeBytes,
          targetAchieved: true,
          passesUsed: passesUsed,
          finalSettings: currentSettings,
        );
      }

      // Need to adjust settings for next pass
      if (pass < AppConstants.maxOptimizationPasses) {
        currentSettings = _adjustSettings(
          currentSettings,
          result.sizeBytes,
          targetSizeBytes,
        );
      }
    }

    // Return result from last pass even if not within tolerance
    return OptimizationResult(
      filePath: result!.filePath,
      finalSizeBytes: result.sizeBytes,
      targetSizeBytes: targetSizeBytes,
      targetAchieved: false,
      passesUsed: passesUsed,
      finalSettings: currentSettings,
    );
  }

  /// Adjust settings based on current vs target size
  PdfSettings _adjustSettings(
    PdfSettings current,
    int currentSize,
    int targetSize,
  ) {
    // Calculate the ratio needed
    final ratio = targetSize / currentSize;

    // Adjust quality - this has the most significant impact
    // Quality affects size roughly linearly
    int newQuality = (current.quality * ratio).round();

    // Clamp quality to valid range
    newQuality = max(AppConstants.minQuality, min(AppConstants.maxQuality, newQuality));

    // If quality adjustment alone isn't enough, also adjust DPI
    DpiPreset newDpiPreset = current.dpiPreset;
    int? newCustomDpi = current.customDpi;

    if (ratio < 0.5 && current.dpiPreset != DpiPreset.screen) {
      // Need significant reduction - lower DPI
      if (current.dpiPreset == DpiPreset.highQuality) {
        newDpiPreset = DpiPreset.standard;
      } else if (current.dpiPreset == DpiPreset.standard) {
        newDpiPreset = DpiPreset.screen;
      } else if (current.dpiPreset == DpiPreset.custom &&
          current.customDpi != null &&
          current.customDpi! > 100) {
        // Reduce custom DPI
        newCustomDpi = (current.customDpi! * sqrt(ratio)).round();
        newCustomDpi = max(72, newCustomDpi);
      }
    } else if (ratio > 2.0) {
      // Can afford higher quality - increase DPI if room
      if (current.dpiPreset == DpiPreset.screen) {
        newDpiPreset = DpiPreset.standard;
      } else if (current.dpiPreset == DpiPreset.standard &&
          newQuality >= 90) {
        newDpiPreset = DpiPreset.highQuality;
      }
    }

    return current.copyWith(
      quality: newQuality,
      dpiPreset: newDpiPreset,
      customDpi: newCustomDpi,
    );
  }

  /// Estimate the output size with given settings
  ///
  /// Returns estimated size in bytes
  Future<int> estimateSize({
    required List<ImageItem> images,
    required PdfSettings settings,
  }) async {
    return await _pdfGenerator.estimatePdfSize(
      images: images,
      settings: settings,
    );
  }

  /// Calculate recommended initial settings to approximate target size
  ///
  /// Provides a better starting point for optimization
  Future<PdfSettings> recommendInitialSettings({
    required List<ImageItem> images,
    required PdfSettings baseSettings,
    required int targetSizeBytes,
  }) async {
    // Get current estimated size with base settings
    final currentEstimate = await estimateSize(
      images: images,
      settings: baseSettings,
    );

    if (currentEstimate <= 0) {
      return baseSettings;
    }

    // Calculate ratio to reach target
    final ratio = targetSizeBytes / currentEstimate;

    // Recommended quality based on ratio
    int recommendedQuality;
    DpiPreset recommendedDpi;

    if (ratio >= 2.0) {
      // Can afford high quality
      recommendedQuality = AppConstants.maxQuality;
      recommendedDpi = DpiPreset.highQuality;
    } else if (ratio >= 1.0) {
      // Room for good quality
      recommendedQuality = 90;
      recommendedDpi = DpiPreset.standard;
    } else if (ratio >= 0.5) {
      // Need moderate compression
      recommendedQuality = max(60, (baseSettings.quality * ratio).round());
      recommendedDpi = DpiPreset.standard;
    } else {
      // Need aggressive compression
      recommendedQuality = max(
        AppConstants.minQuality,
        (baseSettings.quality * ratio * 1.2).round(),
      );
      recommendedDpi = DpiPreset.screen;
    }

    return baseSettings.copyWith(
      quality: recommendedQuality,
      dpiPreset: recommendedDpi,
    );
  }
}

/// Exception thrown during size optimization
class SizeOptimizationException implements Exception {
  final String message;
  SizeOptimizationException(this.message);

  @override
  String toString() => 'SizeOptimizationException: $message';
}
