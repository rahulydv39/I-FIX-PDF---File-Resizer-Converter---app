/// PDF Repository Interface
/// Defines the contract for PDF generation operations
library;

import '../entities/image_item.dart';
import '../entities/pdf_settings.dart';

/// Result of PDF generation
class PdfResult {
  /// Path to the generated PDF file
  final String filePath;

  /// Final file size in bytes
  final int sizeBytes;

  /// Number of pages in the PDF
  final int pageCount;

  /// Time taken to generate in milliseconds
  final int generationTimeMs;

  const PdfResult({
    required this.filePath,
    required this.sizeBytes,
    required this.pageCount,
    required this.generationTimeMs,
  });

  /// Formatted file size
  String get formattedSize {
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    } else if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// Size estimation for PDF
class SizeEstimate {
  /// Estimated size in bytes
  final int estimatedBytes;

  /// Confidence level (0.0 - 1.0)
  final double confidence;

  const SizeEstimate({
    required this.estimatedBytes,
    required this.confidence,
  });

  /// Formatted estimated size
  String get formattedSize {
    if (estimatedBytes < 1024) {
      return '$estimatedBytes B';
    } else if (estimatedBytes < 1024 * 1024) {
      return '${(estimatedBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(estimatedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// Repository interface for PDF operations
abstract class PdfRepository {
  /// Generate PDF from images with given settings
  Future<PdfResult> generatePdf({
    required List<ImageItem> images,
    required PdfSettings settings,
    required String outputPath,
    void Function(int current, int total)? onProgress,
  });

  /// Estimate output PDF size
  Future<SizeEstimate> estimateSize({
    required List<ImageItem> images,
    required PdfSettings settings,
  });

  /// Generate PDF with size optimization
  /// Iteratively adjusts settings to reach target size
  Future<PdfResult> generateOptimizedPdf({
    required List<ImageItem> images,
    required PdfSettings settings,
    required int targetSizeBytes,
    required String outputPath,
    void Function(int pass, int totalPasses)? onOptimizationProgress,
  });

  /// Get the default output directory for PDFs
  Future<String> getOutputDirectory();

  /// Share the generated PDF
  Future<void> sharePdf(String filePath);
}
