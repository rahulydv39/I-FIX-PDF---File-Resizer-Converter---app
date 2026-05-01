/// PDF Generator Service
/// Handles PDF creation from processed images
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/image_item.dart';
import '../../domain/entities/pdf_settings.dart';
import '../../core/utils/target_size_optimizer.dart';
import 'image_processor_service.dart';
import 'file_export_service.dart';

/// Result of PDF generation
class PdfGenerationResult {
  /// Path to the generated PDF file
  final String filePath;

  /// Final file size in bytes
  final int sizeBytes;

  /// Number of pages
  final int pageCount;

  /// Generation time in milliseconds
  final int generationTimeMs;

  const PdfGenerationResult({
    required this.filePath,
    required this.sizeBytes,
    required this.pageCount,
    required this.generationTimeMs,
  });
}

/// Service for generating PDF documents from images
class PdfGeneratorService {
  final ImageProcessorService _imageProcessor;
  final FileExportService _exportService;

  PdfGeneratorService({
    ImageProcessorService? imageProcessor,
    FileExportService? exportService,
  }) : _imageProcessor = imageProcessor ?? ImageProcessorService(),
       _exportService = exportService ?? FileExportService();

  /// Generate PDF from images
  ///
  /// Each image becomes one page in the PDF.
  /// Images are processed according to [settings] before inclusion.
  Future<PdfGenerationResult> generatePdf({
    required List<ImageItem> images,
    required PdfSettings settings,
    String? outputPath,
    void Function(int current, int total)? onProgress,
    ExportFileType fileType = ExportFileType.pdf,
    String? subFolder,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Sort images by order index
    final sortedImages = List<ImageItem>.from(images)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    // Create PDF document
    final pdf = pw.Document();

    // Process each image and add as page
    for (int i = 0; i < sortedImages.length; i++) {
      final imageItem = sortedImages[i];

      // Report progress
      onProgress?.call(i + 1, sortedImages.length);

      // Process image with target size optimization if enabled
      ProcessedImage processedImage;
      if (settings.targetSize != null && settings.enableSizeOptimization) {
        // Calculate per-image target size (distribute total size evenly)
        final totalTargetBytes = settings.targetSize!.sizeInBytes;
        final perImageTargetBytes = totalTargetBytes ~/ sortedImages.length;

        processedImage = await _processImageWithTargetSize(
          imageItem,
          settings,
          perImageTargetBytes,
        );
      } else {
        // Standard processing
        processedImage = await _imageProcessor.processImage(
          imageItem,
          settings,
        );
      }

      // Calculate page size
      final pageFormat = _getPageFormat(
        settings,
        processedImage.width,
        processedImage.height,
      );

      // Create memory image for PDF
      final pdfImage = pw.MemoryImage(processedImage.bytes);

      // Add page with image
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain));
          },
        ),
      );
    }

    // Generate timestamp for filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String filename =
        settings.customFileName != null && settings.customFileName!.isNotEmpty
            ? settings.customFileName!
            : 'PDF_$timestamp';
    if (!filename.toLowerCase().endsWith('.pdf')) {
      filename += '.pdf';
    }

    // Save PDF using export service
    final bytes = await pdf.save();
    final exportedFile = await _exportService.exportFile(
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      mimeType: 'application/pdf',
      fileType: fileType,
      subFolder: subFolder,
    );

    stopwatch.stop();

    return PdfGenerationResult(
      filePath: exportedFile.path,
      sizeBytes: exportedFile.sizeBytes,
      pageCount: sortedImages.length,
      generationTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Get PDF page format based on settings and image dimensions
  PdfPageFormat _getPageFormat(
    PdfSettings settings,
    int imageWidth,
    int imageHeight,
  ) {
    switch (settings.pageSize) {
      case PageSizeType.a4:
        // A4: 595.28 x 841.89 points (210 x 297 mm)
        // Determine orientation based on image aspect ratio
        final imageAspectRatio = imageWidth / imageHeight;
        if (imageAspectRatio > 1) {
          // Landscape image → landscape A4
          return PdfPageFormat.a4.landscape;
        } else {
          // Portrait image → portrait A4
          return PdfPageFormat.a4.portrait;
        }

      case PageSizeType.letter:
        final imageAspectRatio = imageWidth / imageHeight;
        if (imageAspectRatio > 1) {
          return PdfPageFormat.letter.landscape;
        } else {
          return PdfPageFormat.letter.portrait;
        }

      case PageSizeType.auto:
        // Auto: Use image dimensions converted to points
        // At the effective DPI, convert pixels to points (72 points = 1 inch)
        // Width in inches = pixels / DPI, Width in points = inches × 72
        final dpi = settings.effectiveDpi.toDouble();
        final widthPoints = (imageWidth / dpi) * 72;
        final heightPoints = (imageHeight / dpi) * 72;

        return PdfPageFormat(widthPoints, heightPoints);
    }
  }

  /// Generate a unique output path for the PDF
  Future<String> _generateOutputPath() async {
    final directory = await getOutputDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$directory/converted_$timestamp.pdf';
  }

  /// Get the output directory for PDFs
  Future<String> getOutputDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory(
      '${appDocDir.path}/${AppConstants.outputFolder}',
    );

    // Create directory if it doesn't exist
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return outputDir.path;
  }

  /// Estimate the output size of a PDF
  Future<int> estimatePdfSize({
    required List<ImageItem> images,
    required PdfSettings settings,
  }) async {
    int totalEstimate = 0;

    for (final image in images) {
      final imageEstimate = await _imageProcessor.estimateProcessedSize(
        image,
        settings,
      );
      totalEstimate += imageEstimate;
    }

    // Add PDF overhead (approximately 1KB per page + 5KB base)
    final pdfOverhead = 5000 + (images.length * 1000);

    return totalEstimate + pdfOverhead;
  }

  /// Process image with target size using safe sequential compression
  Future<ProcessedImage> _processImageWithTargetSize(
    ImageItem imageItem,
    PdfSettings settings,
    int targetBytes,
  ) async {
    // 1. Process CPU-heavy parts (decode, resize, upscale) on background isolate
    final processed = await compute(_isolatedProcessTargetSize, {
      'imagePath': imageItem.path,
      'imageFormat': imageItem.format,
      'targetBytes': targetBytes,
      'effectiveDpi': settings.effectiveDpi,
      'targetWidth': settings.targetWidth,
      'targetHeight': settings.targetHeight,
      'lockAspectRatio': settings.lockAspectRatio,
    });

    // 2. Fast native compression on MAIN isolate
    final optimizedBytes = await TargetSizeOptimizer.processTargetSize(
      inputBytes: processed.bytes,
      targetKB: targetBytes ~/ 1024,
      useTargetSize: true,
    );

    return ProcessedImage(
      bytes: optimizedBytes,
      width: processed.width,
      height: processed.height,
      format: processed.format,
    );
  }

  /// Apply image resizing based on settings
  img.Image _applyImageResizing(
    img.Image image,
    ImageItem imageItem,
    PdfSettings settings,
  ) {
    // Apply DPI scaling
    const double originalDpi = 72.0;
    final double targetDpi = settings.effectiveDpi.toDouble();

    if (targetDpi != originalDpi) {
      final double scaleFactor = originalDpi / targetDpi;
      final int newWidth = (image.width * scaleFactor).round();
      final int newHeight = (image.height * scaleFactor).round();

      if (newWidth != image.width || newHeight != image.height) {
        image = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // Apply custom dimensions if specified
    if (settings.targetWidth != null || settings.targetHeight != null) {
      int newWidth = settings.targetWidth ?? image.width;
      int newHeight = settings.targetHeight ?? image.height;

      if (settings.lockAspectRatio) {
        final double aspectRatio = image.width / image.height;
        if (settings.targetWidth != null && settings.targetHeight == null) {
          newHeight = (settings.targetWidth! / aspectRatio).round();
        } else if (settings.targetHeight != null &&
            settings.targetWidth == null) {
          newWidth = (settings.targetHeight! * aspectRatio).round();
        }
      }

      if (newWidth != image.width || newHeight != image.height) {
        image = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    return image;
  }

  /// Encode image with specific quality
  Uint8List _encodeWithQuality(
    img.Image image,
    ImageFormat format,
    int quality,
  ) {
    switch (format) {
      case ImageFormat.jpg:
      case ImageFormat.jpeg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ImageFormat.png:
        return Uint8List.fromList(img.encodePng(image, level: 9));
      case ImageFormat.webp:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ImageFormat.heic:
        // HEIC encoding fallback to JPEG
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
  }
}

/// Exception thrown when PDF generation fails
class PdfGeneratorException implements Exception {
  final String message;
  PdfGeneratorException(this.message);

  @override
  String toString() => 'PdfGeneratorException: $message';
}

/// Top-level helper function for isolates
Future<ProcessedImage> _isolatedProcessTargetSize(
  Map<String, dynamic> args,
) async {
  final String imagePath = args['imagePath'];
  final ImageFormat formatStr = args['imageFormat'];
  int targetBytes = args['targetBytes'];
  final int effectiveDpi = args['effectiveDpi'];
  final int? targetWidth = args['targetWidth'];
  final int? targetHeight = args['targetHeight'];
  final bool lockAspectRatio = args['lockAspectRatio'];

  print('🎯 ISOLATE: PDF IMAGE OPTIMIZATION ($imagePath)');

  if (targetBytes < 10 * 1024) {
    targetBytes = 10 * 1024;
  }

  final file = File(imagePath);
  final bytes = file.readAsBytesSync();
  var image = img.decodeImage(bytes);

  if (image == null) {
    throw Exception('Failed to decode image');
  }

  // Apply DPI scaling
  final double scaleFactor = 72.0 / effectiveDpi.toDouble();
  int newWidth = (image.width * scaleFactor).round();
  int newHeight = (image.height * scaleFactor).round();

  // Apply custom dimensions if needed
  if (targetWidth != null || targetHeight != null) {
    newWidth = targetWidth ?? image.width;
    newHeight = targetHeight ?? image.height;

    if (lockAspectRatio) {
      final double aspectRatio = image.width / image.height;
      if (targetWidth != null && targetHeight == null) {
        newHeight = (targetWidth / aspectRatio).round();
      } else if (targetHeight != null && targetWidth == null) {
        newWidth = (targetHeight * aspectRatio).round();
      }
    }
  }

  if (newWidth != image.width || newHeight != image.height) {
    image = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  // Always encode to JPEG for target-size path.
  // ❌ Never encode to PNG here — PNG inflates byte count and breaks the
  //    optimizer's binary search (it would always see input > target).
  // ✅ TargetSizeOptimizer always operates on JPEG bytes.
  return ProcessedImage(
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 95)),
    width: image.width,
    height: image.height,
    format: ImageFormat.jpeg,
  );
}
