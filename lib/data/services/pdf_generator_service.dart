/// PDF Generator Service
/// Handles PDF creation from processed images
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/image_item.dart';
import '../../domain/entities/pdf_settings.dart';
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
            return pw.Center(
              child: pw.Image(
                pdfImage,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    // Generate timestamp for filename
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final filename = 'PHOTO_$timestamp.pdf';

    // Save PDF using export service
    final bytes = await pdf.save();
    final exportedFile = await _exportService.exportFile(
      bytes: Uint8List.fromList(bytes),
      filename: filename,
      mimeType: 'application/pdf',
      fileType: ExportFileType.pdf,
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
    final outputDir = Directory('${appDocDir.path}/${AppConstants.outputFolder}');

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
    print('🎯 PDF IMAGE OPTIMIZATION (${imageItem.fileName})');
    print('   Target: ${(targetBytes / 1024).toStringAsFixed(1)} KB per image');
    
    // Step 3: Validate Target Size
    int safeTargetBytes = targetBytes;
    if (safeTargetBytes < 10 * 1024) {
      print('⚠️ Target size too small, setting absolute minimum to 10KB');
      safeTargetBytes = 10 * 1024;
    }

    // Load image
    final file = File(imageItem.path);
    final bytes = await file.readAsBytes();
    var image = img.decodeImage(bytes);
    
    if (image == null) {
      throw PdfGeneratorException('Failed to decode image: ${imageItem.path}');
    }

    print('   Original: ${image.width}x${image.height}, Format: ${imageItem.format.name}');

    // Apply resizing (DPI and custom dimensions)
    image = _applyImageResizing(image, imageItem, settings);
    
    // Convert PNG/HEIC to JPEG for better compression
    ImageFormat targetFormat = imageItem.format;
    if (imageItem.format == ImageFormat.png || imageItem.format == ImageFormat.heic) {
      targetFormat = ImageFormat.jpeg;
      print('   🔄 Converting ${imageItem.format.name} → JPEG for better compression');
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
        Uint8List encodedBytes = _encodeWithQuality(workingImage, targetFormat, quality);
        
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
          return ProcessedImage(
            bytes: encodedBytes,
            width: workingImage.width,
            height: workingImage.height,
            format: targetFormat,
          );
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
        final finalSizeKB = bestBytes.length / 1024;
        print('   ⚠️ Max attempts reached, returning best effort: ${finalSizeKB.toStringAsFixed(1)} KB');
        return ProcessedImage(
          bytes: bestBytes,
          width: workingImage.width,
          height: workingImage.height,
          format: targetFormat,
        );
      }
      
      // Failsafe
      return ProcessedImage(
        bytes: _encodeWithQuality(image, targetFormat, 80),
        width: image.width,
        height: image.height,
        format: targetFormat,
      );
      
    } catch (e) {
      // Step 5: Handle Exceptions
      print('❌ Compression failed with error: $e');
      // Return a basic compressed version if logic fails completely
      return ProcessedImage(
        bytes: _encodeWithQuality(image, targetFormat, 60),
        width: image.width,
        height: image.height,
        format: targetFormat,
      );
    }
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
        } else if (settings.targetHeight != null && settings.targetWidth == null) {
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
  Uint8List _encodeWithQuality(img.Image image, ImageFormat format, int quality) {
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
